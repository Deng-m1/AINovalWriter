package com.ainovel.server.service;

import java.util.List;

import org.springframework.data.domain.Pageable;

import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.domain.model.NovelSettingItem.SettingRelationship;
import com.ainovel.server.domain.model.SettingGroup;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说设定服务接口
 */
public interface NovelSettingService {
    
    // ==================== 设定条目管理 ====================
    
    /**
     * 创建小说设定条目
     */
    Mono<NovelSettingItem> createSettingItem(NovelSettingItem settingItem);
    
    /**
     * 获取小说的设定条目列表
     */
    Flux<NovelSettingItem> getNovelSettingItems(String novelId, String type, String name, Integer priority, String generatedBy, String status, Pageable pageable);
    
    /**
     * 根据ID获取设定条目
     */
    Mono<NovelSettingItem> getSettingItemById(String itemId);
    
    /**
     * 更新设定条目
     */
    Mono<NovelSettingItem> updateSettingItem(String itemId, NovelSettingItem settingItem);
    
    /**
     * 删除设定条目
     */
    Mono<Void> deleteSettingItem(String itemId);
    
    /**
     * 获取场景相关的设定条目
     */
    Flux<NovelSettingItem> getSceneSettingItems(String novelId, String sceneId);
    
    /**
     * 从AI建议中接受设定条目
     */
    Mono<NovelSettingItem> acceptSuggestedSettingItem(String settingItemId);
    
    /**
     * 拒绝AI建议的设定条目
     */
    Mono<NovelSettingItem> rejectSuggestedSettingItem(String settingItemId);
    
    /**
     * 添加设定关系
     * 
     * @param itemId 源设定条目ID
     * @param relationship 关系对象
     * @return 更新后的设定条目
     */
    Mono<NovelSettingItem> addSettingRelationship(String itemId, SettingRelationship relationship);
    
    /**
     * 移除设定关系
     * 
     * @param itemId 源设定条目ID
     * @param targetItemId 目标设定条目ID
     * @param relationshipType 关系类型 (可选)
     * @return 操作结果
     */
    Mono<Void> removeSettingRelationship(String itemId, String targetItemId, String relationshipType);
    
    // ==================== 设定组管理 ====================
    
    /**
     * 创建设定组
     */
    Mono<SettingGroup> createSettingGroup(SettingGroup settingGroup);
    
    /**
     * 获取小说的设定组列表
     */
    Flux<SettingGroup> getNovelSettingGroups(String novelId, String name, Boolean isActiveContext);
    
    /**
     * 根据ID获取设定组
     */
    Mono<SettingGroup> getSettingGroupById(String groupId);
    
    /**
     * 更新设定组
     * 
     * @param groupId 设定组ID
     * @param settingGroup 设定组对象
     * @return 更新后的设定组
     */
    Mono<SettingGroup> updateSettingGroup(String groupId, SettingGroup settingGroup);
    
    /**
     * 删除设定组
     */
    Mono<Void> deleteSettingGroup(String groupId);
    
    /**
     * 添加设定条目到设定组
     * 
     * @param groupId 设定组ID
     * @param itemId 设定条目ID
     * @return 更新后的设定组
     */
    Mono<SettingGroup> addItemToGroup(String groupId, String itemId);
    
    /**
     * 从设定组中移除设定条目
     * 
     * @param groupId 设定组ID
     * @param itemId 设定条目ID
     * @return 操作结果
     */
    Mono<Void> removeItemFromGroup(String groupId, String itemId);
    
    /**
     * 设置设定组是否为活跃上下文
     * 
     * @param groupId 设定组ID
     * @param isActive 是否激活
     * @return 更新后的设定组
     */
    Mono<SettingGroup> setGroupActiveContext(String groupId, boolean isActive);
    
    // ==================== 高级功能 ====================
    
    /**
     * 从文本中提取设定条目
     * 
     * @param novelId 小说ID
     * @param text 文本内容
     * @param type 设定类型 (auto表示自动识别)
     * @param userId 用户ID
     * @return 提取的设定条目列表
     */
    Flux<NovelSettingItem> extractSettingsFromText(String novelId, String text, String type, String userId);
    
    /**
     * 搜索设定条目
     * 
     * @param novelId 小说ID
     * @param query 查询关键词
     * @param types 设定类型列表 (可选)
     * @param groupIds 设定组ID列表 (可选)
     * @param minScore 最小相似度分数 (可选)
     * @param maxResults 最大返回结果数 (可选)
     * @return 搜索结果
     */
    Flux<NovelSettingItem> searchSettingItems(String novelId, String query, List<String> types, List<String> groupIds, Double minScore, Integer maxResults);
    
    /**
     * 向量化并索引设定条目
     * 
     * @param itemId 设定条目ID
     * @return 操作结果
     */
    Mono<Void> vectorizeAndIndexSettingItem(String itemId);
} 