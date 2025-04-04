package com.ainovel.server.service.rag;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.time.Duration;

import org.springframework.stereotype.Component;

import com.ainovel.server.service.vectorstore.VectorStore;
import com.ainovel.server.exception.VectorStoreException;

import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingStore;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;
import reactor.util.retry.Retry;

/**
 * Chroma嵌入存储适配器 将VectorStore适配为LangChain4j的EmbeddingStore
 */
@Slf4j
@Component
public class ChromaEmbeddingStoreAdapter implements EmbeddingStore<TextSegment> {

    private final VectorStore vectorStore;
    private static final int EXPECTED_DIMENSION = 384; // 期望的向量维度
    private static final boolean AUTO_ADJUST_DIMENSION = true; // 是否自动调整向量维度
    private static final int BATCH_SIZE = 10; // 批量处理大小
    private static final int MAX_RETRIES = 3; // 最大重试次数
    private static final int RETRY_DELAY_MS = 1000; // 重试延迟（毫秒）
    private static final int ERROR_THRESHOLD_MS = 1000; // 错误冷却时间（毫秒）
    private static final int MAX_ERROR_COUNT = 5; // 最大错误次数

    private final ConcurrentHashMap<String, AtomicLong> lastErrorTime = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AtomicInteger> errorCount = new ConcurrentHashMap<>();

    /**
     * 构造函数
     *
     * @param vectorStore 向量存储
     */
    public ChromaEmbeddingStoreAdapter(VectorStore vectorStore) {
        this.vectorStore = vectorStore;
    }

