package com.ainovel.server.service.ai;

/**
 * 定义 AI 提供商获取其模型列表的能力。
 */
public enum ModelListingCapability {
    /**
     * 提供商不支持通过 API 获取模型列表。
     * 前端应仅显示基于硬编码或默认配置的模型。
     */
    NO_LISTING,

    /**
     * 提供商可以在不需要 API Key 的情况下获取模型列表。
     * 前端可以直接调用 `listModels()` 对应的接口。
     */
    LISTING_WITHOUT_KEY,

    /**
     * 提供商需要有效的 API Key 才能获取模型列表。
     * 前端应提示用户输入 API Key，并在验证成功后调用 `listModelsWithApiKey()` 对应的接口。
     */
    LISTING_WITH_KEY,

    /**
     * 提供商既支持无 Key 获取（可能为默认或部分列表），也支持使用 Key 获取（可能为完整或用户特定列表）。
     * 前端可以先尝试无 Key 获取，并在 Key 验证后再次获取。
     * (注意: 当前实现中可能简化处理，优先使用 Key 获取)
     */
    LISTING_WITH_OR_WITHOUT_KEY
} 