package com.ainovel.server.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 剧情大纲模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "next_outlines")
public class NextOutline {

    /**
     * 大纲ID
     */
    @Id
    private String id;

    /**
     * 小说ID
     */
    private String novelId;

    /**
     * 大纲标题
     */
    private String title;

    /**
     * 大纲内容
     */
    private String content;

    /**
     * 使用的模型配置ID
     */
    private String configId;

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

    /**
     * 创建时间
     */
    private LocalDateTime createdAt;

    /**
     * 是否被选中
     */
    private boolean selected;

    // 新增字段：用于存储原始生成请求的上下文信息
    private String originalStartChapterId; // 原始请求的起始章节ID
    private String originalEndChapterId; // 原始请求的结束章节ID
    private String originalAuthorGuidance; // 原始请求的作者引导
    // private String originalContext; // (可选) 如果上下文不是基于章节范围，可以存原始上下文文本
}
