package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景恢复数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SceneRestoreDto {
    private String id;
    private String novelId;
    private String chapterId;
    /**
     * 历史版本索引
     */
    private int historyIndex;
    
    /**
     * 用户ID
     */
    private String userId;
    
    /**
     * 恢复原因
     */
    private String reason;
}