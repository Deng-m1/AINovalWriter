package com.ainovel.server.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.ainovel.server.service.rag.ChromaEmbeddingStoreAdapter;
import com.ainovel.server.service.rag.LangChain4jEmbeddingModel;

import dev.langchain4j.rag.content.retriever.ContentRetriever;
import dev.langchain4j.rag.content.retriever.EmbeddingStoreContentRetriever;
import lombok.extern.slf4j.Slf4j;

/**
 * RAG助手配置类
 */
@Slf4j
@Configuration
public class RagAssistantConfig {

    @Autowired
    private ChromaEmbeddingStoreAdapter embeddingStore;

    @Autowired
    private LangChain4jEmbeddingModel embeddingModel;

    /**
     * 配置内容检索器
     *
     * @return 内容检索器Bean
     */
    @Bean
    public ContentRetriever contentRetriever() {
        log.info("创建ContentRetriever...");
        return EmbeddingStoreContentRetriever.builder()
                .embeddingStore(embeddingStore)
                .embeddingModel(embeddingModel)
                .maxResults(5)
                .minScore(0.6)
                .build();
    }
}
