package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
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
    
    @Override
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
                        if (novel.getStructure() != null && 
                            !novel.getStructure().getActs().isEmpty() && 
                            !novel.getStructure().getActs().get(0).getChapters().isEmpty()) {
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
} 