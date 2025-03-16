package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 内容修改请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RevisionRequest {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 原内容
     */
    private String content;
    
    /**
     * 修改指令
     */
    private String instruction;
} 