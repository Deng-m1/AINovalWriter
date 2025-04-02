package com.ainovel.server.service;

import com.ainovel.server.domain.model.KnowledgeChunk;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 知识库服务接口
 */
public interface KnowledgeService {

    /**
     * 索引内容
     *
     * @param novelId 小说ID
     * @param sourceType 源类型（scene, character, setting, note等）
     * @param sourceId 源ID
     * @param content 内容
     * @return 创建的知识块
     */
    Mono<KnowledgeChunk> indexContent(String novelId, String sourceType, String sourceId, String content);

    /**
     * 检索相关上下文
     *
     * @param query 查询文本
     * @param novelId 小说ID
     * @return 相关上下文
     */
    Mono<String> retrieveRelevantContext(String query, String novelId);

    /**
     * 检索相关上下文
     *
     * @param query 查询文本
     * @param novelId 小说ID
     * @param limit 限制数量
     * @return 相关上下文
     */
    Mono<String> retrieveRelevantContext(String query, String novelId, int limit);

    /**
     * 语义搜索
     *
     * @param query 查询文本
     * @param novelId 小说ID
     * @param limit 限制数量
     * @return 搜索结果
     */
    Flux<KnowledgeChunk> semanticSearch(String query, String novelId, int limit);

    /**
     * 删除知识块
     *
     * @param novelId 小说ID
     * @param sourceType 源类型
     * @param sourceId 源ID
     * @return 操作结果
     */
    Mono<Void> deleteKnowledgeChunks(String novelId, String sourceType, String sourceId);

    /**
     * 重新索引小说
     *
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> reindexNovel(String novelId);
}
