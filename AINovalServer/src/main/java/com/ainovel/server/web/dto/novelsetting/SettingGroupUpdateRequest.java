package com.ainovel.server.web.dto.novelsetting;

import com.ainovel.server.domain.model.SettingGroup;

import lombok.Data;

/**
 * 设定组更新请求DTO
 */
@Data
public class SettingGroupUpdateRequest {
    private String groupId;
    private SettingGroup settingGroup;
} 