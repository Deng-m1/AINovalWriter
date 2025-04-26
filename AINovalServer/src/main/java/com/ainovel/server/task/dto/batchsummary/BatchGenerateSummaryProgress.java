package com.ainovel.server.task.dto.batchsummary;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 批量生成场景摘要任务进度
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatchGenerateSummaryProgress {
    
    /**
     * 总场景数
     */
    private int totalScenes;
    
    /**
     * 已处理场景数
     */
    private int processedCount;
    
    /**
     * 成功生成摘要的场景数
     */
    private int successCount;
    
    /**
     * 生成失败的场景数
     */
    private int failedCount;
    
    /**
     * 检测到冲突并基于最新内容生成的场景数
     */
    private int conflictCount;
    
    /**
     * 因已存在摘要而跳过的场景数
     */
    private int skippedCount;
} 