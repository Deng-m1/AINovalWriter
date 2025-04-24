package com.ainovel.server.domain.model;

/**
 * 模型列表能力枚举
 * 定义了AI提供商对模型列表的支持能力
 */
public enum ModelListingCapability {
    /**
     * 不支持获取模型列表
     */
    NO_LISTING,
    
    /**
     * 无需API密钥即可获取模型列表
     */
    LISTING_WITHOUT_KEY,
    
    /**
     * 需要有效的API密钥才能获取模型列表
     */
    LISTING_WITH_KEY,
    
    /**
     * 支持两种方式获取模型列表，有API密钥时使用API密钥，无API密钥时回退到无密钥方式
     */
    LISTING_WITH_OR_WITHOUT_KEY
} 