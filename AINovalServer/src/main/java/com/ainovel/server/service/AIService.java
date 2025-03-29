package com.ainovel.server.service;

import java.util.List;
import java.util.Map;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.service.ai.AIModelProvider;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 基础AI服务接口 只处理与AI模型交互的基础功能，不包含业务逻辑
 */
public interface AIService {

    /**
     * 生成内容 (非流式)
     *
     * @param request 包含提示、消息、模型名、参数等的请求对象
     * @param apiKey 用户提供的API Key
     * @param apiEndpoint 用户提供的API Endpoint (可选)
     * @return AI响应
     */
    Mono<AIResponse> generateContent(AIRequest request, String apiKey, String apiEndpoint);

    /**
     * 生成内容 (流式)
     *
     * @param request 包含提示、消息、模型名、参数等的请求对象
     * @param apiKey 用户提供的API Key
     * @param apiEndpoint 用户提供的API Endpoint (可选)
     * @return 响应内容流
     */
    Flux<String> generateContentStream(AIRequest request, String apiKey, String apiEndpoint);

    /**
     * 获取系统支持的所有模型
     *
     * @return 模型名称流
     */
    Flux<String> getAvailableModels();

    /**
     * 估算请求成本 (可能需要API Key)
     *
     * @param request 请求对象
     * @param apiKey API Key
     * @param apiEndpoint API Endpoint (可选)
     * @return 估算成本
     */
    Mono<Double> estimateCost(AIRequest request, String apiKey, String apiEndpoint);

    /**
     * 验证用户提供的API Key是否有效.
     *
     * @param userId 用户ID (可选，用于日志或特定逻辑)
     * @param provider 模型提供商 (e.g., "openai")
     * @param modelName 模型名称 (用于选择合适的验证端点或方式)
     * @param apiKey 要验证的API Key
     * @param apiEndpoint API Endpoint (可选, 例如用于自建或代理的OpenAI兼容API)
     * @return 如果有效则为true，否则为false
     */
    Mono<Boolean> validateApiKey(String userId, String provider, String modelName, String apiKey, String apiEndpoint);

    /**
     * 获取指定模型的提供商名称
     *
     * @param modelName 模型名称
     * @return 提供商名称 (小写)
     */
    String getProviderForModel(String modelName);

    /**
     * 获取指定提供商支持的模型列表
     *
     * @param provider 提供商名称 (小写)
     * @return 模型列表
     */
    Flux<String> getModelsForProvider(String provider);

    /**
     * 获取所有支持的提供商
     *
     * @return 提供商名称列表 (小写)
     */
    Flux<String> getAvailableProviders();

    /**
     * 获取模型分组信息
     *
     * @return 模型分组Map
     */
    Map<String, List<String>> getModelGroups();

    /**
     * 创建AI模型提供商实例 (内部使用或高级场景)
     *
     * @param provider 提供商名称
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点 (可选)
     * @return AI模型提供商实例
     */
    AIModelProvider createAIModelProvider(String provider, String modelName, String apiKey, String apiEndpoint);

    /**
     * 设置是否使用LangChain4j实现 (全局配置)
     *
     * @param useLangChain4j 是否使用LangChain4j
     */
    void setUseLangChain4j(boolean useLangChain4j);
}
