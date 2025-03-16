package com.ainovel.server.service;

import java.util.Map;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.service.ai.AIModelProvider;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说AI服务接口 专门处理与小说创作相关的AI功能
 */
public interface NovelAIService {

    /**
     * 生成小说内容
     *
     * @param request AI请求
     * @return AI响应
     */
    Mono<AIResponse> generateNovelContent(AIRequest request);

    /**
     * 生成小说内容（流式）
     *
     * @param request AI请求
     * @return 流式AI响应
     */
    Flux<String> generateNovelContentStream(AIRequest request);

    /**
     * 获取创作建议
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @param suggestionType 建议类型（情节、角色、对话等）
     * @return 创作建议
     */
    Mono<AIResponse> getWritingSuggestion(String novelId, String sceneId, String suggestionType);

    /**
     * 获取创作建议（流式）
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @param suggestionType 建议类型（情节、角色、对话等）
     * @return 流式创作建议
     */
    Flux<String> getWritingSuggestionStream(String novelId, String sceneId, String suggestionType);

    /**
     * 修改内容
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @param content 原内容
     * @param instruction 修改指令
     * @return 修改后的内容
     */
    Mono<AIResponse> reviseContent(String novelId, String sceneId, String content, String instruction);

    /**
     * 修改内容（流式）
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @param content 原内容
     * @param instruction 修改指令
     * @return 流式修改后的内容
     */
    Flux<String> reviseContentStream(String novelId, String sceneId, String content, String instruction);

    /**
     * 生成角色
     *
     * @param novelId 小说ID
     * @param description 角色描述
     * @return 生成的角色信息
     */
    Mono<AIResponse> generateCharacter(String novelId, String description);

    /**
     * 生成情节
     *
     * @param novelId 小说ID
     * @param description 情节描述
     * @return 生成的情节信息
     */
    Mono<AIResponse> generatePlot(String novelId, String description);

    /**
     * 生成设定
     *
     * @param novelId 小说ID
     * @param description 设定描述
     * @return 生成的设定信息
     */
    Mono<AIResponse> generateSetting(String novelId, String description);

    /**
     * 设置是否使用LangChain4j实现
     *
     * @param useLangChain4j 是否使用LangChain4j
     */
    void setUseLangChain4j(boolean useLangChain4j);

    /**
     * 清除用户的模型提供商缓存
     *
     * @param userId 用户ID
     * @return 操作结果
     */
    Mono<Void> clearUserProviderCache(String userId);

    /**
     * 清除所有模型提供商缓存
     *
     * @return 操作结果
     */
    Mono<Void> clearAllProviderCache();

    /**
     * 获取AI模型提供商
     *
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return AI模型提供商
     */
    Mono<AIModelProvider> getAIModelProvider(String userId, String modelName);

    /**
     * 生成聊天响应
     *
     * @param userId 用户ID
     * @param sessionId 会话ID
     * @param content 用户消息内容
     * @param metadata 消息元数据
     * @return 聊天响应
     */
    Mono<AIResponse> generateChatResponse(String userId, String sessionId, String content, Map<String, Object> metadata);

    /**
     * 生成聊天响应（流式）
     *
     * @param userId 用户ID
     * @param sessionId 会话ID
     * @param content 用户消息内容
     * @param metadata 消息元数据
     * @return 流式聊天响应
     */
    Flux<String> generateChatResponseStream(String userId, String sessionId, String content, Map<String, Object> metadata);
}
