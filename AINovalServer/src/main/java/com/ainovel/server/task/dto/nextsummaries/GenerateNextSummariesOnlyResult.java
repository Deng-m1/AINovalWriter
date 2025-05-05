package com.ainovel.server.task.dto.nextsummaries;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 生成后续章节摘要任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateNextSummariesOnlyResult {
    
    /**
     * 新创建的章节ID列表
     */
    private List<String> newChapterIds;
    
    /**
     * 生成的摘要内容列表
     */
    private List<String> summaries;
    
    /**
     * 成功生成的摘要数量
     */
    private int summariesGeneratedCount;
    
    /**
     * 总共需要生成的章节数
     */
    private int totalChapters;
    
    /**
     * 失败的生成步骤信息
     */
    private List<String> failedChapters;
    
    /**
     * 任务状态
     * COMPLETED: 全部成功完成
     * COMPLETED_WITH_ERRORS: 部分成功，部分失败
     * FAILED: 全部失败
     */
    private String status;
    
    /**
     * 失败的步骤列表
     */
    private List<String> failedSteps;
} 