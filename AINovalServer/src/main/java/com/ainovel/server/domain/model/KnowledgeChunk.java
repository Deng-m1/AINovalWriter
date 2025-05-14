package com.ainovel.server.domain.model;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.Data;

/**
 * 知识块模型
 * 用于存储小说内容的向量化表示和原始内容
 */
@Data
@Document(collection = "knowledgeChunk")
public class KnowledgeChunk {
    
    @Id
    private String id;
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 源类型（scene, character, setting, note等）
     */
    private String sourceType;
    
    /**
     * 源ID
     */
    private String sourceId;
    
    /**
     * 内容文本
     */
    private String content;
    
    /**
     * 向量嵌入
     */
    private VectorEmbedding vectorEmbedding;
    
    /**
     * 创建时间
     */
    private Instant createdAt = Instant.now();
    
    /**
     * 更新时间
     */
    private Instant updatedAt = Instant.now();


    private Map<String, Object> metadata = new HashMap<>();
    
    /**
     * 向量嵌入类
     */
    @Data
    public static class VectorEmbedding {
        /**
         * 向量数据
         */
        private float[] vector;
        
        /**
         * 向量维度
         */
        private int dimension;
        
        /**
         * 使用的模型
         */
        private String model;
    }
} 