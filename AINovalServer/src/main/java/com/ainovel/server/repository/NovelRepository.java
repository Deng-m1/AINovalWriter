package com.ainovel.server.repository;

import com.ainovel.server.domain.model.Novel;
import org.springframework.data.mongodb.repository.ReactiveMongoRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;

/**
 * 小说仓库接口
 */
@Repository
public interface NovelRepository extends ReactiveMongoRepository<Novel, String> {
    
    /**
     * 根据作者ID查找小说
     * @param authorId 作者ID
     * @return 小说列表
     */
    Flux<Novel> findByAuthorId(String authorId);
    
    /**
     * 根据标题模糊查询小说
     * @param title 标题关键词
     * @return 小说列表
     */
    Flux<Novel> findByTitleContaining(String title);
} 