    /**
     * 验证向量维度 如果维度不匹配且启用了自动调整，则调整向量维度
     */
    private float[] validateAndAdjustEmbeddingDimension(float[] vector) {
        if (vector == null || vector.length == 0) {
            return null;
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
    private void recordErrorTime(String operation) {
        lastErrorTime.computeIfAbsent(operation, k -> new AtomicLong(0))
                .set(System.currentTimeMillis());
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
     * 增加错误计数
     */
    private void incrementErrorCount(String operation) {
        errorCount.computeIfAbsent(operation, k -> new AtomicInteger(0)).incrementAndGet();
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
     * 添加嵌入向量
     *
     * @param embedding 嵌入向量
     * @return 嵌入ID
     */
    @Override
    public String add(Embedding embedding) {
        log.debug("添加嵌入向量");
        try {
            float[] adjustedVector = validateAndAdjustEmbeddingDimension(embedding.vector());
            return withRetry(
                    vectorStore.storeVector("", adjustedVector, Map.of()),
                    "add"
            ).block();
        } catch (Exception e) {
            incrementErrorCount("add");
            recordErrorTime("add");
            throw new VectorStoreException("添加嵌入向量失败: " + e.getMessage(), e);
        }
    }

    /**
     * 添加嵌入向量（带ID）
     *
     * @param id ID
     * @param embedding 嵌入向量
     */
    @Override
    public void add(String id, Embedding embedding) {
        log.debug("添加带ID的嵌入向量: {}", id);
        try {
            float[] adjustedVector = validateAndAdjustEmbeddingDimension(embedding.vector());
            String embeddingId = (id == null || id.isEmpty()) ? UUID.randomUUID().toString() : id;
            withRetry(
                    vectorStore.storeVector(embeddingId, adjustedVector, Map.of()),
                    "add"
            ).block();
        } catch (Exception e) {
            incrementErrorCount("add");
            recordErrorTime("add");
            throw new VectorStoreException("添加带ID的嵌入向量失败: " + e.getMessage(), e);
        }
    }

    /**
     * 添加嵌入向量和文本段落
     *
     * @param embedding 嵌入向量
     * @param textSegment 文本段落
     * @return 嵌入ID
     */
    @Override
    public String add(Embedding embedding, TextSegment textSegment) {
        log.debug("添加嵌入向量和文本段落，文本长度: {}", textSegment.text().length());
        try {
            float[] adjustedVector = validateAndAdjustEmbeddingDimension(embedding.vector());

            // 从TextSegment获取元数据
            Map<String, Object> metadata = new HashMap<>();
            if (textSegment.metadata() != null) {
                textSegment.metadata().asMap().forEach(metadata::put);
            }

            return withRetry(
                    vectorStore.storeVector(textSegment.text(), adjustedVector, metadata),
                    "add"
            ).block();
        } catch (Exception e) {
            incrementErrorCount("add");
            recordErrorTime("add");
            throw new VectorStoreException("添加嵌入向量和文本段落失败: " + e.getMessage(), e);
        }
    }

    /**
     * 添加多个嵌入向量
     *
     * @param embeddings 嵌入向量列表
     * @return 嵌入ID列表
     */
    @Override
    public List<String> addAll(List<Embedding> embeddings) {
        log.debug("添加多个嵌入向量，数量: {}", embeddings.size());
        try {
            List<VectorStore.VectorData> vectorDataList = embeddings.stream()
                    .map(embedding -> {
                        float[] adjustedVector = validateAndAdjustEmbeddingDimension(embedding.vector());
                        return new VectorStore.VectorData("", adjustedVector, Map.of());
                    })
                    .collect(Collectors.toList());

            return withRetry(
                    vectorStore.storeVectorsBatch(vectorDataList),
                    "addAll"
            ).block();
        } catch (Exception e) {
            incrementErrorCount("addAll");
            recordErrorTime("addAll");
            throw new VectorStoreException("批量添加嵌入向量失败: " + e.getMessage(), e);
        }
    }

    /**
     * 添加多个嵌入向量和文本段落
     *
     * @param embeddings 嵌入向量列表
     * @param textSegments 文本段落列表
     * @return 嵌入ID列表
     */
    @Override
    public List<String> addAll(List<Embedding> embeddings, List<TextSegment> textSegments) {
        log.debug("添加多个嵌入向量和文本段落，数量: {}", embeddings.size());
        try {
            if (embeddings.size() != textSegments.size()) {
                throw new VectorStoreException("嵌入向量和文本段落数量不匹配");
            }

            List<VectorStore.VectorData> vectorDataList = new ArrayList<>();
            for (int i = 0; i < embeddings.size(); i++) {
                Embedding embedding = embeddings.get(i);
                TextSegment textSegment = textSegments.get(i);
                float[] adjustedVector = validateAndAdjustEmbeddingDimension(embedding.vector());
                if (adjustedVector == null) {
                    continue;
                }

                Map<String, Object> metadata = new HashMap<>();
                if (textSegment.metadata() != null) {
                    textSegment.metadata().asMap().forEach(metadata::put);
                }

                vectorDataList.add(new VectorStore.VectorData(textSegment.text(), adjustedVector, metadata));
            }

            return withRetry(
                    vectorStore.storeVectorsBatch(vectorDataList),
                    "addAll"
            ).block();
        } catch (Exception e) {
            incrementErrorCount("addAll");
            recordErrorTime("addAll");
            throw new VectorStoreException("批量添加嵌入向量和文本段落失败: " + e.getMessage(), e);
        }
    }

    /**
     * 查找与查询向量最相似的文本段落
     *
     * @param queryEmbedding 查询向量
     * @param maxResults 最大结果数
     * @return 匹配结果
     */
    @Override
    public List<EmbeddingMatch<TextSegment>> findRelevant(Embedding queryEmbedding, int maxResults) {
        log.debug("查找相关文本段落，最大结果数: {}", maxResults);
        try {
            float[] adjustedVector = validateAndAdjustEmbeddingDimension(queryEmbedding.vector());

            return withRetry(
                    vectorStore.search(adjustedVector, maxResults)
                            .map(result -> {
                                // 创建元数据
                                Metadata metadata = new Metadata();
                                if (result.getMetadata() != null) {
                                    result.getMetadata().forEach((key, value) -> metadata.put(key, value.toString()));
                                }

                                // 创建文本段落
                                TextSegment textSegment = TextSegment.from(result.getContent(), metadata);

                                // 创建嵌入匹配（使用UUID作为ID，这里不需要真实ID）
                                String id = UUID.randomUUID().toString();
                                return new EmbeddingMatch<>(result.getScore(), id, null, textSegment);
                            })
                            .collectList(),
                    "findRelevant"
            ).block();
        } catch (Exception e) {
            incrementErrorCount("findRelevant");
            recordErrorTime("findRelevant");
            throw new VectorStoreException("查找相关文本段落失败: " + e.getMessage(), e);
        }
    }

    /**
     * 查找与查询向量最相似的文本段落（带过滤条件）
     *
     * @param queryEmbedding 查询向量
     * @param filter 过滤条件
     * @param maxResults 最大结果数
     * @return 匹配结果
     */
    public List<EmbeddingMatch<TextSegment>> findRelevant(Embedding queryEmbedding, Metadata filter, int maxResults) {
        log.debug("查找相关文本段落（带过滤条件），最大结果数: {}", maxResults);
        try {
            float[] adjustedVector = validateAndAdjustEmbeddingDimension(queryEmbedding.vector());

            // 将Metadata转换为Map
            Map<String, Object> filterMap = null;
            if (filter != null && !filter.asMap().isEmpty()) {
                filterMap = filter.asMap().entrySet().stream()
                        .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));
            }

            return withRetry(
                    vectorStore.search(adjustedVector, filterMap, maxResults)
                            .map(result -> {
                                // 创建元数据
                                Metadata metadata = new Metadata();
                                if (result.getMetadata() != null) {
                                    result.getMetadata().forEach((key, value) -> metadata.put(key, value.toString()));
                                }

                                // 创建文本段落
                                TextSegment textSegment = TextSegment.from(result.getContent(), metadata);

                                // 创建嵌入匹配（使用UUID作为ID，这里不需要真实ID）
                                String id = UUID.randomUUID().toString();
                                return new EmbeddingMatch<>(result.getScore(), id, null, textSegment);
                            })
                            .collectList(),
                    "findRelevant"
            ).block();
        } catch (Exception e) {
            incrementErrorCount("findRelevant");
            recordErrorTime("findRelevant");
            throw new VectorStoreException("查找相关文本段落（带过滤条件）失败: " + e.getMessage(), e);
        }
    }
}
