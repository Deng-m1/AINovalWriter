package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.Character;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Setting;
import com.ainovel.server.repository.NovelRepository;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.web.dto.NovelWithScenesDto;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说服务实现类
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NovelServiceImpl implements NovelService {

    private final NovelRepository novelRepository;
    private final SceneRepository sceneRepository;

    @Override
    public Mono<Novel> createNovel(Novel novel) {
        novel.setCreatedAt(LocalDateTime.now());
        novel.setUpdatedAt(LocalDateTime.now());
        return novelRepository.save(novel)
                .doOnSuccess(saved -> log.info("创建小说成功: {}", saved.getId()));
    }

    @Override
    public Mono<Novel> findNovelById(String id) {
        return novelRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", id)));
    }

    @Override
    public Mono<Novel> updateNovel(String id, Novel novel) {
        return novelRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", id)))
                .flatMap(existingNovel -> {
                    // Update fields from the input novel
                    if (novel.getTitle() != null) {
                        existingNovel.setTitle(novel.getTitle());
                    }
                    if (novel.getDescription() != null) {
                        existingNovel.setDescription(novel.getDescription());
                    }
                    if (novel.getGenre() != null) {
                        existingNovel.setGenre(novel.getGenre());
                    }
                    if (novel.getCoverImage() != null) {
                        existingNovel.setCoverImage(novel.getCoverImage());
                    }
                    if (novel.getStatus() != null) {
                        existingNovel.setStatus(novel.getStatus());
                    }
                    if (novel.getTags() != null) {
                        existingNovel.setTags(novel.getTags());
                    }
                    if (novel.getStructure() != null) {
                        existingNovel.setStructure(novel.getStructure());
                    }
                    if (novel.getLastEditedChapterId() != null) {
                        existingNovel.setLastEditedChapterId(novel.getLastEditedChapterId());
                    }

                    // Always update the timestamp
                    existingNovel.setUpdatedAt(LocalDateTime.now());

                    return novelRepository.save(existingNovel);
                })
                .doOnSuccess(updated -> log.info("更新小说成功: {}", updated.getId()));
    }

    @Override
    public Mono<Novel> updateNovelWithScenes(String id, Novel novel, Map<String, List<Scene>> scenesByChapter) {
        // 首先更新小说信息
        return updateNovel(id, novel)
                .flatMap(updatedNovel -> {
                    // 如果场景列表为空，直接返回更新后的小说
                    if (scenesByChapter == null || scenesByChapter.isEmpty()) {
                        return Mono.just(updatedNovel);
                    }

                    // 创建一个列表来保存所有场景更新操作
                    List<Mono<Scene>> sceneUpdateOperations = new ArrayList<>();

                    // 对每个章节的场景进行更新
                    for (Map.Entry<String, List<Scene>> entry : scenesByChapter.entrySet()) {
                        String chapterId = entry.getKey();
                        List<Scene> scenes = entry.getValue();

                        // 过滤出属于当前小说和章节的场景
                        scenes.forEach(scene -> {
                            // 确保场景关联到正确的小说和章节
                            scene.setNovelId(id);
                            scene.setChapterId(chapterId);

                            // 添加更新操作到列表中
                            sceneUpdateOperations.add(sceneRepository.save(scene));
                        });
                    }

                    // 如果没有需要更新的场景，直接返回更新后的小说
                    if (sceneUpdateOperations.isEmpty()) {
                        return Mono.just(updatedNovel);
                    }

                    // 并行执行所有场景更新操作
                    return Flux.merge(sceneUpdateOperations)
                            .collectList()
                            .map(updatedScenes -> {
                                log.info("成功更新小说 {} 的 {} 个场景", id, updatedScenes.size());
                                return updatedNovel;
                            });
                })
                .doOnSuccess(updated -> log.info("更新小说及其场景成功: {}", updated.getId()));
    }

    @Override
    public Mono<Void> deleteNovel(String id) {
        return novelRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", id)))
                .flatMap(novel -> novelRepository.delete(novel))
                .doOnSuccess(v -> log.info("删除小说成功: {}", id));
    }

    @Override
    public Flux<Novel> findNovelsByAuthorId(String authorId) {
        return novelRepository.findByAuthorId(authorId);
    }

    @Override
    public Flux<Novel> searchNovelsByTitle(String title) {
        return novelRepository.findByTitleContaining(title);
    }

    @Override
    public Flux<Scene> getNovelScenes(String novelId) {
        return sceneRepository.findByNovelId(novelId);
    }

    @Override
    public Flux<Character> getNovelCharacters(String novelId) {
        // 暂时返回空结果，后续实现
        log.info("获取小说角色列表: {}", novelId);
        return Flux.empty();
    }

    @Override
    public Flux<Setting> getNovelSettings(String novelId) {
        // 暂时返回空结果，后续实现
        log.info("获取小说设定列表: {}", novelId);
        return Flux.empty();
    }

    @Override
    public Mono<Novel> updateLastEditedChapter(String novelId, String chapterId) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    novel.setLastEditedChapterId(chapterId);
                    novel.setUpdatedAt(LocalDateTime.now());
                    return novelRepository.save(novel);
                })
                .doOnSuccess(updated -> log.info("更新小说最后编辑章节成功: {}, 章节: {}", novelId, chapterId));
    }

    public Mono<List<Scene>> getChapterContextScenes(String novelId, String authorId) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 检查作者权限
                    if (!novel.getAuthor().getId().equals(authorId)) {
                        return Mono.error(new SecurityException("无权访问该小说"));
                    }

                    String lastEditedChapterId = novel.getLastEditedChapterId();
                    if (lastEditedChapterId == null || lastEditedChapterId.isEmpty()) {
                        // 如果没有上次编辑的章节，则获取第一个章节
                        if (novel.getStructure() != null
                                && !novel.getStructure().getActs().isEmpty()
                                && !novel.getStructure().getActs().get(0).getChapters().isEmpty()) {
                            lastEditedChapterId = novel.getStructure().getActs().get(0).getChapters().get(0).getId();
                        } else {
                            // 没有章节，返回空列表
                            return Mono.just(new ArrayList<>());
                        }
                    }

                    // 获取前后五章的章节ID列表
                    List<String> contextChapterIds = getContextChapterIds(novel, lastEditedChapterId, 5);

                    // 获取这些章节的所有场景ID
                    List<String> sceneIds = new ArrayList<>();
                    for (Novel.Act act : novel.getStructure().getActs()) {
                        for (Novel.Chapter chapter : act.getChapters()) {
                            if (contextChapterIds.contains(chapter.getId())) {
                                sceneIds.addAll(chapter.getSceneIds());
                            }
                        }
                    }

                    // 获取所有场景内容
                    return Flux.fromIterable(sceneIds)
                            .flatMap(sceneRepository::findById)
                            .collectList();
                });
    }

    /**
     * 获取指定章节前后n章的章节ID列表
     *
     * @param novel 小说
     * @param chapterId 当前章节ID
     * @param n 前后章节数
     * @return 章节ID列表
     */
    private List<String> getContextChapterIds(Novel novel, String chapterId, int n) {
        List<String> allChapterIds = new ArrayList<>();

        // 提取所有章节ID并记录它们的顺序
        for (Novel.Act act : novel.getStructure().getActs()) {
            for (Novel.Chapter chapter : act.getChapters()) {
                allChapterIds.add(chapter.getId());
            }
        }

        // 找到当前章节的索引
        int currentIndex = allChapterIds.indexOf(chapterId);
        if (currentIndex == -1) {
            // 如果找不到当前章节，返回前n章
            return allChapterIds.stream()
                    .limit(Math.min(n, allChapterIds.size()))
                    .collect(Collectors.toList());
        }

        // 计算前后n章的范围
        int startIndex = Math.max(0, currentIndex - n);
        int endIndex = Math.min(allChapterIds.size() - 1, currentIndex + n);

        // 提取前后n章的ID
        return allChapterIds.subList(startIndex, endIndex + 1);
    }

    @Override
    public Mono<NovelWithScenesDto> getNovelWithAllScenes(String novelId) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取所有章节ID
                    List<String> allChapterIds = new ArrayList<>();
                    for (Novel.Act act : novel.getStructure().getActs()) {
                        for (Novel.Chapter chapter : act.getChapters()) {
                            allChapterIds.add(chapter.getId());
                        }
                    }

                    // 如果没有章节，直接返回只有小说信息的DTO
                    if (allChapterIds.isEmpty()) {
                        return Mono.just(NovelWithScenesDto.builder()
                                .novel(novel)
                                .scenesByChapter(new HashMap<>())
                                .build());
                    }

                    // 查询所有场景并按章节分组
                    return sceneRepository.findByNovelId(novelId)
                            .collectList()
                            .map(scenes -> {
                                // 按章节ID分组
                                Map<String, List<Scene>> scenesByChapter = scenes.stream()
                                        .collect(Collectors.groupingBy(Scene::getChapterId));

                                // 构建并返回DTO
                                return NovelWithScenesDto.builder()
                                        .novel(novel)
                                        .scenesByChapter(scenesByChapter)
                                        .build();
                            });
                })
                .doOnSuccess(dto -> log.info("获取小说及其所有场景成功，小说ID: {}", novelId));
    }

    @Override
    public Mono<NovelWithScenesDto> getNovelWithPaginatedScenes(String novelId, String lastEditedChapterId, int chaptersLimit) {
        log.info("分页获取小说内容，novelId={}, lastEditedChapterId={}, chaptersLimit={}",
                novelId, lastEditedChapterId, chaptersLimit);

        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取所有章节ID，并保持它们的顺序
                    List<String> allChapterIds = new ArrayList<>();
                    Map<String, Novel.Act> actsByChapterId = new HashMap<>(); // 用于后续查找chapter所属的act

                    for (Novel.Act act : novel.getStructure().getActs()) {
                        for (Novel.Chapter chapter : act.getChapters()) {
                            allChapterIds.add(chapter.getId());
                            actsByChapterId.put(chapter.getId(), act);
                        }
                    }

                    // 如果没有章节，直接返回只有小说信息的DTO
                    if (allChapterIds.isEmpty()) {
                        return Mono.just(NovelWithScenesDto.builder()
                                .novel(novel)
                                .scenesByChapter(new HashMap<>())
                                .build());
                    }

                    // 确定中心章节
                    String centerChapterId = lastEditedChapterId;

                    // 如果未提供lastEditedChapterId或者它不在章节列表中
                    if (centerChapterId == null || centerChapterId.isEmpty() || !allChapterIds.contains(centerChapterId)) {
                        // 使用novel的lastEditedChapterId字段，尝试使用它
                        centerChapterId = novel.getLastEditedChapterId();
                        // 如果lastEditedChapterId也无效，使用第一个章节
                        if (centerChapterId == null || centerChapterId.isEmpty() || !allChapterIds.contains(centerChapterId)) {
                            centerChapterId = allChapterIds.get(0);
                        }
                    }

                    // 确定加载范围
                    int centerIndex = allChapterIds.indexOf(centerChapterId);
                    int startIndex = Math.max(0, centerIndex - chaptersLimit);
                    int endIndex = Math.min(allChapterIds.size() - 1, centerIndex + chaptersLimit);

                    // 获取要加载的章节ID列表
                    List<String> chapterIdsToLoad = allChapterIds.subList(startIndex, endIndex + 1);

                    log.info("分页加载章节，中心章节={}, 总章节数={}, 加载章节数={}, 范围从{}到{}",
                            centerChapterId, allChapterIds.size(), chapterIdsToLoad.size(), startIndex, endIndex);

                    // 获取这些章节的场景
                    return Flux.fromIterable(chapterIdsToLoad)
                            .flatMap(chapterId -> sceneRepository.findByChapterId(chapterId))
                            .collectList()
                            .map(scenes -> {
                                // 按章节ID分组，明确指定返回类型
                                final Map<String, List<Scene>> scenesByChapter = scenes.stream()
                                        .collect(Collectors.groupingBy(
                                                Scene::getChapterId,
                                                Collectors.toList() // 明确指定下游收集器
                                        ));

                                // 构建并返回DTO
                                return NovelWithScenesDto.builder()
                                        .novel(novel)
                                        .scenesByChapter(scenesByChapter)
                                        .build();
                            });
                })
                .doOnSuccess(dto -> log.info("分页获取小说及场景成功，小说ID: {}, 中心章节ID: {}, 加载章节数: {}",
                novelId, lastEditedChapterId, dto.getScenesByChapter().size()))
                .doOnError(e -> log.error("分页获取小说内容失败", e));
    }

    @Override
    public Mono<Map<String, List<Scene>>> loadMoreScenes(String novelId, String fromChapterId, String direction, int chaptersLimit) {
        log.info("加载更多场景，novelId={}, fromChapterId={}, direction={}, chaptersLimit={}",
                novelId, fromChapterId, direction, chaptersLimit);

        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取所有章节ID，并保持它们的顺序
                    List<String> allChapterIds = new ArrayList<>();

                    for (Novel.Act act : novel.getStructure().getActs()) {
                        for (Novel.Chapter chapter : act.getChapters()) {
                            allChapterIds.add(chapter.getId());
                        }
                    }

                    // 如果没有章节，或者fromChapterId不在章节列表中，返回空结果
                    if (allChapterIds.isEmpty() || !allChapterIds.contains(fromChapterId)) {
                        log.warn("加载更多场景失败：章节列表为空或fromChapterId不存在, novelId={}, fromChapterId={}",
                                novelId, fromChapterId);
                        Map<String, List<Scene>> emptyResult = new HashMap<>();
                        return Mono.just(emptyResult);
                    }

                    // 确定要加载的章节范围
                    int fromIndex = allChapterIds.indexOf(fromChapterId);
                    List<String> chapterIdsToLoad;

                    if ("up".equalsIgnoreCase(direction)) {
                        // 向上加载（加载fromChapterId之前的章节）
                        int startIndex = Math.max(0, fromIndex - chaptersLimit);
                        // 不包括fromChapterId本身，除非它是第一个
                        chapterIdsToLoad = allChapterIds.subList(startIndex, fromIndex);
                        log.info("向上加载章节，从索引{}到{}，共{}个章节", startIndex, fromIndex, chapterIdsToLoad.size());
                    } else {
                        // 向下加载（加载fromChapterId之后的章节）
                        int endIndex = Math.min(allChapterIds.size(), fromIndex + chaptersLimit + 1);
                        // 不包括fromChapterId本身，除非它是最后一个
                        if (fromIndex + 1 < endIndex) {
                            chapterIdsToLoad = allChapterIds.subList(fromIndex + 1, endIndex);
                        } else {
                            // 已经是最后一章，没有更多内容可加载
                            chapterIdsToLoad = new ArrayList<>();
                        }
                        log.info("向下加载章节，从索引{}到{}，共{}个章节", fromIndex + 1, endIndex, chapterIdsToLoad.size());
                    }

                    // 如果没有更多章节可加载，返回空结果
                    if (chapterIdsToLoad.isEmpty()) {
                        log.info("没有更多章节可加载，方向: {}", direction);
                        Map<String, List<Scene>> emptyResult = new HashMap<>();
                        return Mono.just(emptyResult);
                    }

                    // 获取这些章节的场景
                    return Flux.fromIterable(chapterIdsToLoad)
                            .flatMap(chapterId -> sceneRepository.findByChapterId(chapterId))
                            .collectList()
                            .map(scenes -> {
                                // 明确指定返回类型为Map而非HashMap
                                Map<String, List<Scene>> result = new HashMap<>();

                                // 按章节ID分组
                                Map<String, List<Scene>> groupedScenes = scenes.stream()
                                        .collect(Collectors.groupingBy(Scene::getChapterId));

                                // 将分组结果复制到结果Map中
                                result.putAll(groupedScenes);

                                return result;
                            });
                })
                .doOnSuccess(result -> log.info("加载更多场景成功，加载章节数: {}", result.size()))
                .doOnError(e -> log.error("加载更多场景失败", e));
    }
}
