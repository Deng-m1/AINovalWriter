package com.ainovel.server.web.dto;

import java.util.Map;

import lombok.Data;

@Data
public class SessionMessageDto {
    private String userId;
    private String sessionId;
    private String messageId;
    private String content;
    private Map<String, Object> metadata;
} 