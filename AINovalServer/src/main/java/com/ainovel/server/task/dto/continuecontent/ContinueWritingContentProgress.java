package com.ainovel.server.task.dto.continuecontent;

import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

/**
 * 自动续写小说章节内容任务进度
 */
@Data
@NoArgsConstructor
public class ContinueWritingContentProgress {
    
    /**
     * 总共需要生成的章节数
     */
    private int totalChapters;
    
    /**
     * 已成功生成章节数
     */
    private int chaptersCompleted;
    
    /**
     * 失败的章节数
     */
    private int failedChapters;
    
    /**
     * 当前阶段
     * GENERATING_SUMMARIES: 正在生成摘要
     * WAITING_FOR_REVIEW: 等待用户评审摘要
     * GENERATING_CONTENT: 正在生成内容
     * COMPLETED: 任务已完成
     */
    private String currentStep; // e.g., STARTING, GENERATING_SUMMARY_1, GENERATING_CONTENT_1, GENERATING_SUMMARY_2, ... FINISHED
    
    /**
     * 最后一次错误消息
     */
    private String lastError; // Store last relevant error message
    
    /**
     * 已成功生成章节的ID列表
     */
    private List<String> completedChapterIds = new ArrayList<>();
} 