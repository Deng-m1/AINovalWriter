package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Scene.HistoryEntry;
import com.ainovel.server.domain.model.SceneVersionDiff;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.IndexingService;
import com.ainovel.server.service.MetadataService;
import com.ainovel.server.service.SceneService;
import com.github.difflib.DiffUtils;
import com.github.difflib.UnifiedDiffUtils;
import com.github.difflib.patch.Patch;

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
    private final MetadataService metadataService;

    @Lazy
    @Autowired
    private IndexingService indexingService;

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
        scene.setCreatedAt(LocalDateTime.now());
        scene.setUpdatedAt(LocalDateTime.now());

        // 设置初始版本
        scene.setVersion(1);

        // 使用元数据服务更新场景元数据（包括字数统计）
        final Scene updatedScene = metadataService.updateSceneMetadata(scene);

        // 如果没有设置序号，查找当前章节的最后一个场景序号并加1
        if (updatedScene.getSequence() == null) {
            return sceneRepository.findByChapterIdOrderBySequenceAsc(updatedScene.getChapterId())
                    .collectList()
                    .flatMap(scenes -> {
                        // 如果章节中没有场景，则序号为0
                        if (scenes.isEmpty()) {
                            updatedScene.setSequence(0);
                        } else {
                            // 获取最大序号并加1
                            int maxSequence = scenes.stream()
                                    .mapToInt(Scene::getSequence)
                                    .max()
                                    .orElse(-1);
                            updatedScene.setSequence(maxSequence + 1);
                        }
                        return sceneRepository.save(updatedScene)
                                .doOnSuccess(savedScene -> {
                                    // 异步触发小说元数据更新
                                    metadataService.triggerNovelMetadataUpdate(savedScene).subscribe();
                                });
                    });
        }

        return sceneRepository.save(updatedScene)
                .doOnSuccess(savedScene -> {
                    // 异步触发小说元数据更新
                    metadataService.triggerNovelMetadataUpdate(savedScene).subscribe();
                });
    }

    @Override
    public Flux<Scene> createScenes(List<Scene> scenes) {
        if (scenes.isEmpty()) {
            return Flux.empty();
        }

        // 设置创建和更新时间以及初始版本
        LocalDateTime now = LocalDateTime.now();
        scenes.forEach(scene -> {
            scene.setCreatedAt(now);
            scene.setUpdatedAt(now);
            scene.setVersion(1);
            // 使用元数据服务更新每个场景的元数据
            metadataService.updateSceneMetadata(scene);
        });

        // 按章节ID分组
        Map<String, List<Scene>> scenesByChapter = scenes.stream()
                .collect(Collectors.groupingBy(Scene::getChapterId));

        // 处理每个章节的场景
        List<Flux<Scene>> fluxes = new ArrayList<>();

        for (Map.Entry<String, List<Scene>> entry : scenesByChapter.entrySet()) {
            String chapterId = entry.getKey();
            List<Scene> chapterScenes = entry.getValue();

            // 获取章节中现有场景的最大序列号，然后设置新场景的序列号
            Flux<Scene> flux = sceneRepository.findByChapterIdOrderBySequenceAsc(chapterId)
                    .collectList()
                    .flatMapMany(existingScenes -> {
                        int nextSequence = 0;

                        if (!existingScenes.isEmpty()) {
                            // 获取当前章节中最大的序列号
                            nextSequence = existingScenes.stream()
                                    .mapToInt(Scene::getSequence)
                                    .max()
                                    .orElse(-1) + 1;
                        }

                        // 为每个新场景设置序列号（除非已设置）
                        for (Scene scene : chapterScenes) {
                            if (scene.getSequence() == null) {
                                scene.setSequence(nextSequence++);
                            }
                        }

                        return sceneRepository.saveAll(chapterScenes)
                                .doOnNext(savedScene -> {
                                    // 对每个保存的场景异步触发小说元数据更新
                                    metadataService.triggerNovelMetadataUpdate(savedScene).subscribe();
                                });
                    });

            fluxes.add(flux);
        }

        return Flux.concat(fluxes);
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
                    scene.setUpdatedAt(LocalDateTime.now());

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

                    // 使用元数据服务更新场景元数据（包括字数统计）
                    final Scene updatedScene = metadataService.updateSceneMetadata(scene);
                    final Scene finalExistingScene = existingScene;

                    // 在更新场景时，检查内容是否发生变化
                    if (!Objects.equals(finalExistingScene.getContent(), updatedScene.getContent())) {
                        // 如果内容发生变化，添加历史记录
                        HistoryEntry historyEntry = new HistoryEntry();
                        historyEntry.setUpdatedAt(LocalDateTime.now());
                        historyEntry.setContent(finalExistingScene.getContent());
                        historyEntry.setUpdatedBy("system");
                        historyEntry.setReason("内容更新");

                        // 复制现有历史记录并添加新记录
                        if (updatedScene.getHistory() == null) {
                            updatedScene.setHistory(new ArrayList<>());
                        }
                        updatedScene.getHistory().addAll(finalExistingScene.getHistory());
                        updatedScene.getHistory().add(historyEntry);
                    } else {
                        // 如果内容没变，保留原有历史记录
                        updatedScene.setHistory(finalExistingScene.getHistory());
                    }

                    // 保存更新后的场景
                    return sceneRepository.save(updatedScene)
                            .doOnSuccess(savedScene -> {
                                // 异步触发小说元数据更新
                                metadataService.triggerNovelMetadataUpdate(savedScene).subscribe();
                            });
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
                .flatMap(scene -> {
                    String novelId = scene.getNovelId();
                    return sceneRepository.delete(scene)
                            .then(Mono.defer(() -> {
                                // 触发小说元数据更新（如果有novelId）
                                if (novelId != null && !novelId.isEmpty()) {
                                    return metadataService.updateNovelMetadata(novelId).then();
                                }
                                return Mono.empty();
                            }));
                });
    }

    @Override
    public Mono<Void> deleteScenesByNovelId(String novelId) {
        return sceneRepository.deleteByNovelId(novelId);
    }

    @Override
    public Mono<Void> deleteScenesByChapterId(String chapterId) {
        // 首先获取章节的场景列表，记录novelId
        return sceneRepository.findByChapterId(chapterId)
                .collectList()
                .flatMap(scenes -> {
                    if (scenes.isEmpty()) {
                        return Mono.empty();
                    }

                    // 获取novelId用于后续更新元数据
                    String novelId = scenes.get(0).getNovelId();

                    return sceneRepository.deleteByChapterId(chapterId)
                            .then(Mono.defer(() -> {
                                // 触发小说元数据更新
                                if (novelId != null && !novelId.isEmpty()) {
                                    return metadataService.updateNovelMetadata(novelId).then();
                                }
                                return Mono.empty();
                            }));
                });
    }

    @Override
    public Mono<Scene> updateSceneContent(String id, String content, String userId, String reason) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .flatMap(scene -> {
                    // 如果内容没有变化，直接返回
                    if (scene.getContent() != null && scene.getContent().equals(content)) {
                        return Mono.just(scene);
                    }

                    // 保存当前内容到历史
                    HistoryEntry entry = new HistoryEntry();
                    entry.setUpdatedAt(LocalDateTime.now());
                    entry.setContent(scene.getContent());
                    entry.setUpdatedBy(userId);
                    entry.setReason(reason != null ? reason : "修改内容");

                    // 确保历史记录存在
                    if (scene.getHistory() == null) {
                        scene.setHistory(new ArrayList<>());
                    }

                    // 添加历史记录
                    scene.getHistory().add(entry);

                    // 更新内容和版本
                    scene.setContent(content);
                    scene.setVersion(scene.getVersion() + 1);
                    scene.setUpdatedAt(LocalDateTime.now());

                    // 使用元数据服务更新场景字数
                    final int wordCount = metadataService.calculateWordCount(content);
                    scene.setWordCount(wordCount);

                    final Scene updatedScene = scene;

                    // 保存到数据库
                    return sceneRepository.save(updatedScene)
                            .flatMap(savedScene -> {
                                // 触发场景索引
                                return indexingService.indexScene(savedScene)
                                        .thenReturn(savedScene);
                            })
                            .doOnSuccess(savedScene -> {
                                // 异步触发小说元数据更新
                                metadataService.triggerNovelMetadataUpdate(savedScene).subscribe();
                            });
                });
    }

    @Override
    public Mono<List<HistoryEntry>> getSceneHistory(String id) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .map(Scene::getHistory);
    }

    @Override
    public Mono<Scene> restoreSceneVersion(String id, int historyIndex, String userId, String reason) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .flatMap(scene -> {
                    List<HistoryEntry> history = scene.getHistory();

                    // 检查历史索引是否有效
                    if (historyIndex < 0 || historyIndex >= history.size()) {
                        return Mono.error(new IllegalArgumentException("无效的历史版本索引: " + historyIndex));
                    }

                    // 获取历史版本内容
                    final String historyContent = history.get(historyIndex).getContent();

                    // 添加当前版本到历史记录
                    HistoryEntry currentVersion = new HistoryEntry();
                    currentVersion.setContent(scene.getContent());
                    currentVersion.setUpdatedAt(LocalDateTime.now());
                    currentVersion.setUpdatedBy(userId);
                    currentVersion.setReason("恢复版本前的备份: " + reason);
                    history.add(currentVersion);

                    // 更新内容、版本和时间
                    scene.setContent(historyContent);
                    scene.setVersion(scene.getVersion() + 1);
                    scene.setUpdatedAt(LocalDateTime.now());

                    // 使用元数据服务更新场景字数
                    scene.setWordCount(metadataService.calculateWordCount(historyContent));

                    final Scene updatedScene = scene;

                    // 添加恢复记录
                    HistoryEntry restoreEntry = new HistoryEntry();
                    restoreEntry.setContent(null); // 不存储内容，因为就是当前版本
                    restoreEntry.setUpdatedAt(LocalDateTime.now());
                    restoreEntry.setUpdatedBy(userId);
                    restoreEntry.setReason("恢复到历史版本 #" + (historyIndex + 1) + ": " + reason);
                    history.add(restoreEntry);

                    return sceneRepository.save(updatedScene)
                            .doOnSuccess(savedScene -> {
                                // 异步触发小说元数据更新
                                metadataService.triggerNovelMetadataUpdate(savedScene).subscribe();
                            });
                });
    }

    @Override
    public Mono<Scene> updateSummary(String id, String summaryText) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .flatMap(scene -> {
                    // 更新摘要
                    if (summaryText != null) {
                        scene.setSummary(summaryText);
                    }

                    // 更新场景
                    scene.setUpdatedAt(LocalDateTime.now());
                    return sceneRepository.save(scene);
                });
    }

    @Override
    public Mono<Scene> addScene(String novelId, String chapterId, String title, String summaryText, Integer position) {
        // 创建新场景
        Scene newScene = new Scene();
        newScene.setId(UUID.randomUUID().toString());
        newScene.setNovelId(novelId);
        newScene.setChapterId(chapterId);
        newScene.setTitle(title);
        newScene.setContent(""); // 初始内容为空
        newScene.setCreatedAt(LocalDateTime.now());
        newScene.setUpdatedAt(LocalDateTime.now());
        newScene.setVersion(1);
        newScene.setSummary(summaryText);
        newScene.setWordCount(0); // 初始字数为0

        if (position != null) {
            newScene.setSequence(position);
            return createScene(newScene);
        } else {
            // 查找当前章节中最大的场景序号
            return sceneRepository.findByChapterIdOrderBySequenceAsc(chapterId)
                    .collectList()
                    .flatMap(scenes -> {
                        int sequence = 0;
                        if (!scenes.isEmpty()) {
                            sequence = scenes.stream()
                                    .mapToInt(Scene::getSequence)
                                    .max()
                                    .orElse(-1) + 1;
                        }
                        newScene.setSequence(sequence);
                        return createScene(newScene);
                    });
        }
    }

    @Override
    public Mono<SceneVersionDiff> compareSceneVersions(String id, int versionIndex1, int versionIndex2) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .map(scene -> {
                    List<HistoryEntry> history = scene.getHistory();

                    // 获取版本1的内容
                    String content1;
                    if (versionIndex1 == -1) {
                        // -1表示当前版本
                        content1 = scene.getContent();
                    } else {
                        if (versionIndex1 < 0 || versionIndex1 >= history.size()) {
                            throw new IllegalArgumentException("无效的历史版本索引1: " + versionIndex1);
                        }
                        content1 = history.get(versionIndex1).getContent();
                    }

                    // 获取版本2的内容
                    String content2;
                    if (versionIndex2 == -1) {
                        // -1表示当前版本
                        content2 = scene.getContent();
                    } else {
                        if (versionIndex2 < 0 || versionIndex2 >= history.size()) {
                            throw new IllegalArgumentException("无效的历史版本索引2: " + versionIndex2);
                        }
                        content2 = history.get(versionIndex2).getContent();
                    }

                    // 使用DiffUtils计算差异
                    List<String> originalLines = Arrays.asList(content1.split("\n"));
                    List<String> revisedLines = Arrays.asList(content2.split("\n"));

                    // 计算差异
                    Patch<String> patch = DiffUtils.diff(originalLines, revisedLines);

                    // 生成统一差异格式
                    List<String> unifiedDiff = UnifiedDiffUtils.generateUnifiedDiff(
                            "原始版本", "修改版本", originalLines, patch, 3);

                    // 创建并返回差异对象
                    SceneVersionDiff diff = new SceneVersionDiff();
                    diff.setOriginalContent(content1);
                    diff.setNewContent(content2);
                    diff.setDiff(String.join("\n", unifiedDiff));

                    return diff;
                });
    }

    @Override
    public Mono<Boolean> deleteSceneById(String id) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .flatMap(scene -> sceneRepository.delete(scene)
                .then(Mono.just(true)))
                .onErrorResume(e -> {
                    if (e instanceof ResourceNotFoundException) {
                        // 如果场景不存在，返回false
                        return Mono.just(false);
                    }
                    // 其他错误继续传播
                    return Mono.error(e);
                });
    }
}
