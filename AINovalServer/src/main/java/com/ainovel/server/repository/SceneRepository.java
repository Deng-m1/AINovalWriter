package com.ainovel.server.repository;

import java.util.List;

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
     * @return 场景列表
     */
    Flux<Scene> findByChapterId(String chapterId);

    /**
     * 根据章节ID查找场景并按顺序排序
     * @param chapterId 章节ID
     * @return 排序后的场景列表
     */
    Flux<Scene> findByChapterIdOrderBySequenceAsc(String chapterId);

    /**
     * 根据小说ID查找场景并按章节ID和顺序排序
     * @param novelId 小说ID
     * @return 排序后的场景列表
     */
    Flux<Scene> findByNovelIdOrderByChapterIdAscSequenceAsc(String novelId);

    /**
     * 根据章节ID列表查找场景
     * @param chapterIds 章节ID列表
     * @return 场景列表
     */
    Flux<Scene> findByChapterIdIn(List<String> chapterIds);

    /**
     * 根据小说ID和场景类型查找场景
     * @param novelId 小说ID
     * @param sceneType 场景类型
     * @return 场景列表
     */
    Flux<Scene> findByNovelIdAndSceneType(String novelId, String sceneType);

    /**
     * 删除小说的所有场景
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteByNovelId(String novelId);

    /**
     * 删除章节的所有场景
     * @param chapterId 章节ID
     * @return 操作结果
     */
    Mono<Void> deleteByChapterId(String chapterId);
}