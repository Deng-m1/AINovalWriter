package com.ainovel.server.task.dto.nextsummaries;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成后续章节摘要任务参数
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
     * 可选值: AUTO - 自动选择合适的上下文
     *       LAST_N_CHAPTERS - 使用最近N章作为上下文 
     *       CUSTOM - 使用自定义上下文
     */
    private String startContextMode;
    
    /**
     * 上下文包含的章节数量 (当startContextMode为LAST_N_CHAPTERS时使用)
     */
    private Integer contextChapterCount;
    
    /**
     * 自定义上下文内容 (当startContextMode为CUSTOM时使用)
     */
    private String customContext;
    
    /**
     * 写作风格指示
     */
    private String writingStyle;
} 