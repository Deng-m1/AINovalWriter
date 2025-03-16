package com.ainovel.server.service;

import reactor.core.publisher.Mono;

/**
 * 嵌入服务接口
 * 提供文本向量化功能
 */
public interface EmbeddingService {
    
    /**
     * 生成文本的向量嵌入
     * 使用默认的嵌入模型
     * @param text 文本内容
     * @return 向量嵌入
     */
    Mono<float[]> generateEmbedding(String text);
    
    /**
     * 生成文本的向量嵌入
     * @param text 文本内容
     * @param modelName 模型名称
     * @return 向量嵌入
     */
    Mono<float[]> generateEmbedding(String text, String modelName);
} 