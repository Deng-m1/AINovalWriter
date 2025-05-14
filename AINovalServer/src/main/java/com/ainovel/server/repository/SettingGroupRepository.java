package com.ainovel.server.repository;

import com.ainovel.server.domain.model.SettingGroup;
import org.springframework.data.mongodb.repository.ReactiveMongoRepository;



import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 设定组数据访问接口
 */
public interface SettingGroupRepository extends ReactiveMongoRepository<SettingGroup, String> {
    
    /**
     * 根据小说ID查找设定组
     */
    Flux<SettingGroup> findByNovelId(String novelId);
    
    /**
     * 根据小说ID和名称查找设定组
     */
    Flux<SettingGroup> findByNovelIdAndNameContaining(String novelId, String name);
    
    /**
     * 根据小说ID和是否激活状态查找设定组
     */
    Flux<SettingGroup> findByNovelIdAndIsActiveContext(String novelId, Boolean isActiveContext);
    
    /**
     * 根据小说ID和用户ID查找设定组
     */
    Flux<SettingGroup> findByNovelIdAndUserId(String novelId, String userId);
    
    /**
     * 删除小说的所有设定组
     */
    Mono<Void> deleteByNovelId(String novelId);
    
    /**
     * 检查设定组是否包含特定设定条目
     */
    Mono<Boolean> existsByIdAndItemIdsContaining(String groupId, String settingItemId);
} 