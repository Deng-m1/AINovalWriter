package com.ainovel.server.task.dto.continuecontent;

import com.ainovel.server.domain.model.Novel.Chapter;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 单个章节内容生成任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateChapterContentResult {
    
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
     * 生成的章节对象
     */
    private Chapter chapter;
    
    /**
     * 生成的场景IDs
     */
    private java.util.List<String> sceneIds;
    
    /**
     * 是否成功生成
     */
    private boolean success;
    
    /**
     * 错误信息（如果有）
     */
    private String errorMessage;
} 