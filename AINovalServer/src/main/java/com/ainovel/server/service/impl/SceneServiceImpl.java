package com.ainovel.server.service.impl;

import java.time.Instant;
import java.util.List;

import org.springframework.stereotype.Service;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.SceneService;

import lombok.RequiredArgsConstructor;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 场景服务实现
 */
@Service
@RequiredArgsConstructor
public class SceneServiceImpl implements SceneService {
    
    private final SceneRepository sceneRepository;
    
    @Override
    public Mono<Scene> findSceneById(String id) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)));
    }
    
    @Override
    public Flux<Scene> findSceneByChapterId(String chapterId) {
        return sceneRepository.findByChapterId(chapterId);
    }
    
    @Override
    public Flux<Scene> findSceneByChapterIdOrdered(String chapterId) {
        return sceneRepository.findByChapterIdOrderBySequenceAsc(chapterId);
    }
    
    @Override
    public Flux<Scene> findScenesByNovelId(String novelId) {
        return sceneRepository.findByNovelId(novelId);
    }
    
    @Override
    public Flux<Scene> findScenesByNovelIdOrdered(String novelId) {
        return sceneRepository.findByNovelIdOrderByChapterIdAscSequenceAsc(novelId);
    }
    
    @Override
    public Flux<Scene> findScenesByChapterIds(List<String> chapterIds) {
        return sceneRepository.findByChapterIdIn(chapterIds);
    }
    
    @Override
    public Flux<Scene> findScenesByNovelIdAndType(String novelId, String sceneType) {
        return sceneRepository.findByNovelIdAndSceneType(novelId, sceneType);
    }
    
    @Override
    public Mono<Scene> createScene(Scene scene) {
        // 设置创建和更新时间
        scene.setCreatedAt(Instant.now());
        scene.setUpdatedAt(Instant.now());
        
        // 设置初始版本
        scene.setVersion(1);
        
        // 如果没有设置序号，默认为0
        if (scene.getSequence() == null) {
            scene.setSequence(0);
        }
        
        return sceneRepository.save(scene);
    }
    
    @Override
    public Flux<Scene> createScenes(List<Scene> scenes) {
        // 设置创建和更新时间以及初始版本
        Instant now = Instant.now();
        scenes.forEach(scene -> {
            scene.setCreatedAt(now);
            scene.setUpdatedAt(now);
            scene.setVersion(1);
            
            // 如果没有设置序号，默认为0
            if (scene.getSequence() == null) {
                scene.setSequence(0);
            }
        });
        
        return sceneRepository.saveAll(scenes);
    }
    
    @Override
    public Mono<Scene> updateScene(String id, Scene scene) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .flatMap(existingScene -> {
                    // 保留原始ID和创建时间
                    scene.setId(existingScene.getId());
                    scene.setCreatedAt(existingScene.getCreatedAt());
                    
                    // 更新版本和更新时间
                    scene.setVersion(existingScene.getVersion() + 1);
                    scene.setUpdatedAt(Instant.now());
                    
                    // 如果没有设置小说ID或章节ID，使用原有的
                    if (scene.getNovelId() == null) {
                        scene.setNovelId(existingScene.getNovelId());
                    }
                    if (scene.getChapterId() == null) {
                        scene.setChapterId(existingScene.getChapterId());
                    }
                    
                    // 如果没有设置序号，使用原有的
                    if (scene.getSequence() == null) {
                        scene.setSequence(existingScene.getSequence());
                    }
                    
                    // 保存更新后的场景
                    return sceneRepository.save(scene);
                });
    }
    
    @Override
    public Mono<Scene> upsertScene(Scene scene) {
        // 如果场景ID为空，则创建新场景
        if (scene.getId() == null || scene.getId().isEmpty()) {
            return createScene(scene);
        }
        
        // 否则尝试更新，如果不存在则创建
        return sceneRepository.findById(scene.getId())
                .flatMap(existingScene -> updateScene(existingScene.getId(), scene))
                .switchIfEmpty(createScene(scene));
    }
    
    @Override
    public Flux<Scene> upsertScenes(List<Scene> scenes) {
        return Flux.fromIterable(scenes)
                .flatMap(this::upsertScene);
    }
    
    @Override
    public Mono<Void> deleteScene(String id) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .flatMap(scene -> sceneRepository.delete(scene));
    }
    
    @Override
    public Mono<Void> deleteScenesByNovelId(String novelId) {
        return sceneRepository.deleteByNovelId(novelId);
    }
    
    @Override
    public Mono<Void> deleteScenesByChapterId(String chapterId) {
        return sceneRepository.deleteByChapterId(chapterId);
    }
} 