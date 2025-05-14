package com.ainovel.server.web.dto.novelsetting;

import lombok.Data;

/**
 * 设定组列表请求DTO
 */
@Data
public class SettingGroupListRequest {
    private String name;
    private Boolean isActiveContext;
} 