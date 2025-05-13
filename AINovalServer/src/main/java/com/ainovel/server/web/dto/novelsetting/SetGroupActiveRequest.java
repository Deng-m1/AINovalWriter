package com.ainovel.server.web.dto.novelsetting;

import lombok.Data;

/**
 * 设置组激活状态请求DTO
 */
@Data
public class SetGroupActiveRequest {
    private String groupId;
    private boolean active;
} 