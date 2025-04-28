package com.ainovel.server.task.dto.summarygeneration;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * 生成场景摘要任务的结果DTO
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
     * 生成的向量嵌入（如果启用）
     */
    private float[] embedding;
    
    /**
     * 使用的模型名称
     */
    private String modelName;
    
    /**
     * 处理时间（毫秒）
     */
    private long processingTimeMs;
    
    /**
     * 完成时间
     */
    private Instant completedAt;
} 