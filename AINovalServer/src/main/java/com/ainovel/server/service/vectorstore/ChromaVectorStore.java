package com.ainovel.server.service.vectorstore;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;


import org.springframework.beans.factory.annotation.Value;

import com.ainovel.server.domain.model.KnowledgeChunk;

import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.chroma.ChromaEmbeddingStore;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * Chroma向量存储实现 基于LangChain4j的ChromaEmbeddingStore
 */
@Slf4j
public class ChromaVectorStore implements VectorStore {

    private final EmbeddingStore<TextSegment> embeddingStore;


    /**
     * 创建Chroma向量存储
     * @param chromaUrl Chroma服务URL
     * @param collectionName 集合名称
     */
    public ChromaVectorStore(@Value("${vectorstore.chroma.url:http://localhost:18000}") String chromaUrl,
            @Value("${vectorstore.chroma.collection:ainovel}") String collectionName) {
        this(chromaUrl, collectionName, true);
    }

    /**
     * 创建Chroma向量存储
     * @param chromaUrl Chroma服务URL
     * @param collectionName 集合名称
     * @param reuseCollection 是否重用已存在的集合
     */
    public ChromaVectorStore(String chromaUrl, String collectionName, boolean reuseCollection) {
        log.info("初始化Chroma向量存储，URL: {}, 集合: {}, 重用集合: {}", chromaUrl, collectionName, reuseCollection);
        
        // 如果不需要重用集合，则创建一个唯一命名的集合
        String actualCollectionName;
        if (!reuseCollection) {
            actualCollectionName = collectionName + "_" + UUID.randomUUID().toString().substring(0, 8);
            log.info("使用唯一命名的Chroma集合: {}", actualCollectionName);
        } else {
            actualCollectionName = collectionName;
        }
        
        // 尝试创建或连接到集合
        EmbeddingStore<TextSegment> store = null;
        int maxRetries = 3;
        int retryCount = 0;
        boolean success = false;
        
        while (!success && retryCount < maxRetries) {
            try {
                if (retryCount > 0) {
                    // 如果是重试，则使用唯一命名的集合
                    actualCollectionName = collectionName + "_retry_" + UUID.randomUUID().toString().substring(0, 8);
                    log.info("重试 #{}: 使用新的集合名称: {}", retryCount, actualCollectionName);
                }
                
                store = ChromaEmbeddingStore.builder()
                        .baseUrl(chromaUrl)
                        .collectionName(actualCollectionName)
                        .build();
                
                log.info("成功创建或连接到Chroma集合: {}", actualCollectionName);
                success = true;
            } catch (Exception e) {
                retryCount++;
                
                // 如果是集合已存在错误，并且我们想要重用集合
                if (e.getMessage() != null && 
                    e.getMessage().contains("Collection " + actualCollectionName + " already exists") && 
                    reuseCollection) {
                    // 这是我们期望的情况，但LangChain4j的ChromaEmbeddingStore不支持直接连接到现有集合
                    // 我们需要修改VectorStoreConfig，使用随机集合名称
                    log.warn("集合 {} 已存在，但无法直接连接。请考虑在配置中启用随机集合名称。", actualCollectionName);
                    throw new RuntimeException("集合已存在，但无法直接连接: " + e.getMessage(), e);
                }
                
                if (retryCount >= maxRetries) {
                    log.error("在 {} 次尝试后初始化Chroma向量存储失败", maxRetries, e);
                    throw new RuntimeException("初始化Chroma向量存储失败: " + e.getMessage(), e);
                }
                
                log.warn("初始化Chroma向量存储失败，将重试 ({}/{}): {}", retryCount, maxRetries, e.getMessage());
            }
        }
        
        this.embeddingStore = store;
    }

    @Override
    public Mono<String> storeVector(String content, float[] vector, Map<String, Object> metadata) {
        log.info("存储向量，内容长度: {}, 元数据: {}", content.length(), metadata);

        return Mono.fromCallable(() -> {
            String id = UUID.randomUUID().toString();

            // 转换元数据
            Metadata langchainMetadata = new Metadata();
            if (metadata != null) {
                metadata.forEach((key, value) -> langchainMetadata.put(key, value.toString()));
            }

            // 创建文本段落
            TextSegment segment = TextSegment.from(content, langchainMetadata);

            // 创建嵌入
            Embedding embedding = Embedding.from(vector);

            // 存储嵌入
            embeddingStore.add(embedding, segment);

            return id;
        }).onErrorResume(e -> {
            log.error("存储向量失败", e);
            return Mono.error(new RuntimeException("存储向量失败: " + e.getMessage()));
        });
    }

    @Override
    public Mono<String> storeKnowledgeChunk(KnowledgeChunk chunk) {
        log.info("存储知识块，ID: {}, 小说ID: {}", chunk.getId(), chunk.getNovelId());

        if (chunk.getVectorEmbedding() == null || chunk.getVectorEmbedding().getVector() == null) {
            return Mono.error(new IllegalArgumentException("知识块缺少向量嵌入"));
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
        log.info("搜索向量，过滤条件: {}, 限制: {}", filter, limit);

        return Mono.fromCallable(() -> {
            // 创建查询嵌入
            Embedding queryEmbedding = Embedding.from(queryVector);

            // 执行搜索
            List<EmbeddingMatch<TextSegment>> matches = embeddingStore.findRelevant(queryEmbedding, limit);

            // 转换结果
            return matches.stream()
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
        })
                .flatMapMany(Flux::fromIterable)
                .onErrorResume(e -> {
                    log.error("搜索向量失败", e);
                    return Flux.error(new RuntimeException("搜索向量失败: " + e.getMessage()));
                });
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

        // 注意：ChromaEmbeddingStore目前不支持按元数据删除
        // 这里需要先获取所有匹配的ID，然后逐个删除
        // 这是一个简化实现，实际应用中可能需要更复杂的逻辑
        return Mono.error(new UnsupportedOperationException("当前版本不支持按小说ID删除"));
    }

    @Override
    public Mono<Void> deleteBySourceId(String novelId, String sourceType, String sourceId) {
        log.info("删除源的向量，小说ID: {}, 源类型: {}, 源ID: {}", novelId, sourceType, sourceId);

        // 注意：ChromaEmbeddingStore目前不支持按元数据删除
        // 这里需要先获取所有匹配的ID，然后逐个删除
        // 这是一个简化实现，实际应用中可能需要更复杂的逻辑
        return Mono.error(new UnsupportedOperationException("当前版本不支持按源ID删除"));
    }
}
