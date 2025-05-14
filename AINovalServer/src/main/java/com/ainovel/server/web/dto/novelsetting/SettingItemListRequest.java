package com.ainovel.server.web.dto.novelsetting;

import lombok.Data;

/**
 * 设定条目列表请求DTO
 */
@Data
public class SettingItemListRequest {
    private String type;
    private String name;
    private Integer priority;
    private String generatedBy;
    private String status;
    private int page = 0;
    private int size = 20;
    private String sortBy = "priority";
    private String sortDirection = "desc";
} 