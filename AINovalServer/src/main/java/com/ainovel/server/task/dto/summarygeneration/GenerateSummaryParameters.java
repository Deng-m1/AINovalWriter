package com.ainovel.server.task.dto.summarygeneration;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成场景摘要任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSummaryParameters {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * AI配置ID
     */
    private String aiConfigId;
    
    /**
     * 预期版本号，用于乐观锁检查
     */
    private int expectedVersion;
} 