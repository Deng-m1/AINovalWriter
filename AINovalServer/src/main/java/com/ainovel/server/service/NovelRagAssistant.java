package com.ainovel.server.service;

import reactor.core.publisher.Mono;

/**
 * 小说RAG助手接口 提供基于检索增强生成的小说辅助功能
 */
public interface NovelRagAssistant {

    /**
     * 使用RAG上下文进行查询
     *
     * @param novelId 小说ID
     * @param query 查询文本
     * @return 查询结果
     */
    Mono<String> queryWithRagContext(String novelId, String query);
}
