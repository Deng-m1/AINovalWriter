package com.ainovel.server.service;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.UserPromptTemplate;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户提示词服务接口
 * 用于管理用户自定义提示词
 */
public interface UserPromptService {
    
    /**
     * 获取指定用户和功能的提示词模板 (优先用户自定义，否则返回默认)
     * 
     * @param userId 用户ID
     * @param featureType 功能类型
     * @return 提示词模板
     */
    Mono<String> getPromptTemplate(String userId, AIFeatureType featureType);
    
    /**
     * 获取指定用户的所有自定义提示词
     * 
     * @param userId 用户ID
     * @return 用户自定义提示词列表
     */
    Flux<UserPromptTemplate> getUserCustomPrompts(String userId);
    
    /**
     * 保存或更新用户自定义提示词
     * 
     * @param userId 用户ID
     * @param featureType 功能类型
     * @param promptText 提示词文本
     * @return 保存或更新后的用户提示词模板
     */
    Mono<UserPromptTemplate> saveOrUpdateUserPrompt(String userId, AIFeatureType featureType, String promptText);
    
    /**
     * 删除用户自定义提示词 (恢复默认)
     * 
     * @param userId 用户ID
     * @param featureType 功能类型
     * @return 操作结果
     */
    Mono<Void> deleteUserPrompt(String userId, AIFeatureType featureType);
    
    /**
     * 获取指定功能的默认提示词
     * 
     * @param featureType 功能类型
     * @return 默认提示词
     */
    Mono<String> getDefaultPromptTemplate(AIFeatureType featureType);
} 