package com.ainovel.server.web.dto.novelsetting;

import com.ainovel.server.domain.model.NovelSettingItem;

import lombok.Data;

/**
 * 设定条目更新请求DTO
 */
@Data
public class SettingItemUpdateRequest {
    private String itemId;
    private NovelSettingItem settingItem;
} 