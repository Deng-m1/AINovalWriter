package com.ainovel.server.task.dto.continuecontent;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 自动续写小说章节内容任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ContinueWritingContentParameters {
    
    /**
     * 小说ID
     */
    @NotBlank(message = "小说ID不能为空")
    private String novelId;
    
    /**
     * 要生成的章节数量
     */
    @NotNull(message = "续写章节数不能为空")
    @Min(value = 1, message = "续写章节数必须大于0")
    private Integer numberOfChapters;
    
    /**
     * 摘要生成用的AI配置ID
     */
    @NotBlank(message = "摘要AI配置ID不能为空")
    private String aiConfigIdSummary;
    
    /**
     * 内容生成用的AI配置ID
     */
    @NotBlank(message = "内容AI配置ID不能为空")
    private String aiConfigIdContent;
    
    /**
     * 上下文获取模式
     * AUTO: 由后端决定（如最后3章内容+全局设定）
     * LAST_N_CHAPTERS: 需配合contextChapterCount
     * CUSTOM: 需配合customContext
     */
    private String startContextMode = "AUTO";
    
    /**
     * 当startContextMode为LAST_N_CHAPTERS时使用
     */
    private Integer contextChapterCount;
    
    /**
     * 当startContextMode为CUSTOM时使用
     */
    private String customContext;
    
    /**
     * 写作风格提示
     */
    private String writingStyle;
    
    /**
     * 是否需要在生成摘要后暂停，等待用户评审
     */
    private boolean requiresReview = false;

    private boolean persistChanges = true;
} 