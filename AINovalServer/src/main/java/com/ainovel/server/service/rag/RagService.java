package com.ainovel.server.service.rag;

import com.ainovel.server.domain.model.AIFeatureType;

import reactor.core.publisher.Mono;

/**
 * RAG服务接口
 * 提供基于检索增强生成的上下文获取服务
 */
public interface RagService {
    
    /**
     * 根据小说、场景/章节/位置信息以及目标AI功能，检索相关上下文
     * 
     * @param novelId 小说ID
     * @param contextId 可选，如sceneId
     * @param featureType 目标AI功能类型
     * @return 格式化后的上下文文本
     */
    Mono<String> retrieveRelevantContext(String novelId, String contextId, AIFeatureType featureType);
    
    /**
     * 根据小说、场景/章节/位置信息以及目标AI功能，检索相关上下文
     * 
     * @param novelId 小说ID
     * @param contextId 可选，如sceneId
     * @param positionHint 可选，如章节ID或位置信息
     * @param featureType 目标AI功能类型
     * @return 格式化后的上下文文本
     */
    Mono<String> retrieveRelevantContext(String novelId, String contextId, Object positionHint, AIFeatureType featureType);
} 