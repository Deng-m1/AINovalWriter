package com.ainovel.server.domain.model;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 角色模型
 * 表示小说中的一个角色
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "character")
public class Character {
    
    @Id
    private String id;
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 角色名称
     */
    private String name;
    
    /**
     * 角色描述
     */
    private String description;
    
    /**
     * 角色详情
     */
    private Details details;
    
    /**
     * 角色关系
     */
    @Builder.Default
    private List<Relationship> relationships = new ArrayList<>();
    
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
        private List<String> goals;
        private List<String> conflicts;
    }
    
    /**
     * 角色关系
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Relationship {
        /**
         * 关联角色ID
         */
        private String characterId;
        
        /**
         * 关系类型
         */
        private String type;
        
        /**
         * 关系描述
         */
        private String description;
    }
    
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
} 