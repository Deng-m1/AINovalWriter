package com.ainovel.server.service;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * AI服务接口
 */
public interface AIService {
    
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
     * 获取可用的AI模型列表
     * @return 模型列表
     */
    Flux<String> getAvailableModels();
} 