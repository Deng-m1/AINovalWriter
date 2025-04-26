package com.ainovel.server.task.dto.continuecontent;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 单个章节内容生成任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateChapterContentParameters {
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 章节ID
     */
    private String chapterId;
    
    /**
     * 章节序号（在当前任务中的索引，从0开始）
     */
    private int chapterIndex;
    
    /**
     * 全局章节序号
     */
    private int chapterOrder;
    
    /**
     * 章节标题
     */
    private String chapterTitle;
    
    /**
     * 章节摘要
     */
    private String chapterSummary;
    
    /**
     * 内容生成用的AI配置ID
     */
    private String aiConfigId;
    
    /**
     * 内容生成上下文
     */
    private String context;
    
    /**
     * 写作风格提示
     */
    private String writingStyle;
} 