package com.ainovel.server.task.dto.continuecontent;

import com.ainovel.server.domain.model.Novel.Chapter;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 自动续写小说章节内容任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ContinueWritingContentResult {
    
    /**
     * 生成的章节列表
     */
    private List<Chapter> generatedChapters;
    
    /**
     * 任务是否成功完成
     */
    private boolean success;
    
    /**
     * 错误信息（如果有）
     */
    private String errorMessage;
    
    /**
     * 任务当前状态
     */
    private String status;
    
    /**
     * 当前阶段已完成的章节数量
     */
    private int completedChapters;
    
    /**
     * 总章节数量
     */
    private int totalChapters;
} 