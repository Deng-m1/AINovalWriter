package com.ainovel.server.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.ainovel.server.service.EmbeddingService;
import com.ainovel.server.service.rag.LangChain4jEmbeddingModel;

import dev.langchain4j.data.document.DocumentSplitter;
import dev.langchain4j.data.document.splitter.DocumentSplitters;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.rag.content.Content;
import dev.langchain4j.rag.content.retriever.ContentRetriever;
import dev.langchain4j.rag.content.retriever.EmbeddingStoreContentRetriever;
import dev.langchain4j.rag.query.Query;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.EmbeddingStoreIngestor;
import lombok.extern.slf4j.Slf4j;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

/**
 * RAG（检索增强生成）配置类
 */
@Slf4j
@Configuration
public class RagConfig {

    @Value("${rag.document-splitter.chunk-size:1000}")
    private int chunkSize;

    @Value("${rag.document-splitter.chunk-overlap:200}")
    private int chunkOverlap;

    @Value("${rag.retriever.max-results:5}")
    private int maxResults;

    @Value("${rag.retriever.min-score:0.6}")
    private double minScore;

    /**
     * 配置文档拆分器
     *
     * @return 文档拆分器
     */
    @Bean
    public DocumentSplitter documentSplitter() {
        log.info("配置DocumentSplitter，块大小：{}，重叠大小：{}", chunkSize, chunkOverlap);
        return DocumentSplitters.recursive(chunkSize, chunkOverlap);
    }

    /**
     * 配置LangChain4j嵌入模型适配器
     *
     * @param embeddingService 嵌入服务
     * @return 嵌入模型
     */
    @Bean
    public EmbeddingModel embeddingModel(EmbeddingService embeddingService) {
        log.info("配置EmbeddingModel适配器");
        return new LangChain4jEmbeddingModel(embeddingService);
    }

    /**
     * 配置嵌入存储摄取器
     *
     * @param documentSplitter 文档拆分器
     * @param embeddingModel 嵌入模型
     * @param embeddingStore 嵌入存储
     * @return 嵌入存储摄取器
     */
    @Bean
    public EmbeddingStoreIngestor embeddingStoreIngestor(
            DocumentSplitter documentSplitter,
            EmbeddingModel embeddingModel,
            EmbeddingStore<TextSegment> embeddingStore) {
        log.info("配置EmbeddingStoreIngestor");
        return EmbeddingStoreIngestor.builder()
                .documentSplitter(documentSplitter)
                .embeddingModel(embeddingModel)
                .embeddingStore(embeddingStore)
                .build();
    }

    /**
     * 配置内容检索器 为避免LangChain4j库中出现的StackOverflowError问题，包装在一个异常处理器中
     *
     * @param embeddingStore 嵌入存储
     * @param embeddingModel 嵌入模型
     * @return 内容检索器
     */
    @Bean
    public ContentRetriever contentRetriever(
            EmbeddingStore<TextSegment> embeddingStore,
            EmbeddingModel embeddingModel) {
        log.info("配置ContentRetriever，最大结果数：{}，最小分数：{}", maxResults, minScore);

        // 创建标准的ContentRetriever
        ContentRetriever standardRetriever = EmbeddingStoreContentRetriever.builder()
                .embeddingStore(embeddingStore)
                .embeddingModel(embeddingModel)
                .maxResults(maxResults)
                .minScore(minScore)
                .build();

        // 包装在异常处理器中
        return new ContentRetriever() {
            @Override
            public List<Content> retrieve(Query query) {
                try {
                    // 添加直接调用EmbeddingStore的实现，避免递归调用
                    Embedding queryEmbedding = embeddingModel.embed(query.text()).content();
                    var relevantMatches = embeddingStore.findRelevant(queryEmbedding, maxResults, minScore);

                    if (relevantMatches.isEmpty()) {
                        log.info("向量搜索未找到相关内容");
                        return Collections.emptyList();
                    }

                    return relevantMatches.stream()
                            .map(match -> Content.from(match.embedded().text()))
                            .collect(Collectors.toList());
                } catch (StackOverflowError e) {
                    log.error("ContentRetriever发生StackOverflowError，返回空结果", e);
                    return Collections.emptyList();
                } catch (Exception e) {
                    log.error("ContentRetriever发生异常", e);
                    return Collections.emptyList();
                }
            }
        };
    }
}
