package com.ainovel.server.web.controller;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Scene.HistoryEntry;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.AuthorIdDto;
import com.ainovel.server.web.dto.ChapterSceneDto;
import com.ainovel.server.web.dto.ChapterScenesDto;
import com.ainovel.server.web.dto.IdDto;
import com.ainovel.server.web.dto.NovelChapterDto;
import com.ainovel.server.web.dto.NovelChapterSceneDto;
import com.ainovel.server.web.dto.NovelWithScenesDto;
import com.ainovel.server.web.dto.SceneContentUpdateDto;
import com.ainovel.server.web.dto.SceneRestoreDto;
import com.ainovel.server.web.dto.SceneSearchDto;
import com.ainovel.server.web.dto.SceneVersionCompareDto;
import com.ainovel.server.web.dto.SceneVersionDiff;

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
     * 
     * @param novel 小说信息
     * @return 创建的小说
     */
    @PostMapping("/create")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Novel> createNovel(@RequestBody Novel novel) {
        return novelService.createNovel(novel);
    }

    /**
     * 获取小说详情
     * 
     * @param idDto 包含小说ID的DTO
     * @return 小说信息
     */
    @PostMapping("/get")
    public Mono<Novel> getNovel(@RequestBody IdDto idDto) {
        return novelService.findNovelById(idDto.getId());
    }

    /**
     * 获取小说详情及其所有场景内容
     * 
     * @param idDto 包含小说ID的DTO
     * @return 小说及其所有场景数据
     */
    @PostMapping("/get-with-scenes")
    public Mono<NovelWithScenesDto> getNovelWithScenes(@RequestBody IdDto idDto) {
        return novelService.getNovelWithAllScenes(idDto.getId());
    }

    /**
     * 更新小说及其所有场景内容
     * 
     * @param novelWithScenesDto 包含小说信息及其所有场景数据的DTO
     * @return 更新后的小说及场景数据
     */
    @PostMapping("/update-with-scenes")
    public Mono<NovelWithScenesDto> updateNovelWithScenes(@RequestBody NovelWithScenesDto novelWithScenesDto) {
        Novel novel = novelWithScenesDto.getNovel();
        // 从 Map 中获取所有场景列表，并将它们合并成一个大的 List
        List<Scene> scenes = novelWithScenesDto.getScenesByChapter().values().stream()
                .flatMap(List::stream) // 将多个 List<Scene> 合并成一个 Stream<Scene>
                .toList(); // 收集成一个新的 List<Scene>
        
        // 确保所有场景关联到正确的小说ID
        // 注意：ChapterId 应该在构建 DTO 时已经正确设置在每个 Scene 对象中
        scenes.forEach(scene -> scene.setNovelId(novel.getId()));
        
        // 首先更新小说
        return novelService.updateNovel(novel.getId(), novel)
                // 然后更新所有场景
                .flatMap(updatedNovel -> {
                    // 使用upsertScenes批量更新场景
                    return sceneService.upsertScenes(scenes)
                            .collectList()
                            .map(updatedScenes -> {
                                // 将更新后的场景列表重新按 ChapterId 分组
                                Map<String, List<Scene>> updatedScenesByChapter = updatedScenes.stream()
                                        .collect(Collectors.groupingBy(Scene::getChapterId));
                                
                                // 构建返回对象
                                NovelWithScenesDto result = new NovelWithScenesDto();
                                result.setNovel(updatedNovel);
                                // 设置分组后的 Map
                                result.setScenesByChapter(updatedScenesByChapter); 
                                return result;
                            });
                });
    }

    /**
     * 更新小说
     * 
     * @param novelUpdateDto 包含小说ID和更新信息的DTO
     * @return 更新后的小说
     */
    @PostMapping("/update")
    public Mono<Novel> updateNovel(@RequestBody Novel novel) {
        return novelService.updateNovel(novel.getId(), novel);
    }

    /**
     * 删除小说
     *
     * @param idDto 包含小说ID的DTO
     * @return 操作结果
     */
    @PostMapping("/delete")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteNovel(@RequestBody IdDto idDto) {
        return novelService.deleteNovel(idDto.getId());
    }

    /**
     * 获取作者的所有小说
     * 
     * @param authorIdDto 包含作者ID的DTO
     * @return 小说列表
     */
    @PostMapping("/get-by-author")
    public Flux<Novel> getNovelsByAuthor(@RequestBody AuthorIdDto authorIdDto) {
        return novelService.findNovelsByAuthorId(authorIdDto.getAuthorId());
    }

    /**
     * 搜索小说
     * 
     * @param searchDto 包含标题关键词的DTO
     * @return 小说列表
     */
    @PostMapping("/search")
    public Flux<Novel> searchNovels(@RequestBody SceneSearchDto searchDto) {
        return novelService.searchNovelsByTitle(searchDto.getTitle());
    }

    /**
     * 获取小说章节的场景内容（按顺序排序）
     * 
     * @param novelChapterDto 包含小说ID和章节ID的DTO
     * @return 排序后的场景列表
     */
    @PostMapping("/get-chapter-scenes-ordered")
    public Flux<Scene> getChapterScenesOrdered(@RequestBody NovelChapterDto novelChapterDto) {
        return sceneService.findSceneByChapterIdOrdered(novelChapterDto.getChapterId())
                .filter(scene -> scene.getNovelId().equals(novelChapterDto.getNovelId()));
    }

    /**
     * 获取小说章节的特定场景内容
     * 
     * @param novelChapterSceneDto 包含小说ID、章节ID和场景ID的DTO
     * @return 场景内容
     */
    @PostMapping("/get-chapter-scene")
    public Mono<Scene> getChapterScene(@RequestBody NovelChapterSceneDto novelChapterSceneDto) {
        return sceneService.findSceneById(novelChapterSceneDto.getSceneId())
                .filter(scene -> scene.getNovelId().equals(novelChapterSceneDto.getNovelId())
                        && scene.getChapterId().equals(novelChapterSceneDto.getChapterId()))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")));
    }

    /**
     * 创建小说章节的场景内容
     * 
     * @param chapterSceneDto 包含小说ID、章节ID和场景内容的DTO
     * @return 创建的场景
     */
    @PostMapping("/create-chapter-scene")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Scene> createChapterScene(@RequestBody ChapterSceneDto chapterSceneDto) {
        // 确保场景关联到正确的小说和章节
        Scene scene = chapterSceneDto.getScene();
        scene.setNovelId(chapterSceneDto.getNovelId());
        scene.setChapterId(chapterSceneDto.getChapterId());

        return sceneService.createScene(scene);
    }

    /**
     * 批量创建小说章节的场景内容
     * 
     * @param chapterScenesDto 包含小说ID、章节ID和场景列表的DTO
     * @return 创建的场景列表
     */
    @PostMapping("/create-chapter-scenes-batch")
    @ResponseStatus(HttpStatus.CREATED)
    public Flux<Scene> createChapterScenes(@RequestBody ChapterScenesDto chapterScenesDto) {
        // 确保所有场景关联到正确的小说和章节
        List<Scene> scenes = chapterScenesDto.getScenes();
        scenes.forEach(scene -> {
            scene.setNovelId(chapterScenesDto.getNovelId());
            scene.setChapterId(chapterScenesDto.getChapterId());
        });

        return sceneService.createScenes(scenes);
    }

    /**
     * 创建或更新小说章节的场景内容
     * 
     * @param chapterSceneDto 包含小说ID、章节ID和场景内容的DTO
     * @return 更新后的场景
     */
    @PostMapping("/upsert-chapter-scene")
    public Mono<Scene> createOrUpdateChapterScene(@RequestBody ChapterSceneDto chapterSceneDto) {
        // 确保场景关联到正确的小说和章节
        Scene scene = chapterSceneDto.getScene();
        scene.setNovelId(chapterSceneDto.getNovelId());
        scene.setChapterId(chapterSceneDto.getChapterId());

        return sceneService.upsertScene(scene);
    }

    /**
     * 批量创建或更新小说章节的场景内容
     * 
     * @param chapterScenesDto 包含小说ID、章节ID和场景列表的DTO
     * @return 更新后的场景列表
     */
    @PostMapping("/upsert-chapter-scenes-batch")
    public Flux<Scene> createOrUpdateChapterScenes(@RequestBody ChapterScenesDto chapterScenesDto) {
        // 确保所有场景关联到正确的小说和章节
        List<Scene> scenes = chapterScenesDto.getScenes();
        scenes.forEach(scene -> {
            scene.setNovelId(chapterScenesDto.getNovelId());
            scene.setChapterId(chapterScenesDto.getChapterId());
        });

        return sceneService.upsertScenes(scenes);
    }

    /**
     * 更新小说章节的特定场景内容
     * 
     * @param novelChapterSceneDto 包含小说ID、章节ID、场景ID和更新信息的DTO
     * @return 更新后的场景
     */
    @PostMapping("/update-chapter-scene")
    public Mono<Scene> updateChapterScene(@RequestBody NovelChapterSceneDto novelChapterSceneDto) {
        // 确保场景关联到正确的小说和章节，并设置正确的ID
        Scene scene = novelChapterSceneDto.getScene();
        scene.setId(novelChapterSceneDto.getSceneId());
        scene.setNovelId(novelChapterSceneDto.getNovelId());
        scene.setChapterId(novelChapterSceneDto.getChapterId());

        return sceneService.updateScene(novelChapterSceneDto.getSceneId(), scene);
    }

    /**
     * 删除小说章节的特定场景
     * 
     * @param novelChapterSceneDto 包含小说ID、章节ID和场景ID的DTO
     * @return 操作结果
     */
    @PostMapping("/delete-chapter-scene")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteChapterScene(@RequestBody NovelChapterSceneDto novelChapterSceneDto) {
        return sceneService.findSceneById(novelChapterSceneDto.getSceneId())
                .filter(scene -> scene.getNovelId().equals(novelChapterSceneDto.getNovelId())
                        && scene.getChapterId().equals(novelChapterSceneDto.getChapterId()))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")))
                .flatMap(scene -> sceneService.deleteScene(novelChapterSceneDto.getSceneId()));
    }

    /**
     * 删除小说章节的所有场景
     * 
     * @param novelChapterDto 包含小说ID和章节ID的DTO
     * @return 操作结果
     */
    @PostMapping("/delete-chapter-scenes")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteChapterScenes(@RequestBody NovelChapterDto novelChapterDto) {
        return sceneService.findSceneByChapterId(novelChapterDto.getChapterId())
                .filter(scene -> scene.getNovelId().equals(novelChapterDto.getNovelId()))
                .map(Scene::getId)
                .flatMap(sceneService::deleteScene)
                .then();
    }

    // ============================== 场景版本控制相关API ==============================

    /**
     * 更新场景内容并保存历史版本
     * 
     * @param sceneContentUpdateDto 包含小说ID、章节ID、场景ID和更新数据的DTO
     * @return 更新后的场景
     */
    @PostMapping("/update-chapter-scene-content")
    public Mono<Scene> updateChapterSceneContent(@RequestBody SceneContentUpdateDto sceneContentUpdateDto) {
        String sceneId = sceneContentUpdateDto.getId();
        String novelId = sceneContentUpdateDto.getNovelId();
        String chapterId = sceneContentUpdateDto.getChapterId();

        return sceneService.findSceneById(sceneId)
                .filter(scene -> scene.getNovelId().equals(novelId) && scene.getChapterId().equals(chapterId))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")))
                .flatMap(scene -> sceneService.updateSceneContent(sceneId, sceneContentUpdateDto.getContent(),
                        sceneContentUpdateDto.getUserId(), sceneContentUpdateDto.getReason()));
    }

    /**
     * 获取场景的历史版本列表
     * 
     * @param novelChapterSceneDto 包含小说ID、章节ID和场景ID的DTO
     * @return 历史版本列表
     */
    @PostMapping("/get-chapter-scene-history")
    public Mono<List<HistoryEntry>> getChapterSceneHistory(@RequestBody NovelChapterSceneDto novelChapterSceneDto) {
        return sceneService.findSceneById(novelChapterSceneDto.getSceneId())
                .filter(scene -> scene.getNovelId().equals(novelChapterSceneDto.getNovelId())
                        && scene.getChapterId().equals(novelChapterSceneDto.getChapterId()))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")))
                .flatMap(scene -> sceneService.getSceneHistory(novelChapterSceneDto.getSceneId()));
    }

    /**
     * 恢复场景到指定的历史版本
     * 
     * @param sceneRestoreDto 包含小说ID、章节ID、场景ID和恢复数据的DTO
     * @return 恢复后的场景
     */
    @PostMapping("/restore-chapter-scene")
    public Mono<Scene> restoreChapterSceneVersion(@RequestBody SceneRestoreDto sceneRestoreDto) {
        String sceneId = sceneRestoreDto.getId();
        String novelId = sceneRestoreDto.getNovelId();
        String chapterId = sceneRestoreDto.getChapterId();

        return sceneService.findSceneById(sceneId)
                .filter(scene -> scene.getNovelId().equals(novelId) && scene.getChapterId().equals(chapterId))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")))
                .flatMap(scene -> sceneService.restoreSceneVersion(sceneId, sceneRestoreDto.getHistoryIndex(),
                        sceneRestoreDto.getUserId(), sceneRestoreDto.getReason()));
    }

    /**
     * 对比两个场景版本
     * 
     * @param sceneVersionCompareDto 包含小说ID、章节ID、场景ID和对比数据的DTO
     * @return 差异信息
     */
    @PostMapping("/compare-chapter-scene-versions")
    public Mono<SceneVersionDiff> compareChapterSceneVersions(
            @RequestBody SceneVersionCompareDto sceneVersionCompareDto) {
        String sceneId = sceneVersionCompareDto.getId();
        String novelId = sceneVersionCompareDto.getNovelId();
        String chapterId = sceneVersionCompareDto.getChapterId();

        return sceneService.findSceneById(sceneId)
                .filter(scene -> scene.getNovelId().equals(novelId) && scene.getChapterId().equals(chapterId))
                .switchIfEmpty(Mono.error(new RuntimeException("场景不存在或不属于指定的小说和章节")))
                .flatMap(scene -> {
                    // 调用服务并转换返回类型
                    return sceneService.compareSceneVersions(sceneId, sceneVersionCompareDto.getVersionIndex1(),
                            sceneVersionCompareDto.getVersionIndex2())
                            .map(diff -> {
                                // 将domain模型转换为DTO
                                SceneVersionDiff dto = new SceneVersionDiff();
                                dto.setOriginalContent(diff.getOriginalContent());
                                dto.setNewContent(diff.getNewContent());
                                dto.setDiff(diff.getDiff());
                                return dto;
                            });
                });
    }
}
