package com.ainovel.server.domain.model;

import java.time.Instant;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.Data;

/**
 * 提示词模板模型
 * 用于存储不同类型的提示词模板
 */
@Data
@Document(collection = "promptTemplate")
public class PromptTemplate {
    
    @Id
    private String id;
    
    /**
     * 提示词类型
     */
    private String type;
    
    /**
     * 模板内容
     */
    private String template;
    
    /**
     * 描述
     */
    private String description;
    
    /**
     * 创建时间
     */
    private Instant createdAt = Instant.now();
    
    /**
     * 更新时间
     */
    private Instant updatedAt = Instant.now();
} 