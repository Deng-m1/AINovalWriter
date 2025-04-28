package com.ainovel.server.task.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景摘要生成任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSummaryResult {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 生成的摘要内容
     */
    private String summary;
    
    /**
     * 字数统计
     */
    private int wordCount;
    
    /**
     * 生成耗时（毫秒）
     */
    private long generationTimeMs;
} 