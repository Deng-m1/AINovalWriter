package com.ainovel.server.web.dto;

import lombok.Data;

/**
 * 场景内容更新请求DTO
 */
@Data
public class SceneContentUpdateDto {
    /**
     * 新内容
     */
    private String content;
    
    /**
     * 用户ID
     */
    private String userId;
    
    /**
     * 修改原因
     */
    private String reason;
} 