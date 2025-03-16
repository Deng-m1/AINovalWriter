package com.ainovel.server.web.dto;

import lombok.Data;

/**
 * 场景版本比较请求DTO
 */
@Data
public class SceneVersionCompareDto {
    /**
     * 版本1索引 (-1表示当前版本)
     */
    private int versionIndex1;
    
    /**
     * 版本2索引
     */
    private int versionIndex2;
} 