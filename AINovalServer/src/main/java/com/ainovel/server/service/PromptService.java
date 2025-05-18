package com.ainovel.server.service;

import java.util.List;
import java.util.Map;

import reactor.core.publisher.Mono;

/**
 * 提示词服务接口
 */
public interface PromptService {
    
    /**
     * 获取指定类型的建议提示词
     * @param suggestionType 建议类型
     * @return 提示词内容
     */
    Mono<String> getSuggestionPrompt(String suggestionType);
    
    /**
     * 获取修改提示词
     * @return 提示词内容
     */
    Mono<String> getRevisionPrompt();
    
    /**
     * 获取角色生成提示词
     * @return 提示词内容
     */
    Mono<String> getCharacterGenerationPrompt();
    
    /**
     * 获取情节生成提示词
     * @return 提示词内容
     */
    Mono<String> getPlotGenerationPrompt();
    
    /**
     * 获取设定生成提示词
     * @return 提示词内容
     */
    Mono<String> getSettingGenerationPrompt();
    
    /**
     * 获取下一个剧情大纲生成提示词
     * @return 提示词内容
     */
    Mono<String> getNextOutlinesGenerationPrompt();
    
    /**
     * 获取单个剧情大纲生成提示词
     * @return 提示词内容
     */
    Mono<String> getSingleOutlineGenerationPrompt();
    
    /**
     * 获取用于单轮剧情推演的提示词模板
     * @return 提示词模板
     */
    Mono<String> getNextChapterOutlineGenerationPrompt();
    
    /**
     * 获取结构化的设定生成提示词，用于支持JSON Schema的模型
     * 
     * @param settingTypes 设定类型列表（逗号分隔）
     * @param maxSettingsPerType 每种类型最大生成数量
     * @param additionalInstructions 用户的额外指示
     * @return 结构化的系统和用户提示词
     */
    Mono<Map<String, String>> getStructuredSettingPrompt(String settingTypes, int maxSettingsPerType, String additionalInstructions);
    
    /**
     * 获取常规的设定生成提示词，用于不支持JSON Schema的模型
     * 
     * @param contextText 小说上下文文本
     * @param settingTypes 设定类型列表（逗号分隔）
     * @param maxSettingsPerType 每种类型最大生成数量
     * @param additionalInstructions 用户的额外指示
     * @return 完整的提示词
     */
    Mono<String> getGeneralSettingPrompt(String contextText, String settingTypes, int maxSettingsPerType, String additionalInstructions);
    
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
     * @return 类型列表
     */
    Mono<List<String>> getAllPromptTypes();
} 