package com.ainovel.server.task.dto.batchsummary;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 批量生成场景摘要任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatchGenerateSummaryParameters {
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 起始章节ID
     */
    private String startChapterId;
    
    /**
     * 结束章节ID
     */
    private String endChapterId;
    
    /**
     * AI配置ID
     */
    private String aiConfigId;
    
    /**
     * 是否覆盖已有摘要
     */
    private boolean overwriteExisting;
} 