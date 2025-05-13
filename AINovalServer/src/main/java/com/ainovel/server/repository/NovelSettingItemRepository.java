package com.ainovel.server.repository;

import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.ReactiveMongoRepository;

import com.ainovel.server.domain.model.NovelSettingItem;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说设定条目数据访问接口
 */
public interface NovelSettingItemRepository extends ReactiveMongoRepository<NovelSettingItem, String> {
    
    /**
     * 根据小说ID查找设定条目
     */
    Flux<NovelSettingItem> findByNovelId(String novelId);
    
    /**
     * 根据小说ID和类型查找设定条目
     */
    Flux<NovelSettingItem> findByNovelIdAndType(String novelId, String type);
    
    /**
     * 根据小说ID和名称查找设定条目
     */
    Flux<NovelSettingItem> findByNovelIdAndNameContaining(String novelId, String name);
    
    /**
     * 根据小说ID和场景ID查找设定条目
     */
    Flux<NovelSettingItem> findByNovelIdAndSceneId(String novelId, String sceneId);
    
    /**
     * 根据小说ID、类型和优先级查找设定条目，支持分页
     */
    Flux<NovelSettingItem> findByNovelIdAndTypeAndPriorityOrderByPriorityAsc(
            String novelId, String type, Integer priority, Pageable pageable);
    
    /**
     * 根据小说ID和优先级范围查找设定条目
     */
    Flux<NovelSettingItem> findByNovelIdAndPriorityBetween(
            String novelId, Integer minPriority, Integer maxPriority);
    
    /**
     * 根据小说ID、类型和生成源查找设定条目
     */
    Flux<NovelSettingItem> findByNovelIdAndTypeAndGeneratedBy(
            String novelId, String type, String generatedBy);
    
    /**
     * 根据小说ID、生成源和状态查找设定条目
     */
    Flux<NovelSettingItem> findByNovelIdAndGeneratedByAndStatus(
            String novelId, String generatedBy, String status);
    
    /**
     * 批量删除小说的所有设定条目
     */
    Mono<Void> deleteByNovelId(String novelId);
    
    /**
     * 批量删除特定场景的设定条目
     */
    Mono<Void> deleteByNovelIdAndSceneId(String novelId, String sceneId);
} 