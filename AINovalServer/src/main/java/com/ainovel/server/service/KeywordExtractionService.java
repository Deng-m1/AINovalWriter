package com.ainovel.server.service;

import java.util.List;

import reactor.core.publisher.Mono;

/**
 * 关键词提取服务接口
 * 使用轻量级LLM从文本中提取关键词
 */
public interface KeywordExtractionService {
    
    /**
     * 从文本中提取关键词
     * @param text 文本内容
     * @return 关键词列表
     */
    Mono<List<String>> extractKeywords(String text);
    
    /**
     * 从文本中提取关键词，并限制返回数量
     * @param text 文本内容
     * @param maxKeywords 最大关键词数量
     * @return 关键词列表
     */
    Mono<List<String>> extractKeywords(String text, int maxKeywords);
} 