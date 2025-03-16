package com.ainovel.server.service;

import java.util.List;

import com.ainovel.server.domain.model.Scene;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 场景服务接口
 */
public interface SceneService {
    
    /**
     * 根据ID查找场景
     * @param id 场景ID
     * @return 场景信息
     */
    Mono<Scene> findSceneById(String id);
    
    /**
     * 根据章节ID查找场景
     * @param chapterId 章节ID
     * @return 场景列表
     */
    Flux<Scene> findSceneByChapterId(String chapterId);
    
    /**
     * 根据章节ID查找场景并按顺序排序
     * @param chapterId 章节ID
     * @return 排序后的场景列表
     */
    Flux<Scene> findSceneByChapterIdOrdered(String chapterId);
    
    /**
     * 根据小说ID查找场景列表
     * @param novelId 小说ID
     * @return 场景列表
     */
    Flux<Scene> findScenesByNovelId(String novelId);
    
    /**
     * 根据小说ID查找场景列表并按章节和顺序排序
     * @param novelId 小说ID
     * @return 排序后的场景列表
     */
    Flux<Scene> findScenesByNovelIdOrdered(String novelId);
    
    /**
     * 根据章节ID列表查找场景
     * @param chapterIds 章节ID列表
     * @return 场景列表
     */
    Flux<Scene> findScenesByChapterIds(List<String> chapterIds);
    
    /**
     * 根据小说ID和场景类型查找场景
     * @param novelId 小说ID
     * @param sceneType 场景类型
     * @return 场景列表
     */
    Flux<Scene> findScenesByNovelIdAndType(String novelId, String sceneType);
    
    /**
     * 创建场景
     * @param scene 场景信息
     * @return 创建的场景
     */
    Mono<Scene> createScene(Scene scene);
    
    /**
     * 批量创建场景
     * @param scenes 场景列表
     * @return 创建的场景列表
     */
    Flux<Scene> createScenes(List<Scene> scenes);
    
    /**
     * 更新场景
     * @param id 场景ID
     * @param scene 更新的场景信息
     * @return 更新后的场景
     */
    Mono<Scene> updateScene(String id, Scene scene);
    
    /**
     * 创建或更新场景
     * 如果场景不存在则创建，存在则更新
     * @param scene 场景信息
     * @return 创建或更新后的场景
     */
    Mono<Scene> upsertScene(Scene scene);
    
    /**
     * 批量创建或更新场景
     * @param scenes 场景列表
     * @return 创建或更新后的场景列表
     */
    Flux<Scene> upsertScenes(List<Scene> scenes);
    
    /**
     * 删除场景
     * @param id 场景ID
     * @return 操作结果
     */
    Mono<Void> deleteScene(String id);
    
    /**
     * 删除小说的所有场景
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteScenesByNovelId(String novelId);
    
    /**
     * 删除章节的所有场景
     * @param chapterId 章节ID
     * @return 操作结果
     */
    Mono<Void> deleteScenesByChapterId(String chapterId);
} 