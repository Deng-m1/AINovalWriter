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
 * 小说领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "novels")
public class Novel {
    
    @Id
    private String id;
    
    private String title;
    
    private String description;
    
    private Author author;
    
    private List<String> genre;
    
    private List<String> tags;
    
    private String coverImage;
    
    private String status;
    
    private Structure structure;
    
    private Metadata metadata;
    
    private LocalDateTime createdAt;
    
    private LocalDateTime updatedAt;
    
    /**
     * 作者信息
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Author {
        private String id;
        private String username;
    }
    
    /**
     * 小说结构
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Structure {
        @Builder.Default
        private List<Act> acts = new ArrayList<>();
    }
    
    /**
     * 卷
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Act {
        private String id;
        private String title;
        private String description;
        private int order;
        @Builder.Default
        private List<Chapter> chapters = new ArrayList<>();
    }
    
    /**
     * 章节
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Chapter {
        private String id;
        private String title;
        private String description;
        private int order;
        private String sceneRef;
    }
    
    /**
     * 元数据
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Metadata {
        private int wordCount;
        private int readTime;
        private LocalDateTime lastEditedAt;
        private int version;
    }
} 