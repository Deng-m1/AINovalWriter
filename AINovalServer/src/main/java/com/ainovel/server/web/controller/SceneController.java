package com.ainovel.server.web.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.web.base.ReactiveBaseController;

import lombok.RequiredArgsConstructor;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 场景控制器
 */
@RestController
@RequestMapping("/api/v1/scenes")
@RequiredArgsConstructor
public class SceneController extends ReactiveBaseController {
    
    private final SceneService sceneService;
    
    /**
     * 获取场景详情
     * @param id 场景ID
     * @return 场景信息
     */
    @GetMapping("/{id}")
    public Mono<Scene> getScene(@PathVariable String id) {
        return sceneService.findSceneById(id);
    }
    
    /**
     * 根据章节ID获取场景
     * @param chapterId 章节ID
     * @return 场景列表
     */
    @GetMapping("/chapter/{chapterId}")
    public Flux<Scene> getSceneByChapter(@PathVariable String chapterId) {
        return sceneService.findSceneByChapterId(chapterId);
    }
    
    /**
     * 根据章节ID获取场景并按顺序排序
     * @param chapterId 章节ID
     * @return 排序后的场景列表
     */
    @GetMapping("/chapter/{chapterId}/ordered")
    public Flux<Scene> getSceneByChapterOrdered(@PathVariable String chapterId) {
        return sceneService.findSceneByChapterIdOrdered(chapterId);
    }
    
    /**
     * 根据小说ID获取所有场景
     * @param novelId 小说ID
     * @return 场景列表
     */
    @GetMapping("/novel/{novelId}")
    public Flux<Scene> getScenesByNovel(@PathVariable String novelId) {
        return sceneService.findScenesByNovelId(novelId);
    }
    
    /**
     * 根据小说ID获取所有场景并按章节和顺序排序
     * @param novelId 小说ID
     * @return 排序后的场景列表
     */
    @GetMapping("/novel/{novelId}/ordered")
    public Flux<Scene> getScenesByNovelOrdered(@PathVariable String novelId) {
        return sceneService.findScenesByNovelIdOrdered(novelId);
    }
    
    /**
     * 根据小说ID和场景类型获取场景
     * @param novelId 小说ID
     * @param type 场景类型
     * @return 场景列表
     */
    @GetMapping("/novel/{novelId}/type")
    public Flux<Scene> getScenesByNovelAndType(
            @PathVariable String novelId,
            @RequestParam String type) {
        return sceneService.findScenesByNovelIdAndType(novelId, type);
    }
    
    /**
     * 创建场景
     * @param scene 场景信息
     * @return 创建的场景
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Scene> createScene(@RequestBody Scene scene) {
        return sceneService.createScene(scene);
    }
    
    /**
     * 批量创建场景
     * @param scenes 场景列表
     * @return 创建的场景列表
     */
    @PostMapping("/batch")
    @ResponseStatus(HttpStatus.CREATED)
    public Flux<Scene> createScenes(@RequestBody List<Scene> scenes) {
        return sceneService.createScenes(scenes);
    }
    
    /**
     * 更新场景
     * @param id 场景ID
     * @param scene 更新的场景信息
     * @return 更新后的场景
     */
    @PutMapping("/{id}")
    public Mono<Scene> updateScene(@PathVariable String id, @RequestBody Scene scene) {
        return sceneService.updateScene(id, scene);
    }
    
    /**
     * 创建或更新场景
     * 如果场景不存在则创建，存在则更新
     * @param scene 场景信息
     * @return 创建或更新后的场景
     */
    @PostMapping("/upsert")
    public Mono<Scene> upsertScene(@RequestBody Scene scene) {
        return sceneService.upsertScene(scene);
    }
    
    /**
     * 批量创建或更新场景
     * @param scenes 场景列表
     * @return 创建或更新后的场景列表
     */
    @PostMapping("/upsert/batch")
    public Flux<Scene> upsertScenes(@RequestBody List<Scene> scenes) {
        return sceneService.upsertScenes(scenes);
    }
    
    /**
     * 删除场景
     * @param id 场景ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteScene(@PathVariable String id) {
        return sceneService.deleteScene(id);
    }
    
    /**
     * 删除小说的所有场景
     * @param novelId 小说ID
     * @return 操作结果
     */
    @DeleteMapping("/novel/{novelId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteScenesByNovel(@PathVariable String novelId) {
        return sceneService.deleteScenesByNovelId(novelId);
    }
    
    /**
     * 删除章节的所有场景
     * @param chapterId 章节ID
     * @return 操作结果
     */
    @DeleteMapping("/chapter/{chapterId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteScenesByChapter(@PathVariable String chapterId) {
        return sceneService.deleteScenesByChapterId(chapterId);
    }
} 