package com.ainovel.server.repository;

import org.springframework.data.mongodb.repository.ReactiveMongoRepository;
import org.springframework.stereotype.Repository;

import com.ainovel.server.domain.model.Scene;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 场景仓库接口
 */
@Repository
public interface SceneRepository extends ReactiveMongoRepository<Scene, String> {
    
    /**
     * 根据小说ID查找场景
     * @param novelId 小说ID
     * @return 场景列表
     */
    Flux<Scene> findByNovelId(String novelId);
    
    /**
     * 根据章节ID查找场景
     * @param chapterId 章节ID
     * @return 场景
     */
    Mono<Scene> findByChapterId(String chapterId);
} 