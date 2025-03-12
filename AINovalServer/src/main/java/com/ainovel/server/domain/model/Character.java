package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 角色领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "characters")
public class Character {
    
    @Id
    private String id;
    
    private String novelId;
    
    private String name;
    
    private String description;
    
    /**
     * 角色详情
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Details {
        private Integer age;
        private String gender;
        private String occupation;
        private String background;
        private String personality;
        private String appearance;
        @Builder.Default
        private List<String> goals = new ArrayList<>();
        @Builder.Default
        private List<String> conflicts = new ArrayList<>();
    }
    
    private Details details;
    
    /**
     * 关系网络
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Relationship {
        private String characterId;
        private String type;  // friend, enemy, family, etc.
        private String description;
    }
    
    @Builder.Default
    private List<Relationship> relationships = new ArrayList<>();
    
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
    
    private VectorEmbedding vectorEmbedding;
    
    private LocalDateTime createdAt;
    
    private LocalDateTime updatedAt;
} 