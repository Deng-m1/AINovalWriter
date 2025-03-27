package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Scene.HistoryEntry;
import com.ainovel.server.domain.model.SceneVersionDiff;
import com.ainovel.server.repository.SceneRepository;
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
        
        // 如果没有设置序号，查找当前章节的最后一个场景序号并加1
        if (scene.getSequence() == null) {
            return sceneRepository.findByChapterIdOrderBySequenceAsc(scene.getChapterId())
                .collectList()
                .flatMap(scenes -> {
                    // 如果章节中没有场景，则序号为0
                    if (scenes.isEmpty()) {
                        scene.setSequence(0);
                    } else {
                        // 获取最大序号并加1
                        int maxSequence = scenes.stream()
                                .mapToInt(Scene::getSequence)
                                .max()
                                .orElse(-1);
                        scene.setSequence(maxSequence + 1);
                    }
                    return sceneRepository.save(scene);
                });
        }
        
        return sceneRepository.save(scene);
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
                        
                        return sceneRepository.saveAll(chapterScenes);
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
                    
                    // 在更新场景时，检查内容是否发生变化
                    if (!Objects.equals(existingScene.getContent(), scene.getContent())) {
                        // 如果内容发生变化，添加历史记录
                        HistoryEntry historyEntry = new HistoryEntry();
                        historyEntry.setContent(existingScene.getContent());
                        historyEntry.setUpdatedAt(LocalDateTime.now());
                        // 历史记录可能不包含更新人和原因，使用默认值
                        historyEntry.setUpdatedBy("system");
                        historyEntry.setReason("内容更新");
                        
                        // 复制现有历史记录并添加新记录
                        if (scene.getHistory() == null) {
                            scene.setHistory(new ArrayList<>());
                        }
                        scene.getHistory().addAll(existingScene.getHistory());
                        scene.getHistory().add(historyEntry);
                    } else {
                        // 如果内容没变，保留原有历史记录
                        scene.setHistory(existingScene.getHistory());
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
    
    @Override
    public Mono<Scene> updateSceneContent(String id, String content, String userId, String reason) {
        return sceneRepository.findById(id)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("场景不存在: " + id)))
                .flatMap(scene -> {
                    // 只有内容变化时才更新版本
                    if (!Objects.equals(scene.getContent(), content)) {
                        // 创建历史记录条目
                        HistoryEntry historyEntry = new HistoryEntry();
                        historyEntry.setContent(scene.getContent());
                        historyEntry.setUpdatedAt(LocalDateTime.now());
                        historyEntry.setUpdatedBy(userId);
                        historyEntry.setReason(reason);
                        
                        // 添加历史记录
                        scene.getHistory().add(historyEntry);
                        
                        // 更新内容和版本
                        scene.setContent(content);
                        scene.setVersion(scene.getVersion() + 1);
                        scene.setUpdatedAt(LocalDateTime.now());
                        
                        return sceneRepository.save(scene);
                    } else {
                        // 内容没变，不更新版本
                        return Mono.just(scene);
                    }
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
                    String historyContent = history.get(historyIndex).getContent();
                    
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
                    
                    // 添加恢复记录
                    HistoryEntry restoreEntry = new HistoryEntry();
                    restoreEntry.setContent(null); // 不存储内容，因为就是当前版本
                    restoreEntry.setUpdatedAt(LocalDateTime.now());
                    restoreEntry.setUpdatedBy(userId);
                    restoreEntry.setReason("恢复到历史版本 #" + (historyIndex + 1) + ": " + reason);
                    history.add(restoreEntry);
                    
                    return sceneRepository.save(scene);
                });
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
} 