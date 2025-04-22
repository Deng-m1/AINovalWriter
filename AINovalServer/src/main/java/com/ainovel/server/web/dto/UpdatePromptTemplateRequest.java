package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 更新提示词模板请求
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePromptTemplateRequest {
    
    /**
     * 模板名称
     */
    private String name;
    
    /**
     * 模板内容
     */
    private String content;
} 