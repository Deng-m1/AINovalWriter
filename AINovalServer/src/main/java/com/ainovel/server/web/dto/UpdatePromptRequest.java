package com.ainovel.server.web.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 更新提示词请求DTO
 * 用于API请求
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePromptRequest {
    
    /**
     * 提示词文本
     */
    @NotBlank(message = "提示词文本不能为空")
    private String promptText;
} 