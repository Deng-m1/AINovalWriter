package com.ainovel.server.task.dto.scenegeneration;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 生成场景任务的参数DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSceneParameters {

    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 章节ID
     */
    private String chapterId;
    
    /**
     * 场景摘要或提示
     */
    private String summary;
    
    /**
     * 场景标题（可选）
     */
    private String title;
    
    /**
     * 场景中的角色ID列表（可选）
     */
    private List<String> characterIds;
    
    /**
     * 场景地点（可选）
     */
    private List<String> locations;
    
    /**
     * 用户自定义提示（可选）
     */
    private String customPrompt;
    
    /**
     * AI配置ID（可选）
     */
    private String aiConfigId;
    
    /**
     * 目标场景长度（字数，可选）
     */
    private Integer targetWordCount;
    
    /**
     * 是否生成向量嵌入（可选）
     */
    @Builder.Default
    private Boolean generateEmbedding = false;
} 