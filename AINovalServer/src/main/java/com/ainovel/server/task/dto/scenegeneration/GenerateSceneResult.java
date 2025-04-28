package com.ainovel.server.task.dto.scenegeneration;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * 生成场景任务的结果DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSceneResult {

    /**
     * 生成的场景ID
     */
    private String sceneId;
    
    /**
     * 生成的场景内容
     */
    private String content;
    
    /**
     * 场景字数
     */
    private int wordCount;
    
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
    
    /**
     * 是否保存到数据库
     */
    private boolean savedToDatabase;
} 