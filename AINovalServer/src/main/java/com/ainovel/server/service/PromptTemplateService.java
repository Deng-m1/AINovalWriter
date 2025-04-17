package com.ainovel.server.service;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.OptimizationResult;
import com.ainovel.server.domain.model.OptimizationStyle;
import com.ainovel.server.domain.model.PromptTemplate;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 提示词模板服务接口
 * 提供提示词模板管理和优化的服务
 */
public interface PromptTemplateService {
    
    /**
     * 获取提示词模板列表
     * 
     * @param userId 用户ID
     * @param type 模板类型（ALL, PUBLIC, PRIVATE, FAVORITE）
     * @return 提示词模板列表
     */
    Flux<PromptTemplate> getPromptTemplates(String userId, String type);
    
    /**
     * 根据功能类型获取提示词模板列表
     * 
     * @param userId 用户ID
     * @param featureType 功能类型
     * @param type 模板类型（ALL, PUBLIC, PRIVATE, FAVORITE）
     * @return 提示词模板列表
     */
    Flux<PromptTemplate> getPromptTemplatesByFeatureType(String userId, AIFeatureType featureType, String type);
    
    /**
     * 获取提示词模板详情
     * 
     * @param userId 用户ID
     * @param templateId 模板ID
     * @return 提示词模板详情
     */
    Mono<PromptTemplate> getPromptTemplateById(String userId, String templateId);
    
    /**
     * 创建提示词模板
     * 
     * @param userId 用户ID
     * @param name 模板名称
     * @param content 模板内容
     * @param featureType 功能类型
     * @return 创建的提示词模板
     */
    Mono<PromptTemplate> createPromptTemplate(String userId, String name, String content, AIFeatureType featureType);
    
    /**
     * 更新提示词模板
     * 
     * @param userId 用户ID
     * @param templateId 模板ID
     * @param name 模板名称（可选）
     * @param content 模板内容（可选）
     * @return 更新后的提示词模板
     */
    Mono<PromptTemplate> updatePromptTemplate(String userId, String templateId, String name, String content);
    
    /**
     * 删除提示词模板
     * 
     * @param userId 用户ID
     * @param templateId 模板ID
     * @return 操作结果
     */
    Mono<Void> deletePromptTemplate(String userId, String templateId);
    
    /**
     * 从公共模板复制创建私有模板
     * 
     * @param userId 用户ID
     * @param templateId 公共模板ID
     * @return 新创建的私有模板
     */
    Mono<PromptTemplate> copyPublicTemplate(String userId, String templateId);
    
    /**
     * 切换模板收藏状态
     * 
     * @param userId 用户ID
     * @param templateId 模板ID
     * @return 更新后的模板
     */
    Mono<PromptTemplate> toggleTemplateFavorite(String userId, String templateId);
    
    /**
     * 优化提示词模板
     * 
     * @param userId 用户ID
     * @param templateId 模板ID
     * @param content 提示词内容
     * @param style 优化风格
     * @param preserveRatio 保留原文比例
     * @return 优化结果
     */
    Mono<OptimizationResult> optimizePromptTemplate(String userId, String templateId, String content, 
            OptimizationStyle style, Double preserveRatio);
    
    /**
     * 优化提示词（不关联模板）
     * 
     * @param userId 用户ID
     * @param content 提示词内容
     * @param style 优化风格
     * @param preserveRatio 保留原文比例
     * @return 优化结果
     */
    Mono<OptimizationResult> optimizePrompt(String userId, String content, 
            OptimizationStyle style, Double preserveRatio);
            
    /**
     * 流式优化提示词模板
     * 
     * @param userId 用户ID
     * @param templateId 模板ID
     * @param content 提示词内容
     * @param style 优化风格
     * @param preserveRatio 保留原文比例
     * @return 流式优化结果
     */
    Flux<OptimizationResult> optimizePromptTemplateStream(String userId, String templateId, String content, 
            OptimizationStyle style, Double preserveRatio);
            
    /**
     * 流式优化提示词（不关联模板）
     * 
     * @param userId 用户ID
     * @param content 提示词内容
     * @param style 优化风格
     * @param preserveRatio 保留原文比例
     * @return 流式优化结果
     */
    Flux<OptimizationResult> optimizePromptStream(String userId, String content, 
            OptimizationStyle style, Double preserveRatio);
} 