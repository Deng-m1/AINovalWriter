package com.ainovel.server.service.rag;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.time.Duration;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.ainovel.server.domain.model.KnowledgeChunk;
import com.ainovel.server.exception.VectorStoreException;

import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.EmbeddingSearchRequest;
import dev.langchain4j.store.embedding.EmbeddingSearchResult;
import dev.langchain4j.store.embedding.chroma.ChromaEmbeddingStore;
import lombok.extern.slf4j.Slf4j;
import lombok.Getter;
import lombok.Setter;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;
import reactor.util.retry.Retry;

/**
 * Chroma嵌入存储Provider 
 * 使用官方ChromaEmbeddingStore实现，同时提供更多业务层面的功能
 */
@Slf4j
@Component
public class ChromaEmbeddingStoreProvider {

    // 定义内部的SearchResult和VectorData类
    @Getter
    @Setter
    public static class SearchResult {
        private String id;
        private String content;
        private double score;
        private Map<String, Object> metadata;
    }

    @Getter
    @Setter
    public static class VectorData {
        private String content;
        private float[] vector;
        private Map<String, Object> metadata;
    }

    private final EmbeddingStore<TextSegment> embeddingStore;

    private static final int EXPECTED_DIMENSION = 384; // 期望的向量维度
    private static final boolean AUTO_ADJUST_DIMENSION = true; // 是否自动调整向量维度
    private static final int MAX_RETRIES = 3; // 最大重试次数
    private static final int RETRY_DELAY_MS = 1000; // 重试延迟（毫秒）
    private static final int ERROR_THRESHOLD_MS = 1000; // 错误冷却时间（毫秒）
    private static final int MAX_ERROR_COUNT = 5; // 最大错误次数

    private final ConcurrentHashMap<String, AtomicLong> lastErrorTime = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AtomicInteger> errorCount = new ConcurrentHashMap<>();

    /**
     * 构造函数 - 初始化ChromaEmbeddingStore
     */
    public ChromaEmbeddingStoreProvider(EmbeddingStore<TextSegment> embeddingStore) {
        this.embeddingStore = embeddingStore;
    }

    /**
     * 获取底层ChromaEmbeddingStore
     */
    public EmbeddingStore<TextSegment> getEmbeddingStore() {
        return embeddingStore;
    }


    /**
     * 验证向量维度 如果维度不匹配且启用了自动调整，则调整向量维度
     */
    private float[] validateAndAdjustEmbeddingDimension(float[] vector) {
        if (vector == null || vector.length == 0) {
            throw new VectorStoreException("向量不能为空");
        }

        if (vector.length == EXPECTED_DIMENSION) {
            return vector; // 维度匹配，直接返回
        }

        if (!AUTO_ADJUST_DIMENSION) {
            // 不自动调整维度，抛出异常
            throw new VectorStoreException(
                    String.format("向量维度 %d 与期望维度 %d 不匹配",
                            vector.length, EXPECTED_DIMENSION)
            );
        }

        // 自动调整向量维度
        log.warn("向量维度 {} 与期望维度 {} 不匹配，正在自动调整", vector.length, EXPECTED_DIMENSION);
        return adjustVectorDimension(vector);
    }

    /**
     * 调整向量维度 如果原始维度小于期望维度，则用0填充 如果原始维度大于期望维度，则截断
     */
    private float[] adjustVectorDimension(float[] originalVector) {
        float[] adjustedVector = new float[EXPECTED_DIMENSION];

        if (originalVector.length < EXPECTED_DIMENSION) {
            // 原始维度小于期望维度，用0填充
            System.arraycopy(originalVector, 0, adjustedVector, 0, originalVector.length);
            // 剩余部分默认为0
        } else {
            // 原始维度大于期望维度，截断
            System.arraycopy(originalVector, 0, adjustedVector, 0, EXPECTED_DIMENSION);
        }

        return adjustedVector;
    }

    /**
     * 检查错误冷却时间
     */
    private boolean isInErrorCooldown(String operation) {
        AtomicLong lastError = lastErrorTime.get(operation);
        if (lastError != null) {
            long timeSinceLastError = System.currentTimeMillis() - lastError.get();
            return timeSinceLastError < ERROR_THRESHOLD_MS;
        }
        return false;
    }

    /**
     * 记录错误时间
     */
    private void recordError(String operation) {
        lastErrorTime.computeIfAbsent(operation, k -> new AtomicLong(0)).set(System.currentTimeMillis());
        errorCount.computeIfAbsent(operation, k -> new AtomicInteger(0)).incrementAndGet();
    }

