package com.ainovel.server.service.impl;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.repository.NovelRepository;
import com.ainovel.server.service.NovelService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.time.LocalDateTime;

/**
 * 小说服务实现类
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NovelServiceImpl implements NovelService {
    
    private final NovelRepository novelRepository;
    
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
                    novel.setId(existingNovel.getId());
                    novel.setCreatedAt(existingNovel.getCreatedAt());
                    novel.setUpdatedAt(LocalDateTime.now());
                    return novelRepository.save(novel);
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
} 