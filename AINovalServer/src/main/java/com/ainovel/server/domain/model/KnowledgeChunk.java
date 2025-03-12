package com.ainovel.server.domain.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 知识块领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "knowledge_chunks")
public class KnowledgeChunk {
    
    @Id
    private String id;
    
    private String novelId;
    
    private String sourceType;  // scene, character, setting, note
    
    private String sourceId;
    
    private String content;
    
    /**
     * 向量嵌入
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class VectorEmbedding {
        private float[] vector;
        private String model;
    }
    
    private VectorEmbedding vectorEmbedding;
    
    /**
     * 元数据
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Metadata {
        private String title;
        private Integer chunkIndex;
        private Integer totalChunks;
        private Integer wordCount;
    }
    
    private Metadata metadata;
    
    private LocalDateTime createdAt;
    
    private LocalDateTime updatedAt;
} 