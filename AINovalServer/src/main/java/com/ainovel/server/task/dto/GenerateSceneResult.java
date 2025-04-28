package com.ainovel.server.task.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景生成任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSceneResult {
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 生成的内容
     */
    private String content;
    
    /**
     * 字数统计
     */
    private int wordCount;
    
    /**
     * 生成耗时（毫秒）
     */
    private long generationTimeMs;
} 