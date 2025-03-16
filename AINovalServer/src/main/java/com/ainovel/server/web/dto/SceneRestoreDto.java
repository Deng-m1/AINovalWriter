package com.ainovel.server.web.dto;

import lombok.Data;

/**
 * 场景版本恢复请求DTO
 */
@Data
public class SceneRestoreDto {
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