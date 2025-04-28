package com.ainovel.server.task.dto.continuecontent;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 自动续写小说章节内容任务进度
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ContinueWritingContentProgress {
    
    /**
     * 当前阶段
     * GENERATING_SUMMARIES: 正在生成摘要
     * WAITING_FOR_REVIEW: 等待用户评审摘要
     * GENERATING_CONTENT: 正在生成内容
     * COMPLETED: 任务已完成
     */
    private String stage;
    
    /**
     * 总共需要生成的章节数
     */
    private int totalChapters;
    
    /**
     * 已成功生成摘要的章节数
     */
    private int summariesCompleted;
    
    /**
     * 已成功生成内容的章节数
     */
    private int contentsCompleted;
    
    /**
     * 失败的章节数
     */
    private int failed;
    
    /**
     * 当前处理的章节索引（从0开始）
     */
    private int currentIndex;
    
    /**
     * 当前阶段完成百分比（0-100）
     */
    private int percentComplete;
    
    /**
     * 大纲是否已生成完成
     */
    private boolean outlinesGenerated;
    
    /**
     * 生成的大纲列表（使用Map存储而不是依赖特定类）
     */
    @Builder.Default
    private List<Map<String, Object>> outlines = new ArrayList<>();
    
    /**
     * 已完成的章节数量（响应式架构）
     */
    private int completedChapters;
    
    /**
     * 失败的章节数量（响应式架构）
     */
    private int failedChapters;
    
    /**
     * 章节生成结果列表（使用Map存储而不是依赖特定类）
     */
    @Builder.Default
    private List<Map<String, Object>> chapterResults = new ArrayList<>();
} 