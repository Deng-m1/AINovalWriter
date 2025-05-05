package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.Character;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Act;
import com.ainovel.server.domain.model.Novel.Chapter;
import com.ainovel.server.domain.model.Novel.Structure;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Setting;
import com.ainovel.server.repository.NovelRepository;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.StorageService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.web.dto.CreatedChapterInfo;
import com.ainovel.server.web.dto.NovelWithScenesDto;
import com.ainovel.server.web.dto.NovelWithSummariesDto;
import com.ainovel.server.web.dto.SceneSummaryDto;


import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

/**
 * 小说服务实现类
 */
@Slf4j

@Service
@RequiredArgsConstructor
public class NovelServiceImpl implements NovelService {

    private final NovelRepository novelRepository;
    private final SceneRepository sceneRepository;
    private final StorageService storageService;
    private final SceneService sceneService;
    private final ReactiveMongoTemplate reactiveMongoTemplate;

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
    public Mono<Novel> updateNovelMetadata(String id, String title, String author, String series) {
        return novelRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", id)))
                .flatMap(existingNovel -> {
                    // 更新元数据字段
                    if (title != null) {
                        existingNovel.setTitle(title);
                    }

                    // 作者信息需要特殊处理，因为是一个对象
                    if (author != null && existingNovel.getAuthor() != null) {
                        // 这里假设只更新作者的用户名，保留原有的作者ID
                        existingNovel.getAuthor().setUsername(author);
                    }

                    // 系列信息可能需要添加到元数据中，因为Novel类里没有series字段
                    if (series != null) {
                        // 将系列信息添加到标签中
                        List<String> tags = existingNovel.getTags();
                        if (tags == null) {
                            tags = new ArrayList<>();
                            existingNovel.setTags(tags);
                        }

                        // 移除旧的系列标签（如果存在）
                        tags.removeIf(tag -> tag.startsWith("series:"));

                        // 添加新的系列标签
                        tags.add("series:" + series);
                    }

                    // 更新时间戳
                    existingNovel.setUpdatedAt(LocalDateTime.now());

                    return novelRepository.save(existingNovel);
                })
                .doOnSuccess(updated -> log.info("更新小说元数据成功: {}", updated.getId()));
    }

