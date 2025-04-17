package com.ainovel.server.web.dto;

import java.time.LocalDateTime;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.PromptTemplate;
import com.fasterxml.jackson.annotation.JsonInclude;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 提示词模板DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class PromptTemplateDto {
    private String id;
    private String name;
    private String content;
    private String featureType;
    private boolean isPublic;
    private String authorId;
    private String sourceTemplateId;
    private boolean isVerified;
    private boolean isFavorite;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    /**
     * 从实体转换为DTO
     */
    public static PromptTemplateDto fromEntity(PromptTemplate entity) {
        return PromptTemplateDto.builder()
                .id(entity.getId())
                .name(entity.getName())
                .content(entity.getContent())
                .featureType(featureTypeToString(entity.getFeatureType()))
                .isPublic(entity.isPublic())
                .authorId(entity.getAuthorId())
                .sourceTemplateId(entity.getSourceTemplateId())
                .isVerified(entity.isVerified())
                .isFavorite(entity.isFavorite())
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt())
                .build();
    }
    
    /**
     * 将枚举转换为字符串
     */
    private static String featureTypeToString(AIFeatureType featureType) {
        switch (featureType) {
            case SCENE_TO_SUMMARY:
                return "sceneToSummary";
            case SUMMARY_TO_SCENE:
                return "summaryToScene";
            default:
                return featureType.name();
        }
    }
} 