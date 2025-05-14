package com.ainovel.server.task.dto.nextsummaries;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成单个章节摘要任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSingleSummaryResult {
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 新创建的章节ID
     */
    private String chapterId;
    
    /**
     * 生成的摘要内容
     */
    private String summary;
    
    /**
     * 章节序号（在当前任务中的索引，从0开始）
     */
    private int chapterIndex;
    
    /**
     * 章节全局序号
     */
    private int chapterOrder;
    
    /**
     * 章节标题
     */
    private String chapterTitle;
} 