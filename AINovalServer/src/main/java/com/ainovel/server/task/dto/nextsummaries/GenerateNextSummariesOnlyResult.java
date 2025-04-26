package com.ainovel.server.task.dto.nextsummaries;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 自动续写小说章节摘要任务结果
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
     * 成功生成摘要的数量
     */
    private int summariesGeneratedCount;
    
    /**
     * 最终任务状态
     * COMPLETED: 所有摘要生成成功
     * COMPLETED_WITH_ERRORS: 部分摘要生成成功
     * FAILED: 所有摘要生成失败
     */
    private String status;
    
    /**
     * 记录失败的章节ID或步骤
     */
    private List<String> failedSteps;
} 