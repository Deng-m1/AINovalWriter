package com.ainovel.server.web.dto.novelsetting;

import lombok.Data;

/**
 * 设定关系请求DTO
 */
@Data
public class SettingRelationshipRequest {
    private String itemId;
    private String targetItemId;
    private String relationshipType;
    private String description;
} 