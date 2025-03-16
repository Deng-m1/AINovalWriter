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

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.web.base.ReactiveBaseController;

import lombok.RequiredArgsConstructor;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说控制器
 */
@RestController
@RequestMapping("/api/v1/novels")
@RequiredArgsConstructor
public class NovelController extends ReactiveBaseController {
    
    private final NovelService novelService;
    private final SceneService sceneService;
    
    /**
     * 创建小说
     * @param novel 小说信息
     * @return 创建的小说
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Novel> createNovel(@RequestBody Novel novel) {
        return novelService.createNovel(novel);
    }
    
    /**
     * 获取小说详情
     * @param id 小说ID
     * @return 小说信息
     */
    @GetMapping("/{id}")
    public Mono<Novel> getNovel(@PathVariable String id) {
        return novelService.findNovelById(id);
    }
    
    /**
     * 更新小说
     * @param id 小说ID
     * @param novel 更新的小说信息
     * @return 更新后的小说
     */
    @PutMapping("/{id}")
    public Mono<Novel> updateNovel(@PathVariable String id, @RequestBody Novel novel) {
        return novelService.updateNovel(id, novel);
    }
    
    /**
     * 删除小说
     * @param id 小说ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteNovel(@PathVariable String id) {
        return novelService.deleteNovel(id);
    }
    
    /**
     * 获取作者的所有小说
     * @param authorId 作者ID
     * @return 小说列表
     */
    @GetMapping("/author/{authorId}")
    public Flux<Novel> getNovelsByAuthor(@PathVariable String authorId) {
        return novelService.findNovelsByAuthorId(authorId);
    }
    
    /**
     * 搜索小说
     * @param title 标题关键词
     * @return 小说列表
     */
    @GetMapping("/search")
    public Flux<Novel> searchNovels(@RequestParam String title) {
        return novelService.searchNovelsByTitle(title);
    }
    
    /**
     * 获取小说章节的场景内容
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @return 场景列表
     */
    @GetMapping("/{novelId}/chapters/{chapterId}/scenes")
    public Flux<Scene> getChapterScenes(@PathVariable String novelId, @PathVariable String chapterId) {
        return sceneService.findSceneByChapterId(chapterId)
                .filter(scene -> scene.getNovelId().equals(novelId));
    }
    
    /**
     * 获取小说章节的场景内容（按顺序排序）
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @return 排序后的场景列表
     */
    @GetMapping("/{novelId}/chapters/{chapterId}/scenes/ordered")
    public Flux<Scene> getChapterScenesOrdered(@PathVariable String novelId, @PathVariable String chapterId) {
        return sceneService.findSceneByChapterIdOrdered(chapterId)
                .filter(scene -> scene.getNovelId().equals(novelId));
    }
    
    /**
     * 获取小说章节的特定场景内容
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param sceneId 场景ID
     * @return 场景内容
     */
    @GetMapping("/{novelId}/chapters/{chapterId}/scenes/{sceneId}")
    public Mono<Scene> getChapterScene(
            @PathVariable String novelId, 
            @PathVariable String chapterId, 
            @PathVariable String sceneId) {
        return sceneService.findSceneById(sceneId)
                .filter(scene -> scene.getNovelId().equals(novelId) && scene.getChapterId().equals(chapterId))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")));
    }
    
    /**
     * 创建小说章节的场景内容
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param scene 场景内容
     * @return 创建的场景
     */
    @PostMapping("/{novelId}/chapters/{chapterId}/scenes/create")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Scene> createChapterScene(
            @PathVariable String novelId, 
            @PathVariable String chapterId, 
            @RequestBody Scene scene) {
        // 确保场景关联到正确的小说和章节
        scene.setNovelId(novelId);
        scene.setChapterId(chapterId);
        
        return sceneService.createScene(scene);
    }
    
    /**
     * 批量创建小说章节的场景内容
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param scenes 场景列表
     * @return 创建的场景列表
     */
    @PostMapping("/{novelId}/chapters/{chapterId}/scenes/batch")
    @ResponseStatus(HttpStatus.CREATED)
    public Flux<Scene> createChapterScenes(
            @PathVariable String novelId, 
            @PathVariable String chapterId, 
            @RequestBody List<Scene> scenes) {
        // 确保所有场景关联到正确的小说和章节
        scenes.forEach(scene -> {
            scene.setNovelId(novelId);
            scene.setChapterId(chapterId);
        });
        
        return sceneService.createScenes(scenes);
    }
    
    /**
     * 创建或更新小说章节的场景内容
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param scene 场景内容
     * @return 更新后的场景
     */
    @PostMapping("/{novelId}/chapters/{chapterId}/scenes")
    public Mono<Scene> createOrUpdateChapterScene(
            @PathVariable String novelId, 
            @PathVariable String chapterId, 
            @RequestBody Scene scene) {
        // 确保场景关联到正确的小说和章节
        scene.setNovelId(novelId);
        scene.setChapterId(chapterId);
        
        return sceneService.upsertScene(scene);
    }
    
    /**
     * 批量创建或更新小说章节的场景内容
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param scenes 场景列表
     * @return 更新后的场景列表
     */
    @PostMapping("/{novelId}/chapters/{chapterId}/scenes/upsert/batch")
    public Flux<Scene> createOrUpdateChapterScenes(
            @PathVariable String novelId, 
            @PathVariable String chapterId, 
            @RequestBody List<Scene> scenes) {
        // 确保所有场景关联到正确的小说和章节
        scenes.forEach(scene -> {
            scene.setNovelId(novelId);
            scene.setChapterId(chapterId);
        });
        
        return sceneService.upsertScenes(scenes);
    }
    
    /**
     * 更新小说章节的特定场景内容
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param sceneId 场景ID
     * @param scene 场景内容
     * @return 更新后的场景
     */
    @PutMapping("/{novelId}/chapters/{chapterId}/scenes/{sceneId}")
    public Mono<Scene> updateChapterScene(
            @PathVariable String novelId, 
            @PathVariable String chapterId, 
            @PathVariable String sceneId,
            @RequestBody Scene scene) {
        // 确保场景关联到正确的小说和章节，并设置正确的ID
        scene.setId(sceneId);
        scene.setNovelId(novelId);
        scene.setChapterId(chapterId);
        
        return sceneService.updateScene(sceneId, scene);
    }
    
    /**
     * 删除小说章节的特定场景
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param sceneId 场景ID
     * @return 操作结果
     */
    @DeleteMapping("/{novelId}/chapters/{chapterId}/scenes/{sceneId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteChapterScene(
            @PathVariable String novelId, 
            @PathVariable String chapterId, 
            @PathVariable String sceneId) {
        return sceneService.findSceneById(sceneId)
                .filter(scene -> scene.getNovelId().equals(novelId) && scene.getChapterId().equals(chapterId))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")))
                .flatMap(scene -> sceneService.deleteScene(sceneId));
    }
    
    /**
     * 删除小说章节的所有场景
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @return 操作结果
     */
    @DeleteMapping("/{novelId}/chapters/{chapterId}/scenes")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteChapterScenes(
            @PathVariable String novelId, 
            @PathVariable String chapterId) {
        return sceneService.findSceneByChapterId(chapterId)
                .filter(scene -> scene.getNovelId().equals(novelId))
                .map(Scene::getId)
                .flatMap(sceneService::deleteScene)
                .then();
    }
} 