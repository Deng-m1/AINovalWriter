package com.ainovel.server.web.dto;

import java.util.Map;

import lombok.Data;

@Data
public class SessionCreateDto {

    private String userId;
    private String novelId;
    private String modelName;
    private Map<String, Object> metadata;
}
