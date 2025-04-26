package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

/**
 * 剧情大纲DTO
 */
public class NextOutlineDTO {

    /**
     * 生成剧情大纲请求
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GenerateRequest {

        /**
         * 目标章节/剧情点
         * @deprecated 使用startChapterId和endChapterId替代
         */
        @Deprecated
        private String targetChapter;

        /**
         * 上下文开始章节ID
         */
        private String startChapterId;

        /**
         * 上下文结束章节ID
         */
        private String endChapterId;

        /**
         * 生成选项数量
         */
        @Min(value = 1, message = "生成选项数量至少为1")
        @Builder.Default
        private int numOptions = 3;

        /**
         * 作者引导
         */
        private String authorGuidance;
        
        /**
         * 选定的AI模型配置ID列表
         */
        private List<String> selectedConfigIds;
        
        /**
         * 重新生成提示（用于全局重新生成）
         */
        private String regenerateHint;
    }

    /**
     * 生成剧情大纲响应
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GenerateResponse {

        /**
         * 生成的大纲列表
         */
        private List<OutlineItem> outlines;

        /**
         * 生成时间(毫秒)
         */
        private long generationTimeMs;
    }

    /**
     * 大纲项
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OutlineItem {

        /**
         * 大纲ID
         */
        private String id;

        /**
         * 大纲标题
         */
        private String title;

        /**
         * 大纲内容
         */
        private String content;

        /**
         * 是否被选中
         */
        private boolean isSelected;
        
        /**
         * 使用的模型配置ID
         */
        private String configId;
    }
    
    /**
     * 重新生成单个剧情大纲请求
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RegenerateOptionRequest {
        
        /**
         * 要重新生成的剧情选项ID
         */
        @NotBlank(message = "选项ID不能为空")
        private String optionId;
        
        /**
         * 选定的AI模型配置ID
         */
        @NotBlank(message = "模型配置ID不能为空")
        private String selectedConfigId;
        
        /**
         * 重新生成提示
         */
        private String regenerateHint;
    }

    /**
     * 保存剧情大纲请求
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SaveRequest {

        /**
         * 大纲ID
         */
        @NotBlank(message = "大纲ID不能为空")
        private String outlineId;

        /**
         * 插入位置类型
         * CHAPTER_END: 章节末尾
         * BEFORE_SCENE: 场景之前
         * AFTER_SCENE: 场景之后
         * NEW_CHAPTER: 新建章节（默认）
         */
        @Builder.Default
        private String insertType = "NEW_CHAPTER";

        /**
         * 目标章节ID（当insertType为CHAPTER_END时使用）
         */
        private String targetChapterId;

        /**
         * 目标场景ID（当insertType为BEFORE_SCENE或AFTER_SCENE时使用）
         */
        private String targetSceneId;

        /**
         * 是否创建新场景（默认为true）
         */
        @Builder.Default
        private boolean createNewScene = true;
    }

    /**
     * 保存剧情大纲响应
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SaveResponse {

        /**
         * 是否成功
         */
        private boolean success;

        /**
         * 保存的大纲ID
         */
        private String outlineId;

        /**
         * 新创建的章节ID（如果有）
         */
        private String newChapterId;

        /**
         * 新创建的场景ID（如果有）
         */
        private String newSceneId;

        /**
         * 目标章节ID（如果指定了现有章节）
         */
        private String targetChapterId;

        /**
         * 目标场景ID（如果指定了现有场景）
         */
        private String targetSceneId;

        /**
         * 插入位置类型
         */
        private String insertType;

        /**
         * 大纲标题（用于新章节标题）
         */
        private String outlineTitle;
    }
    
    /**
     * 流式生成大纲块
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OutlineGenerationChunk {
        /**
         * 选项ID
         */
        private String optionId;
        
        /**
         * 选项标题
         */
        private String optionTitle;
        
        /**
         * 文本片段
         */
        private String textChunk;
        
        /**
         * 是否最终片段
         */
        private boolean isFinalChunk;
        
        /**
         * 错误信息（如果有）
         */
        private String error;
    }
}
