package com.ainovel.server.web.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成下一剧情大纲选项DTO
 */
public class GenerateNextOutlinesDTO {

    /**
     * 请求DTO
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Request {

        /**
         * 小说ID
         */
        private String novelId;

        /**
         * 当前剧情上下文
         */
        private String currentContext;

        /**
         * 生成选项数量
         */
        private Integer numberOfOptions;

        /**
         * 作者引导
         */
        private String authorGuidance;
    }

    /**
     * 响应DTO
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Response {

        /**
         * 生成的大纲选项列表
         */
        private List<OutlineOption> options;

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
     * 大纲选项
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OutlineOption {

        /**
         * 选项ID
         */
        private String id;

        /**
         * 标题
         */
        private String title;

        /**
         * 内容
         */
        private String content;

        /**
         * 关键情节点
         */
        private List<String> keyPoints;
    }
}
