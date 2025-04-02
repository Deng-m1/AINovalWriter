package com.ainovel.server.service.rag;

import java.util.List;
import java.util.stream.Collectors;

import com.ainovel.server.service.EmbeddingService;

import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.output.Response;
import lombok.extern.slf4j.Slf4j;

/**
 * LangChain4j嵌入模型适配器
 * 将EmbeddingService适配为LangChain4j的EmbeddingModel
 */
@Slf4j
public class LangChain4jEmbeddingModel implements EmbeddingModel {

    private final EmbeddingService embeddingService;

    /**
     * 构造函数
     * 
     * @param embeddingService 嵌入服务
     */
    public LangChain4jEmbeddingModel(EmbeddingService embeddingService) {
        this.embeddingService = embeddingService;
    }

    /**
     * 为文本生成嵌入向量
     * 
     * @param text 文本
     * @return 嵌入向量
     */
    @Override
    public Response<Embedding> embed(String text) {
        log.debug("生成文本嵌入向量，文本长度: {}", text.length());
        try {
            float[] vector = embeddingService.generateEmbedding(text).block();
            Embedding embedding = vector != null ? Embedding.from(vector) : Embedding.from(new float[0]);
            return Response.from(embedding);
        } catch (Exception e) {
            log.error("生成文本嵌入向量失败", e);
            return Response.from(Embedding.from(new float[0]));
        }
    }

    /**
     * 为文本段落生成嵌入向量
     * 
     * @param textSegment 文本段落
     * @return 嵌入向量
     */
    @Override
    public Response<Embedding> embed(TextSegment textSegment) {
        return embed(textSegment.text());
    }

    /**
     * 为多个文本段落生成嵌入向量
     * 
     * @param textSegments 文本段落列表
     * @return 嵌入向量列表
     */
    @Override
    public Response<List<Embedding>> embedAll(List<TextSegment> textSegments) {
        log.debug("生成多个文本段落嵌入向量，段落数量: {}", textSegments.size());
        try {
            List<Embedding> embeddings = textSegments.stream()
                    .map(segment -> {
                        try {
                            float[] vector = embeddingService.generateEmbedding(segment.text()).block();
                            return vector != null ? Embedding.from(vector) : Embedding.from(new float[0]);
                        } catch (Exception e) {
                            log.error("生成单个文本段落嵌入向量失败", e);
                            return Embedding.from(new float[0]);
                        }
                    })
                    .collect(Collectors.toList());
            return Response.from(embeddings);
        } catch (Exception e) {
            log.error("生成多个文本段落嵌入向量失败", e);
            return Response.from(List.of());
        }
    }
}
