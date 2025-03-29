package com.ainovel.server.web.dto;

// 用于列出用户配置请求的 DTO
public record ListUserConfigsRequest(
        Boolean validatedOnly // 可选参数，是否只显示已验证的
        ) {

}
