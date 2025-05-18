package com.ainovel.server.service.ai.strategy;

import java.util.List;

import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.service.ai.AIModelProvider;

import reactor.core.publisher.Mono;

/**
 * 设定生成策略接口
 * 定义不同AI模型生成小说设定的共通接口
 */
public interface SettingGenerationStrategy {
    
    /**
     * 生成小说设定项
     * 
     * @param novelId 小说ID
     * @param userId 用户ID
     * @param chapterContext 章节内容
     * @param validRequestedTypes 有效的请求类型列表
     * @param maxSettingsPerType 每种类型最大生成数量
     * @param additionalInstructions 用户的附加指示
     * @param aiModelProvider AI模型提供商
     * @return 生成的小说设定项列表
     */
    Mono<List<NovelSettingItem>> generateSettings(
        String novelId, 
        String userId, 
        String chapterContext, 
        List<String> validRequestedTypes, 
        int maxSettingsPerType,
        String additionalInstructions,
        AIModelProvider aiModelProvider
    );
} 