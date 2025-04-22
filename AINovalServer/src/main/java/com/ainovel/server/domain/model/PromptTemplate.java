package com.ainovel.server.domain.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 提示词模板实体
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "prompt_templates")
public class PromptTemplate {
    /**
     * 模板ID
     */
    @Id
    private String id;
    
    /**
     * 模板名称
     */
    private String name;
    
    /**
     * 模板内容
     */
    private String content;
    
    /**
     * 功能类型
     */
    private AIFeatureType featureType;
    
    /**
     * 是否为公共模板
     */
    private boolean isPublic;
    
    /**
     * 作者ID
     */
    private String authorId;
    
    /**
     * 源模板ID（如果是从公共模板复制的）
     */
    private String sourceTemplateId;
    
    /**
     * 是否为官方验证模板
     */
    private boolean isVerified;
    
    /**
     * 用户是否收藏（仅对私有模板有效）
     */
    private boolean isFavorite;
    
    /**
     * 创建时间
     */
    private LocalDateTime createdAt;
    
    /**
     * 更新时间
     */
    private LocalDateTime updatedAt;
} 