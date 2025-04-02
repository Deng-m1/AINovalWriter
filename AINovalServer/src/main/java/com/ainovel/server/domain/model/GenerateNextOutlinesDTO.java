package com.ainovel.server.domain.model;

import java.util.List;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成下一剧情大纲选项的请求和响应DTO
 */
public class GenerateNextOutlinesDTO {

    /**
     * 生成下一剧情大纲选项的请求
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Request {

        /**
         * 小说ID
         */
        @NotBlank(message = "小说ID不能为空")
        private String novelId;

        /**
         * 当前剧情上下文 可以是最近一个场景的ID、章节ID，或者一段简要的剧情梗概
         */
        @NotBlank(message = "当前剧情上下文不能为空")
        private String currentContext;

        /**
         * 希望生成的大纲数量
         */
        @Min(value = 1, message = "大纲数量至少为1")
        @Builder.Default
        private Integer numberOfOptions = 3;

        /**
         * 作者希望下一剧情发展的方向或规避的元素
         */
        private String authorGuidance;
    }

    /**
     * 生成下一剧情大纲选项的响应
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Response {

        /**
         * 生成的大纲选项列表
         */
        private List<PlotOutline> outlines;

        /**
         * 生成时间(毫秒)
         */
        private long generationTimeMs;

        /**
         * 使用的模型
         */
        private String model;
    }

    /**
     * 剧情大纲
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PlotOutline {

        /**
         * 大纲标题
         */
        private String title;

        /**
         * 大纲概要
         */
        private String summary;

        /**
         * 主要事件
         */
        private List<String> mainEvents;

        /**
         * 涉及的角色
         */
        private List<String> characters;

        /**
         * 冲突或悬念
         */
        private List<String> conflicts;
    }
}
