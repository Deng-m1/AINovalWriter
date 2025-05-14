package com.ainovel.server.web.dto.novelsetting;

import lombok.Data;

/**
 * 设定关系删除请求DTO
 */
@Data
public class SettingRelationshipDeleteRequest {
    private String itemId;
    private String targetItemId;
    private String relationshipType;
} 