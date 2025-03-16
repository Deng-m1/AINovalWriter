package com.ainovel.server.repository;

import org.springframework.data.mongodb.repository.ReactiveMongoRepository;
import org.springframework.stereotype.Repository;

import com.ainovel.server.domain.model.KnowledgeChunk;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 知识块仓库接口
 */
@Repository
public interface KnowledgeChunkRepository extends ReactiveMongoRepository<KnowledgeChunk, String> {
    
    /**
     * 根据小说ID查找知识块
     * @param novelId 小说ID
     * @return 知识块流
     */
    Flux<KnowledgeChunk> findByNovelId(String novelId);
    
    /**
     * 根据小说ID和源类型查找知识块
     * @param novelId 小说ID
     * @param sourceType 源类型
     * @return 知识块流
     */
    Flux<KnowledgeChunk> findByNovelIdAndSourceType(String novelId, String sourceType);
    
    /**
     * 根据小说ID、源类型和源ID查找知识块
     * @param novelId 小说ID
     * @param sourceType 源类型
     * @param sourceId 源ID
     * @return 知识块流
     */
    Flux<KnowledgeChunk> findByNovelIdAndSourceTypeAndSourceId(String novelId, String sourceType, String sourceId);
    
    /**
     * 根据小说ID删除知识块
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteByNovelId(String novelId);
    
    /**
     * 根据小说ID和源类型删除知识块
     * @param novelId 小说ID
     * @param sourceType 源类型
     * @return 操作结果
     */
    Mono<Void> deleteByNovelIdAndSourceType(String novelId, String sourceType);
    
    /**
     * 根据小说ID、源类型和源ID删除知识块
     * @param novelId 小说ID
     * @param sourceType 源类型
     * @param sourceId 源ID
     * @return 操作结果
     */
    Mono<Void> deleteByNovelIdAndSourceTypeAndSourceId(String novelId, String sourceType, String sourceId);
} 