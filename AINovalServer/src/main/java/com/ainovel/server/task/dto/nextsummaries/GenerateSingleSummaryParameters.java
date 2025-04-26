package com.ainovel.server.task.dto.nextsummaries;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成单个章节摘要任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSingleSummaryParameters {
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 章节序号（在当前任务中的索引，从0开始）
     */
    private int chapterIndex;
    
    /**
     * 当前章节序号（全局）
     */
    private int chapterOrder;
    
    /**
     * 摘要生成用的AI配置ID
     */
    private String aiConfigIdSummary;
    
    /**
     * 上下文内容（前序章节的摘要或内容）
     */
    private String context;
    
    /**
     * 上一章的摘要（如果有）
     */
    private String previousSummary;
} 