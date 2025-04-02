package com.ainovel.server.service.rag;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Component;

import com.ainovel.server.service.vectorstore.VectorStore;

import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingStore;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;

/**
 * Chroma嵌入存储适配器 将VectorStore适配为LangChain4j的EmbeddingStore
 */
@Slf4j
@Component
public class ChromaEmbeddingStoreAdapter implements EmbeddingStore<TextSegment> {

    private final VectorStore vectorStore;

    /**
     * 构造函数
     *
     * @param vectorStore 向量存储
     */
    public ChromaEmbeddingStoreAdapter(VectorStore vectorStore) {
        this.vectorStore = vectorStore;
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
        return vectorStore.storeVector("", embedding.vector(), Map.of()).block();
    }

    /**
     * 添加嵌入向量（带ID）
     *
     * @param id ID
     * @param embedding 嵌入向量
     * @return 嵌入ID
     */
    @Override
    public void add(String id, Embedding embedding) {
        log.debug("添加带ID的嵌入向量: {}", id);
        // 如果ID为null或为空，生成一个新的UUID
        String embeddingId = (id == null || id.isEmpty()) ? UUID.randomUUID().toString() : id;
        vectorStore.storeVector(embeddingId, embedding.vector(), Map.of()).block();
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

        // 从TextSegment获取元数据
        Map<String, Object> metadata = new HashMap<>();
        if (textSegment.metadata() != null) {
            textSegment.metadata().asMap().forEach(metadata::put);
        }

        // 将嵌入和段落保存到向量存储
        return vectorStore.storeVector(textSegment.text(), embedding.vector(), metadata).block();
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

        return Flux.fromIterable(embeddings)
                .flatMap(embedding -> vectorStore.storeVector("", embedding.vector(), Map.of()))
                .collectList()
                .block();
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

        if (embeddings.size() != textSegments.size()) {
            throw new IllegalArgumentException("嵌入向量和文本段落数量不匹配");
        }

        return Flux.range(0, embeddings.size())
                .flatMap(i -> {
                    Embedding embedding = embeddings.get(i);
                    TextSegment textSegment = textSegments.get(i);

                    // 从TextSegment获取元数据
                    Map<String, Object> metadata = new HashMap<>();
                    if (textSegment.metadata() != null) {
                        textSegment.metadata().asMap().forEach(metadata::put);
                    }

                    // 将嵌入和段落保存到向量存储
                    return vectorStore.storeVector(textSegment.text(), embedding.vector(), metadata);
                })
                .collectList()
                .block();
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

        return vectorStore.search(queryEmbedding.vector(), maxResults)
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
                .collectList()
                .block();
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

        // 将Metadata转换为Map
        Map<String, Object> filterMap = null;
        if (filter != null && !filter.asMap().isEmpty()) {
            filterMap = filter.asMap().entrySet().stream()
                    .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));
        }

        return vectorStore.search(queryEmbedding.vector(), filterMap, maxResults)
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
                .collectList()
                .block();
    }
}
