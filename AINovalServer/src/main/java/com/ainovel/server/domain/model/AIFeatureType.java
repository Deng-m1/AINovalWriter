package com.ainovel.server.domain.model;

/**
 * AI功能类型枚举 用于定义不同AI功能的类型标识
 */
public enum AIFeatureType {
    /**
     * 场景生成摘要
     */
    SCENE_TO_SUMMARY,
    /**
     * 摘要生成场景
     */
    SUMMARY_TO_SCENE

    // 未来可扩展其他功能点，如角色生成、大纲优化等
}
