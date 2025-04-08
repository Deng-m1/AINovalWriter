package com.ainovel.server.web.dto;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.UserPromptTemplate;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 用户提示词模板DTO
 * 用于API响应
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserPromptTemplateDto {
    
    /**
     * 功能类型
     */
    private AIFeatureType featureType;
    
    /**
     * 提示词文本
     */
    private String promptText;
    
    /**
     * 从实体转换为DTO
     *
     * @param template 用户提示词模板实体
     * @return DTO
     */
    public static UserPromptTemplateDto fromEntity(UserPromptTemplate template) {
        return UserPromptTemplateDto.builder()
                .featureType(template.getFeatureType())
                .promptText(template.getPromptText())
                .build();
    }
} 