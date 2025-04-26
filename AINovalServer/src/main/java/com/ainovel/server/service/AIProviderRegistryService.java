package com.ainovel.server.service;

import com.ainovel.server.domain.model.ModelListingCapability;

import reactor.core.publisher.Mono;

/**
 * AI 提供商注册服务接口
 * 负责管理和提供关于 AI 提供商类型的基础信息和能力。
 */
public interface AIProviderRegistryService {

    /**
     * 获取指定 AI 提供商类型的模型列表获取能力。
     *
     * @param providerName 提供商名称 (e.g., "openai", "anthropic")
     * @return 包含 ModelListingCapability 的 Mono，如果提供商类型未知则为空 Mono。
     */
    Mono<ModelListingCapability> getProviderListingCapability(String providerName);

    // 未来可以扩展此服务以提供其他提供商类型的元数据，例如：
    // - 是否支持流式传输
    // - 是否支持特定功能（图像输入、函数调用等）
    // - 默认 API 端点
    // - 图标或品牌信息
} 