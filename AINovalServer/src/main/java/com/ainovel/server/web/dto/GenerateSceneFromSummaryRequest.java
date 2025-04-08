package com.ainovel.server.web.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 根据摘要生成场景请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSceneFromSummaryRequest {
    
    /**
     * 摘要或大纲
     */
    @NotBlank(message = "摘要不能为空")
    private String summary;
    
    /**
     * 场景计划归属的章节ID（可选）
     */
    private String chapterId;
    
    /**
     * 场景在章节或小说中的大致位置（可选，用于RAG参考）
     */
    private Integer position;
    
    /**
     * 用户附加的风格指令（可选）
     */
    private String styleInstructions;
} 