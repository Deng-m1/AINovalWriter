package com.ainovel.server.service;

import reactor.core.publisher.Mono;

/**
 * 小说RAG助手接口 提供基于检索增强生成的小说检索功能
 */
public interface NovelRagAssistant {

    /**
     * 使用RAG上下文进行查询，只负责上下文检索
     *
     * @param novelId 小说ID
     * @param query 查询文本
     * @return 检索到的上下文
     */
    Mono<String> queryWithRagContext(String novelId, String query);
    
    /**
     * 检索与查询相关的上下文
     *
     * @param novelId 小说ID
     * @param query 查询文本
     * @return 上下文文本
     */
    Mono<String> retrieveRelevantContext(String novelId, String query);
    
    /**
     * 检索与查询相关的设定信息
     *
     * @param novelId 小说ID
     * @param query 查询文本
     * @return 设定上下文文本
     */
    Mono<String> retrieveRelevantSettings(String novelId, String query);
    
    /**
     * 提取文本的最后几个段落
     * 
     * @param text 文本
     * @param paragraphCount 段落数
     * @return 最后的段落
     */
    String extractLastParagraphs(String text, int paragraphCount);
}