    @Override
    public Mono<Map<String, String>> getCoverUploadCredential(String novelId) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> storageService.getCoverUploadCredential(novelId,
                "cover.jpg", "image/jpeg"));

    }

    @Override
    public Mono<Novel> updateNovelCover(String novelId, String coverUrl) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(existingNovel -> {
                    // 获取旧的封面URL
                    String oldCoverImage = existingNovel.getCoverImage();

                    // 更新封面URL
                    existingNovel.setCoverImage(coverUrl);
                    existingNovel.setUpdatedAt(LocalDateTime.now());

                    return novelRepository.save(existingNovel)
                            .flatMap(updatedNovel -> {
                                // 如果有旧封面且与新封面不同，尝试删除旧封面
                                if (oldCoverImage != null && !oldCoverImage.isEmpty()
                                        && !oldCoverImage.equals(coverUrl)) {
                                    // 尝试从URL中提取key
                                    String oldCoverKey = extractCoverKeyFromUrl(oldCoverImage);
                                    if (oldCoverKey != null) {
                                        return storageService.deleteCover(oldCoverKey)
                                                .onErrorResume(e -> {
                                                    log.warn("删除旧封面失败: {}, 错误: {}", oldCoverKey, e.getMessage());
                                                    return Mono.just(false);
                                                })
                                                .thenReturn(updatedNovel);
                                    }
                                }
                                return Mono.just(updatedNovel);
                            });
                })
                .doOnSuccess(updated -> log.info("更新小说封面成功: {}, 新封面URL: {}", updated.getId(), coverUrl));
    }

    /**
     * 从封面URL中提取存储键 这个方法需要根据实际的URL格式进行调整
     */
    private String extractCoverKeyFromUrl(String coverUrl) {
        try {
            if (coverUrl == null || coverUrl.isEmpty()) {
                return null;
            }

            // 示例: 从URL https://bucket.endpoint/covers/novelId/filename.jpg 提取 covers/novelId/filename.jpg
            int protocolEnd = coverUrl.indexOf("://");
            if (protocolEnd > 0) {
                String withoutProtocol = coverUrl.substring(protocolEnd + 3);
                int pathStart = withoutProtocol.indexOf('/');
                if (pathStart > 0) {
                    return withoutProtocol.substring(pathStart + 1);
                }
            }

            return null;
        } catch (Exception e) {
            log.warn("从URL提取封面键失败: {}, 错误: {}", coverUrl, e.getMessage());
            return null;
        }
    }

    @Override
    public Mono<Novel> archiveNovel(String novelId) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(existingNovel -> {
                    // 将小说标记为已归档
                    existingNovel.setIsArchived(true);
                    existingNovel.setUpdatedAt(LocalDateTime.now());

                    return novelRepository.save(existingNovel);
                })
                .doOnSuccess(updated -> log.info("小说归档成功: {}", updated.getId()));
    }

    @Override
    public Mono<Novel> unarchiveNovel(String novelId) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(existingNovel -> {
                    // 将小说标记为未归档
                    existingNovel.setIsArchived(false);
                    existingNovel.setUpdatedAt(LocalDateTime.now());

                    return novelRepository.save(existingNovel);
                })
                .doOnSuccess(updated -> log.info("小说恢复归档成功: {}", updated.getId()));
    }

    @Override
    public Mono<Void> permanentlyDeleteNovel(String novelId) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 先删除与该小说相关的所有场景
                    return sceneRepository.deleteByNovelId(novelId)
                            .then(novelRepository.delete(novel));
                })
                .doOnSuccess(v -> log.info("永久删除小说及其所有场景成功: {}", novelId));
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
                            centerChapterId = allChapterIds.getFirst();
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

                    int fromIndex = allChapterIds.indexOf(fromChapterId);
                    List<String> chapterIdsToLoad;

                    if ("up".equalsIgnoreCase(direction)) {
                        // 向上加载（加载fromChapterId之前的章节）
                        int startIndex = Math.max(0, fromIndex - chaptersLimit);
                        chapterIdsToLoad = allChapterIds.subList(startIndex, fromIndex); // Exclude fromIndex itself
                        log.info("向上加载章节，从索引{}到{}，共{}个章节", startIndex, fromIndex, chapterIdsToLoad.size());
                    } else if ("center".equalsIgnoreCase(direction)) {
                        // 中心加载 (加载 fromChapterId 及其前后)
                        int startIndex = Math.max(0, fromIndex - chaptersLimit);
                        int endIndex = Math.min(allChapterIds.size(), fromIndex + chaptersLimit + 1); // +1 because subList end index is exclusive
                        chapterIdsToLoad = allChapterIds.subList(startIndex, endIndex); // Include fromIndex itself
                        log.info("中心加载章节，从索引{}到{}，共{}个章节", startIndex, endIndex, chapterIdsToLoad.size());
                    } else {
                        // 向下加载（加载fromChapterId之后的章节）
                        int endIndex = Math.min(allChapterIds.size(), fromIndex + chaptersLimit + 1); // +1 because subList end index is exclusive
                        if (fromIndex + 1 < endIndex) { // Only load if there are chapters *after* fromIndex
                            chapterIdsToLoad = allChapterIds.subList(fromIndex + 1, endIndex); // Exclude fromIndex itself
                        } else {
                            chapterIdsToLoad = new ArrayList<>();
                        }
                        log.info("向下加载章节，从索引{}到{}，共{}个章节", fromIndex + 1, endIndex, chapterIdsToLoad.size());
                    }

                    // 如果没有章节可加载，返回空结果
                    if (chapterIdsToLoad.isEmpty()) {
                        log.info("根据方向 '{}' 计算后，没有更多章节可加载", direction);
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

    @Override
    public Mono<Novel> updateActTitle(String novelId, String actId, String title) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取小说结构
                    Structure structure = novel.getStructure();
                    if (structure == null || structure.getActs() == null) {
                        return Mono.error(new ResourceNotFoundException("小说结构不存在", novelId));
                    }

                    // 查找指定的卷
                    boolean actFound = false;
                    for (Act act : structure.getActs()) {
                        if (act.getId().equals(actId)) {
                            act.setTitle(title);
                            actFound = true;
                            break;
                        }
                    }

                    if (!actFound) {
                        return Mono.error(new ResourceNotFoundException("卷", actId));
                    }

                    // 更新小说
                    novel.setUpdatedAt(LocalDateTime.now());
                    return novelRepository.save(novel);
                })
                .doOnSuccess(updated -> log.info("更新卷标题成功: 小说 {}, 卷 {}, 新标题: {}", novelId, actId, title));
    }

    @Override
    public Mono<Novel> updateChapterTitle(String novelId, String chapterId, String title) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取小说结构
                    Structure structure = novel.getStructure();
                    if (structure == null || structure.getActs() == null) {
                        return Mono.error(new ResourceNotFoundException("小说结构不存在", novelId));
                    }

                    // 查找指定的章节
                    boolean chapterFound = false;
                    outerLoop:
                    for (Act act : structure.getActs()) {
                        if (act.getChapters() == null) {
                            continue;
                        }

                        for (Chapter chapter : act.getChapters()) {
                            if (chapter.getId().equals(chapterId)) {
                                chapter.setTitle(title);
                                chapterFound = true;
                                break outerLoop;
                            }
                        }
                    }

                    if (!chapterFound) {
                        return Mono.error(new ResourceNotFoundException("章节", chapterId));
                    }

                    // 更新小说
                    novel.setUpdatedAt(LocalDateTime.now());
                    return novelRepository.save(novel);
                })
                .doOnSuccess(updated -> log.info("更新章节标题成功: 小说 {}, 章节 {}, 新标题: {}", novelId, chapterId, title));
    }

    @Override
    public Mono<Novel> addAct(String novelId, String title, Integer position) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取小说结构，如果不存在则创建
                    Structure structure = novel.getStructure();
                    if (structure == null) {
                        structure = new Structure();
                        novel.setStructure(structure);
                    }

                    if (structure.getActs() == null) {
                        structure.setActs(new ArrayList<>());
                    }

                    // 创建新卷
                    Act newAct = new Act();
                    newAct.setId(UUID.randomUUID().toString());
                    newAct.setTitle(title);
                    newAct.setChapters(new ArrayList<>());

                    // 插入到指定位置或末尾
                    List<Act> acts = structure.getActs();
                    if (position != null && position >= 0 && position <= acts.size()) {
                        acts.add(position, newAct);
                    } else {
                        acts.add(newAct);
                    }

                    // 更新小说
                    novel.setUpdatedAt(LocalDateTime.now());
                    return novelRepository.save(novel);
                })
                .doOnSuccess(updated -> log.info("添加新卷成功: 小说 {}, 卷标题: {}", novelId, title));
    }

    @Override
    public Mono<Novel> addChapter(String novelId, String actId, String title, Integer position) {
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取小说结构
                    Structure structure = novel.getStructure();
                    if (structure == null || structure.getActs() == null) {
                        return Mono.error(new ResourceNotFoundException("小说结构不存在", novelId));
                    }

                    // 查找指定的卷
                    Act targetAct = null;
                    for (Act act : structure.getActs()) {
                        if (act.getId().equals(actId)) {
                            targetAct = act;
                            break;
                        }
                    }

                    if (targetAct == null) {
                        return Mono.error(new ResourceNotFoundException("卷", actId));
                    }

                    // 确保章节列表已初始化
                    if (targetAct.getChapters() == null) {
                        targetAct.setChapters(new ArrayList<>());
                    }

                    // 创建新章节
                    Chapter newChapter = new Chapter();
                    newChapter.setId(UUID.randomUUID().toString());
                    newChapter.setTitle(title);

                    // 插入到指定位置或末尾
                    List<Chapter> chapters = targetAct.getChapters();
                    if (position != null && position >= 0 && position <= chapters.size()) {
                        chapters.add(position, newChapter);
                    } else {
                        chapters.add(newChapter);
                    }

                    // 更新小说
                    novel.setUpdatedAt(LocalDateTime.now());
                    return novelRepository.save(novel);
                })
                .doOnSuccess(updated -> log.info("添加新章节成功: 小说 {}, 卷 {}, 章节标题: {}", novelId, actId, title));
    }

    @Override
    public Mono<Novel> moveScene(String novelId, String sceneId, String targetChapterId, int targetPosition) {
        return sceneRepository.findById(sceneId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景", sceneId)))
                .flatMap(scene -> {
                    // 检查场景是否属于这本小说
                    if (!scene.getNovelId().equals(novelId)) {
                        return Mono.error(new IllegalArgumentException("场景不属于指定的小说"));
                    }

                    String sourceChapterId = scene.getChapterId();

                    // 更新场景的章节ID和序列号
                    scene.setChapterId(targetChapterId);

                    // 获取目标章节的所有场景
                    return sceneRepository.findByChapterIdOrderBySequenceAsc(targetChapterId)
                            .collectList()
                            .flatMap(targetScenes -> {
                                // 如果是同一个章节内移动
                                if (sourceChapterId.equals(targetChapterId)) {
                                    // 删除当前场景
                                    targetScenes.removeIf(s -> s.getId().equals(sceneId));
                                }

                                // 检查目标位置是否有效
                                int insertPosition = Math.min(targetPosition, targetScenes.size());

                                // 插入场景到目标位置
                                targetScenes.add(insertPosition, scene);

                                // 更新所有场景的序列号
                                for (int i = 0; i < targetScenes.size(); i++) {
                                    targetScenes.get(i).setSequence(i);
                                }

                                // 保存所有更新的场景
                                return sceneRepository.saveAll(targetScenes).collectList()
                                        .flatMap(savedScenes -> {
                                            // 如果是不同章节间移动，需要更新源章节的场景序列号
                                            if (!sourceChapterId.equals(targetChapterId)) {
                                                return sceneRepository.findByChapterIdOrderBySequenceAsc(sourceChapterId)
                                                        .collectList()
                                                        .flatMap(sourceScenes -> {
                                                            // 删除当前场景（虽然已经移走，但可能仍在列表中）
                                                            sourceScenes.removeIf(s -> s.getId().equals(sceneId));

                                                            // 更新所有源章节场景的序列号
                                                            for (int i = 0; i < sourceScenes.size(); i++) {
                                                                sourceScenes.get(i).setSequence(i);
                                                            }

                                                            // 保存所有更新的源章节场景
                                                            return sceneRepository.saveAll(sourceScenes)
                                                                    .collectList()
                                                                    .then(novelRepository.findById(novelId));
                                                        });
                                            } else {
                                                return novelRepository.findById(novelId);
                                            }
                                        });
                            });
                })
                .doOnSuccess(novel -> log.info("移动场景成功: 场景 {}, 目标章节 {}, 目标位置 {}", sceneId, targetChapterId, targetPosition));
    }

    @Override
    public Mono<NovelWithSummariesDto> getNovelWithSceneSummaries(String novelId) {
        log.info("获取小说及其场景摘要，novelId={}", novelId);

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
                        return Mono.just(NovelWithSummariesDto.builder()
                                .novel(novel)
                                .sceneSummariesByChapter(new HashMap<>())
                                .build());
                    }

                    // 查询所有场景并按章节分组，但只保留摘要相关信息
                    return sceneRepository.findByNovelId(novelId)
                            .collectList()
                            .map(scenes -> {
                                // 将场景转换为摘要DTO
                                List<SceneSummaryDto> summaries = scenes.stream()
                                        .map(scene -> SceneSummaryDto.builder()
                                        .id(scene.getId())
                                        .novelId(scene.getNovelId())
                                        .chapterId(scene.getChapterId())
                                        .title(scene.getTitle())
                                        .summary(scene.getSummary())
                                        .sequence(scene.getSequence())
                                        .wordCount(calculateWordCount(scene.getContent()))
                                        .updatedAt(scene.getUpdatedAt())
                                        .build())
                                        .collect(Collectors.toList());

                                // 按章节ID分组
                                Map<String, List<SceneSummaryDto>> summariesByChapter = summaries.stream()
                                        .collect(Collectors.groupingBy(SceneSummaryDto::getChapterId));

                                // 构建并返回DTO
                                return NovelWithSummariesDto.builder()
                                        .novel(novel)
                                        .sceneSummariesByChapter(summariesByChapter)
                                        .build();
                            });
                })
                .doOnSuccess(dto -> log.info("获取小说及其场景摘要成功，小说ID: {}, 章节数: {}",
                novelId, dto.getSceneSummariesByChapter().size()))
                .doOnError(e -> log.error("获取小说及其场景摘要失败", e));
    }

    /**
     * 计算文本内容的字数
     *
     * @param content 文本内容
     * @return 字数
     */
    private Integer calculateWordCount(String content) {
        if (content == null || content.isEmpty()) {
            return 0;
        }

        // 简单实现，去除HTML标记和特殊字符后统计
        String plainText = content.replaceAll("<[^>]*>", "") // 移除HTML标签
                .replaceAll("\\s+", " ") // 将多个空白字符合并为一个
                .trim();

        // 统计中文字符数量（使用正则表达式匹配中文字符）
        int chineseCount = 0;
        for (char c : plainText.toCharArray()) {
            if (isChinese(c)) {
                chineseCount++;
            }
        }

        // 英文部分按空格分词
        String englishOnly = plainText.replaceAll("[^\\x00-\\x7F]+", " ").trim();
        int englishWordCount = englishOnly.isEmpty() ? 0 : englishOnly.split("\\s+").length;

        return chineseCount + englishWordCount;
    }

    /**
     * 判断字符是否是中文
     *
     * @param c 字符
     * @return 是否是中文
     */
    private boolean isChinese(char c) {
        return c >= 0x4E00 && c <= 0x9FA5; // Unicode CJK统一汉字范围
    }

    /**
     * 计算并更新小说的总字数
     *
     * @param novelId 小说ID
     * @return 更新后的小说
     */
    @Override
    public Mono<Novel> updateNovelWordCount(String novelId) {
        return findNovelById(novelId)
                .flatMap(novel -> {
                    // 使用 SceneRepository 获取所有关联的场景
                    return sceneRepository.findByNovelId(novelId)
                            .flatMap(scene -> {
                                                                // 更新小说元数据
                                                                if (novel.getMetadata() == null) {
                                                                    novel.setMetadata(Novel.Metadata.builder().build());
                                                                }
                                // 计算每个场景的字数
                                return Mono.fromCallable(() -> calculateWordCount(scene.getContent()))
                                        .subscribeOn(Schedulers.boundedElastic()); // 将计算放在弹性线程池
                            })
                            .reduce(0, Integer::sum) // 累加所有场景的字数
                            .flatMap(totalWordCount -> {
                                // 计算估计阅读时间 (假设每分钟阅读300字)
                                int readTime = totalWordCount / 300;
                                if (readTime < 1 && totalWordCount > 0) {
                                    readTime = 1; // 最小阅读时间为1分钟
                                }
                                novel.getMetadata().setWordCount(totalWordCount);
                                novel.getMetadata().setReadTime(readTime);
                                novel.setUpdatedAt(LocalDateTime.now());
                                return novelRepository.save(novel);
                            });
                })
                .doOnSuccess(updatedNovel -> log.info("小说 {} 字数更新为: {}", novelId, updatedNovel.getMetadata().getWordCount()))
                .onErrorResume(e -> {
                    log.error("更新小说 {} 字数失败: {}", novelId, e.getMessage(), e);
                    return Mono.error(e);
                });
    }

    @Override
    public Mono<String> getChapterRangeSummaries(String novelId, String startChapterId, String endChapterId) {
        return findNovelById(novelId)
            .<String>flatMap(novel -> { // 显式指定 flatMap 返回类型为 Mono<String>
                Structure structure = novel.getStructure();
                if (structure == null || structure.getActs() == null || structure.getActs().isEmpty()) {
                    log.warn("小说 {} 没有有效的结构或章节信息，无法获取摘要范围", novelId);
                    return Mono.just(""); // 或者返回特定错误信息
                }

                // 获取所有章节的扁平列表，方便查找索引
                List<Chapter> allChapters = structure.getActs().stream()
                    .flatMap(act -> act.getChapters().stream())
                    .collect(Collectors.toList());

                if (allChapters.isEmpty()) {
                     log.warn("小说 {} 结构中没有章节，无法获取摘要范围", novelId);
                    return Mono.just("");
                }

                int startIndex = 0;
                int endIndex = allChapters.size() - 1;

                // 确定起始索引
                if (startChapterId != null) {
                    boolean foundStart = false;
                    for (int i = 0; i < allChapters.size(); i++) {
                        if (allChapters.get(i).getId().equals(startChapterId)) {
                            startIndex = i;
                            foundStart = true;
                            break;
                        }
                    }
                    if (!foundStart) {
                         log.warn("未找到起始章节ID: {}, 将从第一章开始", startChapterId);
                    }
                }

                // 确定结束索引
                if (endChapterId != null) {
                     boolean foundEnd = false;
                    for (int i = 0; i < allChapters.size(); i++) {
                        if (allChapters.get(i).getId().equals(endChapterId)) {
                            endIndex = i;
                            foundEnd = true;
                            break;
                        }
                    }
                     if (!foundEnd) {
                         log.warn("未找到结束章节ID: {}, 将到最后一章结束", endChapterId);
                         endIndex = allChapters.size() - 1; // 确保 endIndex 有效
                    }
                }

                // 确保索引有效且 startIndex <= endIndex
                if (startIndex > endIndex) {
                    log.warn("起始章节索引 ({}) 大于结束章节索引 ({}), 无法获取摘要范围", startIndex, endIndex);
                    return Mono.just("");
                }

                // 获取指定范围内的章节ID列表
                List<String> targetChapterIds = allChapters.subList(startIndex, endIndex + 1).stream()
                    .map(Chapter::getId)
                    .collect(Collectors.toList());

                 log.debug("获取小说 {} 从索引 {} 到 {} 的章节摘要, 章节ID列表: {}", novelId, startIndex, endIndex, targetChapterIds);

                // 并行获取所有目标章节的场景，然后串行处理拼接（保证顺序）
                return Flux.fromIterable(targetChapterIds)
                    .<String>concatMap(chapterId -> sceneService.findSceneByChapterId(chapterId) // 使用注入的 SceneService
                        .filter(scene -> scene.getSummary() != null && !scene.getSummary().isBlank())
                        .map(Scene::getSummary)
                        .collect(Collectors.joining("\n\n")) // 拼接单个章节内的摘要
                    )
                    .filter(chapterSummary -> !chapterSummary.isEmpty())
                    .collect(Collectors.joining("\n\n---\n\n")) // 拼接不同章节的摘要，用分隔符区分
                    .defaultIfEmpty(""); // 如果没有找到任何摘要，返回空字符串
            })
            .onErrorResume(e -> {
                log.error("获取小说 {} 章节范围摘要时出错: {}", novelId, e.getMessage(), e);
                // 可以返回一个错误提示字符串，或者空字符串，或者重新抛出异常
                return Mono.just("获取章节摘要时发生错误。");
            });
    }

    @Override
    public Mono<CreatedChapterInfo> addChapterWithInitialScene(String novelId, String chapterTitle, String initialSceneSummary, String initialSceneTitle) {
        return novelRepository.findById(novelId)
            .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
            .flatMap(novel -> {
                Structure structure = novel.getStructure();
                Act targetAct;

                // 确保 Structure 和 Acts 列表存在
                if (structure == null) {
                    structure = new Structure();
                    novel.setStructure(structure);
                }
                if (structure.getActs() == null) {
                    structure.setActs(new ArrayList<>());
                }

                // 查找最后一卷，如果不存在则创建
                if (structure.getActs().isEmpty()) {
                    log.info("小说 {} 没有卷，创建第一卷", novelId);
                    Act newAct = Act.builder()
                        .id(UUID.randomUUID().toString())
                        .title("第一卷")
                        .chapters(new ArrayList<>())
                        .build();
                    structure.getActs().add(newAct);
                    targetAct = newAct;
                } else {
                    targetAct = structure.getActs().get(structure.getActs().size() - 1);
                }

                // 确保目标 Act 的 Chapters 列表存在
                if (targetAct.getChapters() == null) {
                    targetAct.setChapters(new ArrayList<>());
                }

                // 创建新场景
                Scene newScene = Scene.builder()
                    .id(UUID.randomUUID().toString())
                    .novelId(novelId)
                    // chapterId 将在下面设置
                    .title(initialSceneTitle != null ? initialSceneTitle : "场景 1") // 使用传入标题或默认值
                    .summary(initialSceneSummary)
                    .content("") // 初始内容为空
                    .sequence(0) // 第一个场景
                    .createdAt(LocalDateTime.now())
                    .updatedAt(LocalDateTime.now())
                    .build();

                // 创建新章节
                Chapter newChapter = Chapter.builder()
                    .id(UUID.randomUUID().toString())
                    .title(chapterTitle)
                    .sceneIds(Collections.singletonList(newScene.getId())) // 关联新场景
                    .build();

                // 设置场景的 chapterId
                newScene.setChapterId(newChapter.getId());

                // 添加新章节到目标 Act
                targetAct.getChapters().add(newChapter);

                // 更新小说更新时间
                novel.setUpdatedAt(LocalDateTime.now());

                // 首先保存场景 (因为 Novel 不直接内嵌 Scene)
                return sceneRepository.save(newScene)
                    .flatMap(savedScene -> {
                        // 然后保存更新后的小说结构
                        return novelRepository.save(novel)
                            .then(Mono.just(new CreatedChapterInfo(newChapter.getId(), savedScene.getId(), initialSceneSummary)));
                    });
            })
            .doOnSuccess(info -> log.info("添加新章节和初始场景成功: 小说 {}, 章节 {}, 场景 {}", novelId, info.getChapterId(), info.getSceneId()))
            .doOnError(e -> log.error("添加新章节和初始场景失败: 小说 {}, 错误: {}", novelId, e.getMessage()));
    }

    @Override
    public Mono<Scene> updateSceneContent(String novelId, String chapterId, String sceneId, String content) {
        return sceneRepository.findById(sceneId)
            .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景", sceneId)))
            .flatMap(scene -> {
                // 可选：验证 novelId 和 chapterId 是否匹配
                if (!scene.getNovelId().equals(novelId)) {
                     log.warn("场景 {} 的 novelId ({}) 与请求 novelId ({}) 不匹配", sceneId, scene.getNovelId(), novelId);
                    // return Mono.error(new IllegalArgumentException("Scene novelId mismatch")); // 可以选择报错或仅警告
                }
                 if (!scene.getChapterId().equals(chapterId)) {
                     log.warn("场景 {} 的 chapterId ({}) 与请求 chapterId ({}) 不匹配", sceneId, scene.getChapterId(), chapterId);
                    // return Mono.error(new IllegalArgumentException("Scene chapterId mismatch")); // 可以选择报错或仅警告
                }

                scene.setContent(content);
                scene.setUpdatedAt(LocalDateTime.now());
                // 可以考虑调用 calculateWordCount 并设置 scene.wordCount
                // scene.setWordCount(calculateWordCount(content));

                return sceneRepository.save(scene);
            })
            .doOnSuccess(savedScene -> log.info("更新场景内容成功: 场景 {}", savedScene.getId()))
            .doOnError(e -> log.error("更新场景内容失败: 场景 {}, 错误: {}", sceneId, e.getMessage()));
    }

    @Override
    public Mono<Novel> deleteChapter(String novelId, String actId, String chapterId) {
        log.info("开始删除章节: 小说={}, 卷={}, 章节={}", novelId, actId, chapterId);
        
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取小说结构
                    Structure structure = novel.getStructure();
                    if (structure == null || structure.getActs() == null) {
                        return Mono.error(new ResourceNotFoundException("小说结构不存在", novelId));
                    }

                    // 查找指定的卷和章节
                    boolean chapterFound = false;
                    Act targetAct = null;
                    
                    for (Act act : structure.getActs()) {
                        if (act.getId().equals(actId)) {
                            targetAct = act;
                            if (act.getChapters() != null) {
                                Iterator<Chapter> chapterIterator = act.getChapters().iterator();
                                while (chapterIterator.hasNext()) {
                                    Chapter chapter = chapterIterator.next();
                                    if (chapter.getId().equals(chapterId)) {
                                        chapterIterator.remove();
                                        chapterFound = true;
                                        break;
                                    }
                                }
                            }
                            break;
                        }
                    }

                    if (targetAct == null) {
                        return Mono.error(new ResourceNotFoundException("卷", actId));
                    }

                    if (!chapterFound) {
                        return Mono.error(new ResourceNotFoundException("章节", chapterId));
                    }

                    // 更新小说
                    novel.setUpdatedAt(LocalDateTime.now());
                    
                    // 更新最后编辑的章节ID（如果被删除的章节是最后编辑的章节）
                    if (chapterId.equals(novel.getLastEditedChapterId())) {
                        // 查找其他可用章节
                        String newLastEditedChapterId = null;
                        if (targetAct.getChapters() != null && !targetAct.getChapters().isEmpty()) {
                            // 优先使用同一卷中的章节
                            newLastEditedChapterId = targetAct.getChapters().get(0).getId();
                        } else {
                            // 查找其他卷中的章节
                            for (Act act : structure.getActs()) {
                                if (act.getChapters() != null && !act.getChapters().isEmpty()) {
                                    newLastEditedChapterId = act.getChapters().get(0).getId();
                                    break;
                                }
                            }
                        }
                        novel.setLastEditedChapterId(newLastEditedChapterId);
                    }
                    
                    // 先保存小说，删除章节结构
                    return novelRepository.save(novel)
                            .flatMap(savedNovel -> {
                                // 然后删除章节的所有场景数据
                                return sceneService.deleteScenesByChapterId(chapterId)
                                        .thenReturn(savedNovel);
                            });
                })
                .doOnSuccess(novel -> log.info("章节删除成功: 小说={}, 卷={}, 章节={}", novelId, actId, chapterId))
                .doOnError(e -> log.error("章节删除失败: 小说={}, 卷={}, 章节={}, 原因={}", 
                        novelId, actId, chapterId, e.getMessage()));
    }

}
