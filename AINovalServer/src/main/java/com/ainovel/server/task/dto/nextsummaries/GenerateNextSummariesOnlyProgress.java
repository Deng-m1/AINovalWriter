package com.ainovel.server.task.dto.nextsummaries;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 自动续写小说章节摘要任务进度
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateNextSummariesOnlyProgress {
    
    /**
     * 总共需要生成的章节数
     */
    private int total;
    
    /**
     * 当前已成功生成摘要的章节数
     */
    private int completed;
    
    /**
     * 失败的章节数
     */
    private int failed;
    
    /**
     * 当前正在处理的章节索引（从0开始）
     */
    private int currentIndex;
} 