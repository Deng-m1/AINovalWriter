package com.ainovel.server.config;

import java.time.Duration;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import com.ainovel.server.service.vectorstore.ChromaVectorStore;
import com.ainovel.server.service.vectorstore.VectorStore;

import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.chroma.ChromaEmbeddingStore;
import lombok.extern.slf4j.Slf4j;

/**
 * 向量存储配置类
 */
@Slf4j
@Configuration
public class VectorStoreConfig {
    
    /**
     * 创建Chroma向量存储
     * @param chromaUrl Chroma服务URL
     * @param collectionName 集合名称
     * @param useRandomCollection 是否使用随机集合名
     * @param reuseCollection 是否重用已存在的集合
     * @return 向量存储实例
     */
    @Bean
    @Primary
    public VectorStore chromaVectorStore(
            @Value("${vectorstore.chroma.url:http://localhost:18000}") String chromaUrl,
            @Value("${vectorstore.chroma.collection:ainovel}") String collectionNamePrefix,
            @Value("${vectorstore.chroma.use-random-collection:true}") boolean useRandomCollection,
            @Value("${vectorstore.chroma.reuse-collection:false}") boolean reuseCollection,
            @Value("${vectorstore.chroma.max-retries:3}") int maxRetries,
            @Value("${vectorstore.chroma.retry-delay-ms:1000}") int retryDelayMs,
            @Value("${vectorstore.chroma.log-requests:false}") boolean logRequests,
            @Value("${vectorstore.chroma.log-responses:false}") boolean logResponses) {

        String collectionName = useRandomCollection
                ? collectionNamePrefix + "_" + UUID.randomUUID().toString().substring(0, 8)
                : collectionNamePrefix;

        log.info("配置Chroma向量存储，URL: {}, 集合: {}, 重用集合: {}", chromaUrl, collectionName, reuseCollection);
        return new ChromaVectorStore(chromaUrl, collectionName, maxRetries, retryDelayMs);
    }
    
    /**
     * 创建LangChain4j的Chroma嵌入存储
     * @param chromaUrl Chroma服务URL
     * @param collectionName 集合名称
     * @param useRandomCollection 是否使用随机集合名
     * @param timeout 超时设置
     * @param logRequests 是否记录请求日志
     * @param logResponses 是否记录响应日志
     * @return 嵌入存储实例
     */
    @Bean
    public EmbeddingStore<TextSegment> chromaEmbeddingStore(
            @Value("${vectorstore.chroma.url:http://localhost:18000}") String chromaUrl,
            @Value("${vectorstore.chroma.collection:ainovel}") String collectionNamePrefix,
            @Value("true") boolean useRandomCollection,
            @Value("${vectorstore.chroma.timeout-seconds:5}") int timeoutSeconds,
            @Value("${vectorstore.chroma.log-requests:false}") boolean logRequests,
            @Value("${vectorstore.chroma.log-responses:false}") boolean logResponses) {

        String collectionName = useRandomCollection
                ? collectionNamePrefix + "_" + UUID.randomUUID().toString().substring(0, 8)
                : collectionNamePrefix;

        log.info("配置LangChain4j Chroma嵌入存储，URL: {}, 集合: {}, 超时: {}秒", 
                chromaUrl, collectionName, timeoutSeconds);

        return ChromaEmbeddingStore.builder()
                .baseUrl(chromaUrl)
                .collectionName(collectionName)
                .timeout(Duration.ofSeconds(timeoutSeconds))
                .logRequests(logRequests)
                .logResponses(logResponses)
                .build();
    }
} 