    /**
     * 重置错误计数
     */
    private void resetErrorCount(String operation) {
        errorCount.computeIfAbsent(operation, k -> new AtomicInteger(0)).set(0);
    }

    /**
     * 获取当前错误计数
     */
    private int getErrorCount(String operation) {
        return errorCount.computeIfAbsent(operation, k -> new AtomicInteger(0)).get();
    }

    /**
     * 执行带重试的操作
     */
    private <T> Mono<T> withRetry(Mono<T> operation, String operationName) {
        return operation
                .retryWhen(Retry.backoff(MAX_RETRIES, Duration.ofMillis(RETRY_DELAY_MS))
                        .filter(throwable -> throwable instanceof VectorStoreException)
                        .doBeforeRetry(signal -> log.warn("重试 {} 操作，第 {} 次尝试", operationName, signal.totalRetries() + 1)))
                .onErrorResume(e -> {
                    log.error("{} 操作在 {} 次尝试后失败", operationName, MAX_RETRIES, e);
                    return Mono.error(new VectorStoreException(operationName + " 操作失败: " + e.getMessage(), e));
                });
    }

    /**
     * 存储向量
     */
    public Mono<String> storeVector(String content, float[] vector, Map<String, Object> metadata) {
        // 检查错误计数
        if (getErrorCount("store") >= MAX_ERROR_COUNT) {
            return Mono.error(new VectorStoreException("向量存储服务暂时不可用，请稍后再试"));
        }

        // 检查冷却时间
        if (isInErrorCooldown("store")) {
            return Mono.delay(Duration.ofMillis(ERROR_THRESHOLD_MS))
                    .flatMap(tick -> storeVector(content, vector, metadata));
        }

        log.info("存储向量，内容长度: {}, 元数据: {}", content.length(), metadata);

        Mono<String> operation = Mono.fromCallable(() -> {
            try {
                // 验证并可能调整向量维度
                float[] adjustedVector = validateAndAdjustEmbeddingDimension(vector);
                String id = UUID.randomUUID().toString();

                // 转换元数据
                Metadata langchainMetadata = new Metadata();
                if (metadata != null) {
                    metadata.forEach((key, value) -> {
                        if (value != null) {
                            langchainMetadata.put(key, value.toString());
                        }
                    });
                }

                // 创建文本段落
                TextSegment segment = TextSegment.from(content, langchainMetadata);

                // 创建嵌入
                Embedding embedding = Embedding.from(adjustedVector);

                // 存储嵌入 - 使用正确的add方法（修复：在1.0.0-beta3中方法签名可能发生变化）
                embeddingStore.add(embedding, segment);

                // 成功存储后重置错误计数
                resetErrorCount("store");

                return id;
            } catch (Exception e) {
                recordError("store");
                throw new VectorStoreException("存储向量失败: " + e.getMessage(), e);
            }
        })
                .subscribeOn(Schedulers.boundedElastic());

        return withRetry(operation, "存储向量");
    }

    /**
     * 存储知识块
     */
    public Mono<String> storeKnowledgeChunk(KnowledgeChunk chunk) {
        if (chunk.getVectorEmbedding() == null || chunk.getVectorEmbedding().getVector() == null) {
            return Mono.error(new VectorStoreException("知识块缺少向量嵌入"));
        }

        // 创建元数据
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("id", chunk.getId());
        metadata.put("novelId", chunk.getNovelId());
        metadata.put("sourceType", chunk.getSourceType());
        metadata.put("sourceId", chunk.getSourceId());

        return storeVector(chunk.getContent(), chunk.getVectorEmbedding().getVector(), metadata);
    }

    /**
     * 批量存储向量
     */
    public Mono<List<String>> storeVectorsBatch(List<VectorData> vectorDataList) {
        if (vectorDataList.isEmpty()) {
            return Mono.just(new ArrayList<>());
        }

        return Mono.fromCallable(() -> {
            List<String> ids = new ArrayList<>();
            List<Embedding> embeddings = new ArrayList<>();
            List<TextSegment> segments = new ArrayList<>();

            for (VectorData data : vectorDataList) {
                try {
                    // 验证并可能调整向量维度
                    float[] adjustedVector = validateAndAdjustEmbeddingDimension(data.getVector());
                    String id = UUID.randomUUID().toString();

                    // 转换元数据
                    Metadata langchainMetadata = new Metadata();
                    if (data.getMetadata() != null) {
                        data.getMetadata().forEach((key, value) -> {
                            if (value != null) {
                                langchainMetadata.put(key, value.toString());
                            }
                        });
                    }

                    // 创建文本段落
                    TextSegment segment = TextSegment.from(data.getContent(), langchainMetadata);
                    segments.add(segment);

                    // 创建嵌入
                    Embedding embedding = Embedding.from(adjustedVector);
                    embeddings.add(embedding);

                    ids.add(id);
                } catch (Exception e) {
                    log.error("批量存储向量时出错: {}", e.getMessage());
                    // 继续处理其他向量
                }
            }

            // 批量存储
            if (!embeddings.isEmpty()) {
                embeddingStore.addAll(embeddings, segments);
            }

            return ids;
        })
                .subscribeOn(Schedulers.boundedElastic())
                .flatMap(ids -> {
                    if (ids.isEmpty()) {
                        return Mono.error(new VectorStoreException("批量存储向量失败：所有向量处理均失败"));
                    }
                    return Mono.just(ids);
                });
    }

