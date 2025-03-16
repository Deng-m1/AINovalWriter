package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景内容更新数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SceneContentUpdateDto {
    private String id;
    private String novelId;
    private String chapterId;
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