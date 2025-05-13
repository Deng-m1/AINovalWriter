package com.ainovel.server.web.dto.novelsetting;

import lombok.Data;

/**
 * 提取设定请求DTO
 */
@Data
public class ExtractSettingsRequest {
    private String text;
    private String type = "auto";
} 