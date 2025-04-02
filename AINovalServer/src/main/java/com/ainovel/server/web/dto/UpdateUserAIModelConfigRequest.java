package com.ainovel.server.web.dto;

// 用于更新用户配置请求的 DTO (apiKey 和 apiEndpoint 都可以部分更新)
public record UpdateUserAIModelConfigRequest(
        String alias,
        String apiKey,
        String apiEndpoint) {

}
