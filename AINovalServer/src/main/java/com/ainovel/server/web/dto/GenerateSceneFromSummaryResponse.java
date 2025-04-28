package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 根据摘要生成场景响应DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSceneFromSummaryResponse {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 生成的场景内容
     */
    private String content;
    
    /**
     * 字数统计
     */
    private int wordCount;
    
    /**
     * 使用的模型
     */
    private String modelUsed;
    
    /**
     * 生成耗时（毫秒）
     */
    private long generationTimeMs;
}