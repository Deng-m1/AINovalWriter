package com.ainovel.server.service;

import java.util.List;
import java.util.Map;

import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.BaseAIRequest;
import com.ainovel.server.service.ai.AIModelProvider;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 基础AI服务接口 只处理与AI模型交互的基础功能，不包含业务逻辑
 */
public interface AIService {

    /**
     * 生成内容（非流式）
     *
     * @param request 基础AI请求
     * @return AI响应
     */
    Mono<AIResponse> generateContent(BaseAIRequest request);

    /**
     * 生成内容（流式）
     *
     * @param request 基础AI请求
     * @return 流式AI响应
     */
    Flux<String> generateContentStream(BaseAIRequest request);

    /**
     * 获取可用的AI模型列表
     *
     * @return 模型列表
     */
    Flux<String> getAvailableModels();

    /**
     * 估算请求成本
     *
     * @param request 基础AI请求
     * @return 估算成本（单位：元）
     */
    Mono<Double> estimateCost(BaseAIRequest request);

    /**
     * 验证API密钥是否有效
     *
     * @param userId 用户ID
     * @param provider 提供商名称
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @return 是否有效
     */
    Mono<Boolean> validateApiKey(String userId, String provider, String modelName, String apiKey);

    /**
     * 获取模型的提供商名称
     *
     * @param modelName 模型名称
     * @return 提供商名称
     */
    String getProviderForModel(String modelName);

    /**
     * 获取提供商支持的模型列表
     *
     * @param provider 提供商名称
     * @return 模型列表
     */
    Flux<String> getModelsForProvider(String provider);

    /**
     * 获取所有支持的提供商
     *
     * @return 提供商列表
     */
    Flux<String> getAvailableProviders();

    /**
     * 获取模型分组信息
     *
     * @return 模型分组信息
     */
    Map<String, List<String>> getModelGroups();

    /**
     * 清除用户的模型提供商缓存
     *
     * @param userId 用户ID
     * @return 操作结果
     */
    Mono<Void> clearUserProviderCache(String userId);

    /**
     * 清除所有模型提供商缓存
     *
     * @return 操作结果
     */
    Mono<Void> clearAllProviderCache();

    /**
     * 设置模型提供商的代理
     *
     * @param userId 用户ID
     * @param modelName 模型名称
     * @param proxyHost 代理主机
     * @param proxyPort 代理端口
     * @return 操作结果
     */
    Mono<Void> setModelProviderProxy(String userId, String modelName, String proxyHost, int proxyPort);

    /**
     * 禁用模型提供商的代理
     *
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return 操作结果
     */
    Mono<Void> disableModelProviderProxy(String userId, String modelName);

    /**
     * 检查模型提供商的代理是否已启用
     *
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return 是否已启用
     */
    Mono<Boolean> isModelProviderProxyEnabled(String userId, String modelName);

    /**
     * 创建AI模型提供商
     *
     * @param provider 提供商名称
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @return AI模型提供商
     */
    AIModelProvider createAIModelProvider(String provider, String modelName, String apiKey, String apiEndpoint);

    /**
     * 设置是否使用LangChain4j实现
     *
     * @param useLangChain4j 是否使用LangChain4j
     */
    void setUseLangChain4j(boolean useLangChain4j);
}
