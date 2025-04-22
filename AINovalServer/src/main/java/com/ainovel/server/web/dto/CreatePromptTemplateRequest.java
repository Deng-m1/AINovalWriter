package com.ainovel.server.web.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 创建提示词模板请求
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreatePromptTemplateRequest {
    
    /**
     * 模板名称
     */
    @NotBlank(message = "模板名称不能为空")
    private String name;
    
    /**
     * 模板内容
     */
    @NotBlank(message = "模板内容不能为空")
    private String content;
    
    /**
     * 功能类型
     */
    @NotBlank(message = "功能类型不能为空")
    private String featureType;
} 