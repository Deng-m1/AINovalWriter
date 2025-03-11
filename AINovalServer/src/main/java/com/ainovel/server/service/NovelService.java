package com.ainovel.server.service;

import com.ainovel.server.domain.model.Novel;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说服务接口
 */
public interface NovelService {
    
    /**
     * 创建小说
     * @param novel 小说信息
     * @return 创建的小说
     */
    Mono<Novel> createNovel(Novel novel);
    
    /**
     * 根据ID查找小说
     * @param id 小说ID
     * @return 小说信息
     */
    Mono<Novel> findNovelById(String id);
    
    /**
     * 更新小说信息
     * @param id 小说ID
     * @param novel 更新的小说信息
     * @return 更新后的小说
     */
    Mono<Novel> updateNovel(String id, Novel novel);
    
    /**
     * 删除小说
     * @param id 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteNovel(String id);
    
    /**
     * 查找用户的所有小说
     * @param authorId 作者ID
     * @return 小说列表
     */
    Flux<Novel> findNovelsByAuthorId(String authorId);
    
    /**
     * 根据标题搜索小说
     * @param title 标题关键词
     * @return 小说列表
     */
    Flux<Novel> searchNovelsByTitle(String title);
} 