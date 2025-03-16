package com.ainovel.server.web.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Scene.HistoryEntry;
import com.ainovel.server.domain.model.SceneVersionDiff;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.ChapterIdDto;
import com.ainovel.server.web.dto.IdDto;
import com.ainovel.server.web.dto.NovelIdDto;
import com.ainovel.server.web.dto.NovelIdTypeDto;
import com.ainovel.server.web.dto.SceneContentUpdateDto;
import com.ainovel.server.web.dto.SceneRestoreDto;
import com.ainovel.server.web.dto.SceneUpdateDto;
import com.ainovel.server.web.dto.SceneVersionCompareDto;

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
     * 
     * @param idDto 包含场景ID的DTO
     * @return 场景信息
     */
    @PostMapping("/get")
    public Mono<Scene> getScene(@RequestBody IdDto idDto) {
        return sceneService.findSceneById(idDto.getId());
    }

    /**
     * 根据章节ID获取场景
     * 
     * @param chapterIdDto 包含章节ID的DTO
     * @return 场景列表
     */
    @PostMapping("/get-by-chapter")
    public Flux<Scene> getSceneByChapter(@RequestBody ChapterIdDto chapterIdDto) {
        return sceneService.findSceneByChapterId(chapterIdDto.getChapterId());
    }

    /**
     * 根据章节ID获取场景并按顺序排序
     * 
     * @param chapterIdDto 包含章节ID的DTO
     * @return 排序后的场景列表
     */
    @PostMapping("/get-by-chapter-ordered")
    public Flux<Scene> getSceneByChapterOrdered(@RequestBody ChapterIdDto chapterIdDto) {
        return sceneService.findSceneByChapterIdOrdered(chapterIdDto.getChapterId());
    }

    /**
     * 根据小说ID获取所有场景
     * 
     * @param novelIdDto 包含小说ID的DTO
     * @return 场景列表
     */
    @PostMapping("/get-by-novel")
    public Flux<Scene> getScenesByNovel(@RequestBody NovelIdDto novelIdDto) {
        return sceneService.findScenesByNovelId(novelIdDto.getNovelId());
    }

    /**
     * 根据小说ID获取所有场景并按章节和顺序排序
     * 
     * @param novelIdDto 包含小说ID的DTO
     * @return 排序后的场景列表
     */
    @PostMapping("/get-by-novel-ordered")
    public Flux<Scene> getScenesByNovelOrdered(@RequestBody NovelIdDto novelIdDto) {
        return sceneService.findScenesByNovelIdOrdered(novelIdDto.getNovelId());
    }

    /**
     * 根据小说ID和场景类型获取场景
     * 
     * @param novelIdTypeDto 包含小说ID和场景类型的DTO
     * @return 场景列表
     */
    @PostMapping("/get-by-novel-type")
    public Flux<Scene> getScenesByNovelAndType(@RequestBody NovelIdTypeDto novelIdTypeDto) {
        return sceneService.findScenesByNovelIdAndType(novelIdTypeDto.getNovelId(), novelIdTypeDto.getType());
    }

    /**
     * 创建场景
     * 
     * @param scene 场景信息
     * @return 创建的场景
     */
    @PostMapping("/create")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Scene> createScene(@RequestBody Scene scene) {
        return sceneService.createScene(scene);
    }

    /**
     * 批量创建场景
     * 
     * @param scenes 场景列表
     * @return 创建的场景列表
     */
    @PostMapping("/create-batch")
    @ResponseStatus(HttpStatus.CREATED)
    public Flux<Scene> createScenes(@RequestBody List<Scene> scenes) {
        return sceneService.createScenes(scenes);
    }

    /**
     * 更新场景
     * 
     * @param sceneUpdateDto 包含场景ID和更新信息的DTO
     * @return 更新后的场景
     */
    @PostMapping("/update")
    public Mono<Scene> updateScene(@RequestBody SceneUpdateDto sceneUpdateDto) {
        return sceneService.updateScene(sceneUpdateDto.getId(), sceneUpdateDto.getScene());
    }

    /**
     * 创建或更新场景
     * 如果场景不存在则创建，存在则更新
     * 
     * @param scene 场景信息
     * @return 创建或更新后的场景
     */
    @PostMapping("/upsert")
    public Mono<Scene> upsertScene(@RequestBody Scene scene) {
        return sceneService.upsertScene(scene);
    }

    /**
     * 批量创建或更新场景
     * 
     * @param scenes 场景列表
     * @return 创建或更新后的场景列表
     */
    @PostMapping("/upsert-batch")
    public Flux<Scene> upsertScenes(@RequestBody List<Scene> scenes) {
        return sceneService.upsertScenes(scenes);
    }

    /**
     * 删除场景
     * 
     * @param idDto 包含场景ID的DTO
     * @return 操作结果
     */
    @PostMapping("/delete")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteScene(@RequestBody IdDto idDto) {
        return sceneService.deleteScene(idDto.getId());
    }

    /**
     * 删除小说的所有场景
     * 
     * @param novelIdDto 包含小说ID的DTO
     * @return 操作结果
     */
    @PostMapping("/delete-by-novel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteScenesByNovel(@RequestBody NovelIdDto novelIdDto) {
        return sceneService.deleteScenesByNovelId(novelIdDto.getNovelId());
    }

    /**
     * 删除章节的所有场景
     * 
     * @param chapterIdDto 包含章节ID的DTO
     * @return 操作结果
     */
    @PostMapping("/delete-by-chapter")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteScenesByChapter(@RequestBody ChapterIdDto chapterIdDto) {
        return sceneService.deleteScenesByChapterId(chapterIdDto.getChapterId());
    }

    /**
     * 更新场景内容并保存历史版本
     * 
     * @param updateDto 更新数据传输对象
     * @return 更新后的场景
     */
    @PostMapping("/update-content")
    public Mono<Scene> updateSceneContent(@RequestBody SceneContentUpdateDto updateDto) {
        return sceneService.updateSceneContent(updateDto.getId(), updateDto.getContent(), updateDto.getUserId(),
                updateDto.getReason());
    }

    /**
     * 获取场景的历史版本列表
     * 
     * @param idDto 包含场景ID的DTO
     * @return 历史版本列表
     */
    @PostMapping("/get-history")
    public Mono<List<HistoryEntry>> getSceneHistory(@RequestBody IdDto idDto) {
        return sceneService.getSceneHistory(idDto.getId());
    }

    /**
     * 恢复场景到指定的历史版本
     * 
     * @param restoreDto 恢复数据传输对象
     * @return 恢复后的场景
     */
    @PostMapping("/restore")
    public Mono<Scene> restoreSceneVersion(@RequestBody SceneRestoreDto restoreDto) {
        return sceneService.restoreSceneVersion(restoreDto.getId(), restoreDto.getHistoryIndex(),
                restoreDto.getUserId(), restoreDto.getReason());
    }

    /**
     * 对比两个场景版本
     * 
     * @param compareDto 对比数据传输对象
     * @return 差异信息
     */
    @PostMapping("/compare")
    public Mono<SceneVersionDiff> compareSceneVersions(@RequestBody SceneVersionCompareDto compareDto) {
        return sceneService.compareSceneVersions(compareDto.getId(), compareDto.getVersionIndex1(),
                compareDto.getVersionIndex2());
    }
}