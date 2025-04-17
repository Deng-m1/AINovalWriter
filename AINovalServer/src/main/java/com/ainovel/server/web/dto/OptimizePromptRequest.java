package com.ainovel.server.web.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 优化提示词请求
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class OptimizePromptRequest {
    
    /**
     * 提示词内容
     */
    @NotBlank(message = "提示词内容不能为空")
    private String content;
    
    /**
     * 优化风格
     */
    @NotBlank(message = "优化风格不能为空")
    private String style;
    
    /**
     * 保留原文比例 (0.0-1.0)
     */
    @NotNull(message = "保留原文比例不能为空")
    @Min(value = 0, message = "保留原文比例最小为0")
    @Max(value = 1, message = "保留原文比例最大为1")
    private Double preserveRatio = 0.5;
} 