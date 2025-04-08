package com.ainovel.server.domain.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

/**
 * 用户提示词模板实体 用于存储用户自定义的提示词模板
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Document(collection = "userPromptTemplate")
public class UserPromptTemplate {

    @Id
    private String id;

    /**
     * 用户ID
     */
    private String userId;

    /**
     * 功能类型
     */
    private AIFeatureType featureType;

    /**
     * 提示词文本
     */
    private String promptText;

    /**
     * 创建时间
     */
    private LocalDateTime createdAt = LocalDateTime.now();

    /**
     * 更新时间
     */
    private LocalDateTime updatedAt = LocalDateTime.now();
}
