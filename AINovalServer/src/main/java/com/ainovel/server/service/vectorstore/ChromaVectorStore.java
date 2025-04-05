package com.ainovel.server.service.vectorstore;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.KnowledgeChunk;
import com.ainovel.server.exception.VectorStoreException;

import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.chroma.ChromaEmbeddingStore;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;
import reactor.util.retry.Retry;

import java.time.Duration;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Chroma向量存储实现 基于LangChain4j的ChromaEmbeddingStore
 */
@Slf4j
@Service
public class ChromaVectorStore implements VectorStore {

    private final EmbeddingStore<TextSegment> embeddingStore;
    private final String collectionName;
    private final int maxRetries;
    private final int retryDelayMs;
    private final ConcurrentHashMap<String, AtomicLong> lastErrorTime = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AtomicInteger> errorCount = new ConcurrentHashMap<>();
    private static final int ERROR_THRESHOLD_MS = 1000; // 1秒内不重试
    private static final int EXPECTED_DIMENSION = 384; // 期望的向量维度
    private static final boolean AUTO_ADJUST_DIMENSION = true; // 是否自动调整向量维度
    private static final int BATCH_SIZE = 10; // 批量处理大小
    private static final int MAX_ERROR_COUNT = 5; // 最大错误次数

    /**
     * 创建Chroma向量存储
     *
     * @param chromaUrl Chroma服务URL
     * @param collectionName 集合名称
     */
    public ChromaVectorStore(
            @Value("${vectorstore.chroma.url:http://localhost:18000}") String chromaUrl,
            @Value("${vectorstore.chroma.collection:ainovel}") String collectionName,
            @Value("${vectorstore.chroma.max-retries:3}") int maxRetries,
            @Value("${vectorstore.chroma.retry-delay-ms:1000}") int retryDelayMs) {
        this.collectionName = collectionName;
        this.maxRetries = maxRetries;
        this.retryDelayMs = retryDelayMs;
        this.embeddingStore = initializeStore(chromaUrl, collectionName);
    }

    /**
     * 初始化向量存储
     */
    private EmbeddingStore<TextSegment> initializeStore(String chromaUrl, String collectionName) {
        log.info("初始化Chroma向量存储，URL: {}, 集合: {}", chromaUrl, collectionName);

        try {
            return ChromaEmbeddingStore.builder()
                    .baseUrl(chromaUrl)
                    .collectionName(collectionName + UUID.randomUUID().toString())
                    .build();
        } catch (Exception e) {
            log.error("初始化Chroma向量存储失败", e);
            throw new VectorStoreException("初始化向量存储失败: " + e.getMessage(), e);
        }
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
                .retryWhen(Retry.backoff(maxRetries, Duration.ofMillis(retryDelayMs))
                        .filter(throwable -> throwable instanceof VectorStoreException)
                        .doBeforeRetry(signal -> log.warn("重试 {} 操作，第 {} 次尝试", operationName, signal.totalRetries() + 1)))
                .onErrorResume(e -> {
                    log.error("{} 操作在 {} 次尝试后失败", operationName, maxRetries, e);
                    return Mono.error(new VectorStoreException(operationName + " 操作失败: " + e.getMessage(), e));
                });
    }

    /**
     * 批量存储向量
     */
    @Override
    public Mono<List<String>> storeVectorsBatch(List<VectorData> vectorDataList) {
        if (vectorDataList.isEmpty()) {
            return Mono.just(new ArrayList<>());
        }

        return Mono.fromCallable(() -> {
            List<String> ids = new ArrayList<>();
            for (VectorData data : vectorDataList) {
                try {
                    // 验证并可能调整向量维度
                    float[] adjustedVector = validateAndAdjustEmbeddingDimension(data.getVector());
                    String id = UUID.randomUUID().toString();

                    // 转换元数据
                    Metadata langchainMetadata = new Metadata();
                    if (data.getMetadata() != null) {
                        data.getMetadata().forEach((key, value) -> langchainMetadata.put(key, value.toString()));
                    }

                    // 创建文本段落
                    TextSegment segment = TextSegment.from(data.getContent(), langchainMetadata);

                    // 创建嵌入
                    Embedding embedding = Embedding.from(adjustedVector);

                    // 存储嵌入
                    embeddingStore.add(embedding, segment);

                    ids.add(id);
                } catch (Exception e) {
                    log.error("批量存储向量时出错: {}", e.getMessage());
                    // 继续处理其他向量
                }
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

    @Override
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
                    metadata.forEach((key, value) -> langchainMetadata.put(key, value.toString()));
                }

                // 创建文本段落
                TextSegment segment = TextSegment.from(content, langchainMetadata);

                // 创建嵌入
                Embedding embedding = Embedding.from(adjustedVector);

                // 存储嵌入
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

    @Override
    public Mono<String> storeKnowledgeChunk(KnowledgeChunk chunk) {
        if (chunk.getVectorEmbedding() == null || chunk.getVectorEmbedding().getVector() == null) {
            return Mono.error(new VectorStoreException("知识块缺少向量嵌入"));
        }

        // 创建元数据
        Map<String, Object> metadata = Map.of(
                "id", chunk.getId(),
                "novelId", chunk.getNovelId(),
                "sourceType", chunk.getSourceType(),
                "sourceId", chunk.getSourceId()
        );

        return storeVector(chunk.getContent(), chunk.getVectorEmbedding().getVector(), metadata);
    }

    @Override
    public Flux<SearchResult> search(float[] queryVector, int limit) {
        return search(queryVector, null, limit);
    }

    @Override
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
                List<EmbeddingMatch<TextSegment>> matches = embeddingStore.findRelevant(queryEmbedding, limit);

                // 转换结果
                List<SearchResult> results = matches.stream()
                        .map(match -> {
                            SearchResult result = new SearchResult();
                            result.setContent(match.embedded().text());
                            result.setScore(match.score());

                            // 提取元数据
                            Metadata metadata = match.embedded().metadata();
                            if (metadata != null) {
                                Map<String, Object> resultMetadata = metadata.asMap().entrySet().stream()
                                        .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));
                                result.setMetadata(resultMetadata);

                                // 设置ID（如果存在）
                                if (metadata.get("id") != null) {
                                    result.setId(metadata.get("id").toString());
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

    @Override
    public Flux<SearchResult> searchByNovelId(float[] queryVector, String novelId, int limit) {
        // 创建过滤条件
        Map<String, Object> filter = Map.of("novelId", novelId);
        return search(queryVector, filter, limit);
    }

    @Override
    public Mono<Void> deleteByNovelId(String novelId) {
        log.info("删除小说的向量，小说ID: {}", novelId);
        // TODO: 实现按小说ID删除向量的功能
        return Mono.empty();
    }

    @Override
    public Mono<Void> deleteBySourceId(String novelId, String sourceType, String sourceId) {
        log.info("删除源的向量，小说ID: {}, 源类型: {}, 源ID: {}", novelId, sourceType, sourceId);
        // TODO: 实现按源ID删除向量的功能
        return Mono.empty();
    }

    /**
     * 向量数据内部类
     */
//    private static class VectorData {
//
//        final String content;
//        final float[] vector;
//        final Map<String, Object> metadata;
//
//        VectorData(String content, float[] vector, Map<String, Object> metadata) {
//            this.content = content;
//            this.vector = vector;
//            this.metadata = metadata;
//        }
//
//        String getContent() {
//            return content;
//        }
//
//        float[] getVector() {
//            return vector;
//        }
//
//        Map<String, Object> getMetadata() {
//            return metadata;
//        }
//    }
}
