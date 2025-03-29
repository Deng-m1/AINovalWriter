package com.ainovel.server.web.dto;

import jakarta.validation.constraints.NotBlank;

// Add validation annotations if needed, e.g., @NotBlank, @Size
// import jakarta.validation.constraints.NotBlank;
/**
 * DTO for creating a new User AI Model Configuration.
 */
public record CreateUserAIModelConfigRequest(
        @NotBlank(message = "提供商不能为空")
        String provider,
        @NotBlank(message = "模型名称不能为空")
        String modelName,
        String alias,
        @NotBlank(message = "API Key 不能为空")
        String apiKey,
        String apiEndpoint) {

}
