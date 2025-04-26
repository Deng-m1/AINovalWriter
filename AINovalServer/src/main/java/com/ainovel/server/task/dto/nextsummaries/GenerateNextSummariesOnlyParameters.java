package com.ainovel.server.task.dto.nextsummaries;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 自动续写小说章节摘要任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateNextSummariesOnlyParameters {
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 要生成的章节数量
     */
    private int numberOfChapters;
    
    /**
     * 摘要生成用的AI配置ID
     */
    private String aiConfigIdSummary;
    
    /**
     * 上下文获取模式
     * LAST_CHAPTER: 仅使用最后一章作为上下文
     * LAST_THREE_CHAPTERS: 使用最后三章作为上下文
     * ALL_CHAPTERS: 使用所有章节作为上下文
     */
    private String startContextMode;
} 