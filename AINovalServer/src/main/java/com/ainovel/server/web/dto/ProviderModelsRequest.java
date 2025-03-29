package com.ainovel.server.web.dto;

import jakarta.validation.constraints.NotBlank;

// 用于请求特定提供商模型列表的 DTO
public record ProviderModelsRequest(
        @NotBlank(message = "提供商名称不能为空")
        String provider) {

}
