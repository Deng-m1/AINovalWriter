package com.ainovel.server.config;

import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import com.ainovel.server.service.vectorstore.ChromaVectorStore;
import com.ainovel.server.service.vectorstore.VectorStore;

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
     * @param reuseCollection 是否重用已存在的集合
     * @return 向量存储实例
     */
    @Bean
    @Primary
    public VectorStore chromaVectorStore(
            @Value("${vectorstore.chroma.url:http://localhost:18000}") String chromaUrl,
            @Value("${vectorstore.chroma.collection:ainovel}") String collectionNamePrefix,
            @Value("true") boolean useRandomCollection,
            @Value("${vectorstore.chroma.reuse-collection:false}") boolean reuseCollection) {

        String collectionName = useRandomCollection
                ? collectionNamePrefix + "_" + UUID.randomUUID().toString().substring(0, 8)
                : collectionNamePrefix;



        log.info("配置Chroma向量存储，URL: {}, 集合: {}, 重用集合: {}", chromaUrl, collectionName, reuseCollection);
        return new ChromaVectorStore(chromaUrl, collectionName, reuseCollection);
    }
} 