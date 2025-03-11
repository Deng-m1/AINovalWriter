package com.ainovel.server.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 场景领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "scenes")
public class Scene {
    
    @Id
    private String id;
    
    private String novelId;
    
    private String chapterId;
    
    private String title;
    
    private String content;
    
    private String summary;
    
    private VectorEmbedding vectorEmbedding;
    
    private List<String> characters;
    
    private List<String> locations;
    
    private String timeframe;
    
    private int version;
    
    private List<HistoryEntry> history;
    
    private LocalDateTime createdAt;
    
    private LocalDateTime updatedAt;
    
    /**
     * 向量嵌入
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class VectorEmbedding {
        private List<Float> vector;
        private String model;
    }
    
    /**
     * 历史记录条目
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class HistoryEntry {
        private String content;
        private LocalDateTime updatedAt;
        private String updatedBy;
    }
} 