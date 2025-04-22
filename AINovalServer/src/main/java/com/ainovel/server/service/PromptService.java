package com.ainovel.server.service;

import reactor.core.publisher.Mono;

/**
 * 提示词服务接口
 */
public interface PromptService {
    
    /**
     * 获取建议提示词
     * @param suggestionType 建议类型（情节、角色、对话等）
     * @return 提示词模板
     */
    Mono<String> getSuggestionPrompt(String suggestionType);
    
    /**
     * 获取修改提示词
     * @return 提示词模板
     */
    Mono<String> getRevisionPrompt();
    
    /**
     * 获取角色生成提示词
     * @return 提示词模板
     */
    Mono<String> getCharacterGenerationPrompt();
    
    /**
     * 获取情节生成提示词
     * @return 提示词模板
     */
    Mono<String> getPlotGenerationPrompt();
    
    /**
     * 获取设定生成提示词
     * @return 提示词模板
     */
    Mono<String> getSettingGenerationPrompt();
    
    /**
     * 获取下一剧情大纲生成提示词
     * @return 提示词模板
     */
    Mono<String> getNextOutlinesGenerationPrompt();
    
    /**
     * 获取单个剧情大纲生成的提示模板
     * 用于生成单个大纲选项，并要求按特定格式输出
     *
     * @return 单个大纲生成的提示模板
     */
    Mono<String> getSingleOutlineGenerationPrompt();
    
    /**
     * 保存提示词模板
     * @param promptType 提示词类型
     * @param template 模板内容
     * @return 操作结果
     */
    Mono<Void> savePromptTemplate(String promptType, String template);
    
    /**
     * 获取提示词模板
     * @param promptType 提示词类型
     * @return 模板内容
     */
    Mono<String> getPromptTemplate(String promptType);
    
    /**
     * 获取所有提示词类型
     * @return 提示词类型列表
     */
    Mono<java.util.List<String>> getAllPromptTypes();
} 