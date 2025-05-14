package com.ainovel.server.task.dto.summarygeneration;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成场景摘要任务的参数DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSummaryParameters {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 用户自定义提示（可选）
     */
    private String customPrompt;
    
    /**
     * 最大摘要长度（可选）
     */
    private Integer maxLength;
    
    /**
     * 是否使用AI模型增强（可选）
     */
    @Builder.Default
    private Boolean useAIEnhancement = true;
} 