    /**
     * 搜索向量
     */
    public Flux<SearchResult> search(float[] queryVector, int limit) {
        return search(queryVector, null, limit);
    }

    /**
     * 按小说ID搜索向量
     */
    public Flux<SearchResult> searchByNovelId(float[] queryVector, String novelId, int limit) {
        // 创建过滤条件
        Map<String, Object> filter = Map.of("novelId", novelId);
        return search(queryVector, filter, limit);
    }

    /**
     * 带过滤条件搜索向量
     */
    public Flux<SearchResult> search(float[] queryVector, Map<String, Object> filter, int limit) {
        // 检查错误计数
        if (getErrorCount("search") >= MAX_ERROR_COUNT) {
            return Flux.error(new VectorStoreException("向量搜索服务暂时不可用，请稍后再试"));
        }

        // 检查冷却时间
        if (isInErrorCooldown("search")) {
            return Mono.delay(Duration.ofMillis(ERROR_THRESHOLD_MS))
                    .flatMapMany(tick -> search(queryVector, filter, limit));
        }

        log.info("搜索向量，过滤条件: {}, 限制: {}", filter, limit);

        Mono<List<SearchResult>> operation = Mono.fromCallable(() -> {
            try {
                // 验证并可能调整向量维度
                float[] adjustedVector = validateAndAdjustEmbeddingDimension(queryVector);

                // 创建查询嵌入
                Embedding queryEmbedding = Embedding.from(adjustedVector);

                // 执行搜索
                List<EmbeddingMatch<TextSegment>> matches;
                
                // 创建搜索请求
                EmbeddingSearchRequest searchRequest = EmbeddingSearchRequest.builder()
                        .queryEmbedding(queryEmbedding)
                        .maxResults(limit)
                        .build();
                
                // 实际调用官方API
                EmbeddingSearchResult<TextSegment> searchResult = embeddingStore.search(searchRequest);
                matches = searchResult.matches();

                // 转换结果
                List<SearchResult> results = matches.stream()
                        .map(match -> {
                            SearchResult result = new SearchResult();
                            result.setContent(match.embedded().text());
                            result.setScore(match.score());

                            // 提取元数据
                            Metadata metadata = match.embedded().metadata();
                            if (metadata != null) {
                                Map<String, Object> resultMetadata = new HashMap<>();
                                // 使用toMap方法替代asMap
                                metadata.toMap().forEach(resultMetadata::put);
                                result.setMetadata(resultMetadata);

                                // 设置ID（如果存在）
                                if (resultMetadata.containsKey("id")) {
                                    result.setId(String.valueOf(resultMetadata.get("id")));
                                }
                            }

                            return result;
                        })
                        .collect(Collectors.toList());

                // 成功搜索后重置错误计数
                resetErrorCount("search");

                return results;
            } catch (Exception e) {
                recordError("search");
                throw new VectorStoreException("搜索向量失败: " + e.getMessage(), e);
            }
        })
                .subscribeOn(Schedulers.boundedElastic());

        return withRetry(operation, "搜索向量")
                .flatMapMany(Flux::fromIterable);
    }

    /**
     * 删除向量（按小说ID）
     */
    public Mono<Void> deleteByNovelId(String novelId) {
        log.info("删除小说的向量，小说ID: {}", novelId);
        // TODO: 实现按小说ID删除向量的功能
        return Mono.empty();
    }

    /**
     * 删除向量（按源ID）
     */
    public Mono<Void> deleteBySourceId(String novelId, String sourceType, String sourceId) {
        log.info("删除源的向量，小说ID: {}, 源类型: {}, 源ID: {}", novelId, sourceType, sourceId);
        // TODO: 实现按源ID删除向量的功能
        return Mono.empty();
    }
} 