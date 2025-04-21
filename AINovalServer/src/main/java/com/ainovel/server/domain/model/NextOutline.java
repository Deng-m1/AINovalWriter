package com.ainovel.server.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 剧情大纲模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NextOutline {

    /**
     * 大纲ID
     */
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
}
