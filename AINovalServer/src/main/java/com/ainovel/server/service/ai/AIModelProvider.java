package com.ainovel.server.service.ai;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * AI模型提供商接口
 */
public interface AIModelProvider {
    
    /**
     * 获取提供商名称
     * @return 提供商名称
     */
    String getProviderName();
    
    /**
     * 获取模型名称
     * @return 模型名称
     */
    String getModelName();
    
    /**
     * 生成内容（非流式）
     * @param request AI请求
     * @return AI响应
     */
    Mono<AIResponse> generateContent(AIRequest request);
    
    /**
     * 生成内容（流式）
     * @param request AI请求
     * @return 流式AI响应
     */
    Flux<String> generateContentStream(AIRequest request);
    
    /**
     * 估算请求成本
     * @param request AI请求
     * @return 估算成本（单位：元）
     */
    Mono<Double> estimateCost(AIRequest request);
    
    /**
     * 检查API密钥是否有效
     * @return 是否有效
     */
    Mono<Boolean> validateApiKey();
    
    /**
     * 设置HTTP代理
     * @param host 代理主机
     * @param port 代理端口
     */
    void setProxy(String host, int port);
    
    /**
     * 禁用HTTP代理
     */
    void disableProxy();
    
    /**
     * 检查代理是否已启用
     * @return 是否已启用
     */
    boolean isProxyEnabled();
} 