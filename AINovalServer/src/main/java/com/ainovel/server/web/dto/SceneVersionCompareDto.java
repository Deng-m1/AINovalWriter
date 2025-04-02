package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景版本比较数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SceneVersionCompareDto {
    private String id;
    private String novelId;
    private String chapterId;
    /**
     * 版本1索引 (-1表示当前版本)
     */
    private int versionIndex1;
    
    /**
     * 版本2索引 (-1表示当前版本)
     */
    private int versionIndex2;
} 