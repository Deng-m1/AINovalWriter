package com.ainovel.server.service.impl;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.User.AIModelConfig;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.KnowledgeService;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.PromptService;
import com.ainovel.server.service.UserService;
import com.ainovel.server.service.ai.AIModelProvider;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说AI服务实现类 专门处理与小说创作相关的AI功能
 */
@Slf4j
@Service
public class NovelAIServiceImpl implements NovelAIService {

    private final AIService aiService;
    private final KnowledgeService knowledgeService;
    private final NovelService novelService;
    private final PromptService promptService;
    private final UserService userService;

    // 缓存用户的AI模型提供商
    private final Map<String, Map<String, AIModelProvider>> userProviders = new ConcurrentHashMap<>();

    // 是否使用LangChain4j实现
    private boolean useLangChain4j = true;

    @Autowired
    public NovelAIServiceImpl(
            @Qualifier("AIServiceImpl") AIService aiService,
            KnowledgeService knowledgeService,
            NovelService novelService,
            PromptService promptService,
            UserService userService) {
        this.aiService = aiService;
        this.knowledgeService = knowledgeService;
        this.novelService = novelService;
        this.promptService = promptService;
        this.userService = userService;
    }

    @Override
    public Mono<AIResponse> generateNovelContent(AIRequest request) {
        return enrichRequestWithContext(request)
                .flatMap(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMap(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContent(enrichedRequest);
                            });
                });
    }

    @Override
    public Flux<String> generateNovelContentStream(AIRequest request) {
        return enrichRequestWithContext(request)
                .flatMapMany(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMapMany(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContentStream(enrichedRequest);
                            });
                });
    }

    @Override
    public Mono<AIResponse> getWritingSuggestion(String novelId, String sceneId, String suggestionType) {
        return createSuggestionRequest(novelId, sceneId, suggestionType)
                .flatMap(this::enrichRequestWithContext)
                .flatMap(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMap(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContent(enrichedRequest);
                            });
                });
    }

    @Override
    public Flux<String> getWritingSuggestionStream(String novelId, String sceneId, String suggestionType) {
        return createSuggestionRequest(novelId, sceneId, suggestionType)
                .flatMapMany(request -> enrichRequestWithContext(request)
                .flatMapMany(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMapMany(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContentStream(enrichedRequest);
                            });
                }));
    }

    @Override
    public Mono<AIResponse> reviseContent(String novelId, String sceneId, String content, String instruction) {
        return createRevisionRequest(novelId, sceneId, content, instruction)
                .flatMap(this::enrichRequestWithContext)
                .flatMap(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMap(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContent(enrichedRequest);
                            });
                });
    }

    @Override
    public Flux<String> reviseContentStream(String novelId, String sceneId, String content, String instruction) {
        return createRevisionRequest(novelId, sceneId, content, instruction)
                .flatMapMany(request -> enrichRequestWithContext(request)
                .flatMapMany(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMapMany(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContentStream(enrichedRequest);
                            });
                }));
    }

    @Override
    public Mono<AIResponse> generateCharacter(String novelId, String description) {
        return createCharacterGenerationRequest(novelId, description)
                .flatMap(this::enrichRequestWithContext)
                .flatMap(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMap(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContent(enrichedRequest);
                            });
                });
    }

    @Override
    public Mono<AIResponse> generatePlot(String novelId, String description) {
        return createPlotGenerationRequest(novelId, description)
                .flatMap(this::enrichRequestWithContext)
                .flatMap(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMap(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContent(enrichedRequest);
                            });
                });
    }

    @Override
    public Mono<AIResponse> generateSetting(String novelId, String description) {
        return createSettingGenerationRequest(novelId, description)
                .flatMap(this::enrichRequestWithContext)
                .flatMap(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMap(provider -> {
                                // 直接使用业务请求调用提供商
                                return provider.generateContent(enrichedRequest);
                            });
                });
    }

    @Override
    public Mono<AIResponse> generateChatResponse(String userId, String sessionId, String content, Map<String, Object> metadata) {
        return getAIModelProvider(userId, null)
                .flatMap(provider -> {
                    AIRequest request = new AIRequest();
                    request.setUserId(userId);
                    // 使用反射设置sessionId和metadata
                    try {
                        request.getClass().getMethod("setSessionId", String.class).invoke(request, sessionId);
                        request.getClass().getMethod("setMetadata", Map.class).invoke(request, metadata);
                    } catch (Exception e) {
                        log.error("Failed to set sessionId or metadata", e);
                    }

                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(content);
                    request.getMessages().add(userMessage);

                    return provider.generateContent(request);
                });
    }

    @Override
    public Flux<String> generateChatResponseStream(String userId, String sessionId, String content, Map<String, Object> metadata) {
        return getAIModelProvider(userId, null)
                .flatMapMany(provider -> {
                    AIRequest request = new AIRequest();
                    request.setUserId(userId);
                    // 使用反射设置sessionId和metadata
                    try {
                        request.getClass().getMethod("setSessionId", String.class).invoke(request, sessionId);
                        request.getClass().getMethod("setMetadata", Map.class).invoke(request, metadata);
                    } catch (Exception e) {
                        log.error("Failed to set sessionId or metadata", e);
                    }

                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(content);
                    request.getMessages().add(userMessage);

                    return provider.generateContentStream(request);
                });
    }

    /**
     * 使用上下文丰富AI请求
     *
     * @param request 原始请求
     * @return 丰富后的请求
     */
    private Mono<AIRequest> enrichRequestWithContext(AIRequest request) {
        if (request.getEnableContext() != null && !request.getEnableContext()) {
            return Mono.just(request);
        }

        String novelId = request.getNovelId();
        if (novelId == null || novelId.isEmpty()) {
            return Mono.just(request);
        }

        // 获取相关上下文
        return knowledgeService.retrieveRelevantContext(request.getPrompt(), novelId)
                .map(context -> {
                    // 创建新的系统消息，包含上下文
                    AIRequest.Message systemMessage = new AIRequest.Message();
                    systemMessage.setRole("system");
                    systemMessage.setContent("以下是小说的相关上下文信息，请在生成内容时参考：\n\n" + context);

                    // 添加到消息列表的开头
                    request.getMessages().add(0, systemMessage);
                    return request;
                })
                .onErrorResume(e -> {
                    log.error("获取上下文失败", e);
                    return Mono.just(request);
                });
    }

    /**
     * 创建建议请求
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @param suggestionType 建议类型
     * @return AI请求
     */
    private Mono<AIRequest> createSuggestionRequest(String novelId, String sceneId, String suggestionType) {
        return promptService.getSuggestionPrompt(suggestionType)
                .map(promptTemplate -> {
                    AIRequest request = new AIRequest();
                    request.setNovelId(novelId);
                    request.setSceneId(sceneId);
                    request.setEnableContext(true);

                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(promptTemplate);

                    request.getMessages().add(userMessage);
                    return request;
                });
    }

    /**
     * 创建修改请求
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @param content 原内容
     * @param instruction 修改指令
     * @return AI请求
     */
    private Mono<AIRequest> createRevisionRequest(String novelId, String sceneId, String content, String instruction) {
        return promptService.getRevisionPrompt()
                .map(promptTemplate -> {
                    String prompt = promptTemplate
                            .replace("{{content}}", content)
                            .replace("{{instruction}}", instruction);

                    AIRequest request = new AIRequest();
                    request.setNovelId(novelId);
                    request.setSceneId(sceneId);
                    request.setEnableContext(true);

                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(prompt);

                    request.getMessages().add(userMessage);
                    return request;
                });
    }

    /**
     * 创建角色生成请求
     *
     * @param novelId 小说ID
     * @param description 角色描述
     * @return AI请求
     */
    private Mono<AIRequest> createCharacterGenerationRequest(String novelId, String description) {
        return promptService.getCharacterGenerationPrompt()
                .map(promptTemplate -> {
                    String prompt = promptTemplate.replace("{{description}}", description);

                    AIRequest request = new AIRequest();
                    request.setNovelId(novelId);
                    request.setEnableContext(true);

                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(prompt);

                    request.getMessages().add(userMessage);
                    return request;
                });
    }

    /**
     * 创建情节生成请求
     *
     * @param novelId 小说ID
     * @param description 情节描述
     * @return AI请求
     */
    private Mono<AIRequest> createPlotGenerationRequest(String novelId, String description) {
        return promptService.getPlotGenerationPrompt()
                .map(promptTemplate -> {
                    String prompt = promptTemplate.replace("{{description}}", description);

                    AIRequest request = new AIRequest();
                    request.setNovelId(novelId);
                    request.setEnableContext(true);

                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(prompt);

                    request.getMessages().add(userMessage);
                    return request;
                });
    }

    /**
     * 创建设定生成请求
     *
     * @param novelId 小说ID
     * @param description 设定描述
     * @return AI请求
     */
    private Mono<AIRequest> createSettingGenerationRequest(String novelId, String description) {
        return promptService.getSettingGenerationPrompt()
                .map(promptTemplate -> {
                    String prompt = promptTemplate.replace("{{description}}", description);

                    AIRequest request = new AIRequest();
                    request.setNovelId(novelId);
                    request.setEnableContext(true);

                    // 创建用户消息
                    AIRequest.Message userMessage = new AIRequest.Message();
                    userMessage.setRole("user");
                    userMessage.setContent(prompt);

                    request.getMessages().add(userMessage);
                    return request;
                });
    }

    /**
     * 获取AI模型提供商
     *
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return AI模型提供商
     */
    @Override
    public Mono<AIModelProvider> getAIModelProvider(String userId, String modelName) {
        // 如果没有指定模型名称，则使用用户的默认模型
        if (modelName == null || modelName.isEmpty()) {
            return userService.getUserDefaultAIModelConfig(userId)
                    .flatMap(config -> {
                        if (config == null) {
                            return Mono.error(new IllegalArgumentException("用户没有配置默认AI模型"));
                        }
                        return getOrCreateAIModelProvider(userId, config);
                    });
        }

        // 如果指定了模型名称，则查找对应的配置
        return userService.getUserAIModelConfigs(userId)
                .filter(config -> modelName.equals(config.getModelName()))
                .next()
                .flatMap(config -> getOrCreateAIModelProvider(userId, config))
                .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到指定的AI模型配置: " + modelName)));
    }

    /**
     * 获取或创建AI模型提供商
     *
     * @param userId 用户ID
     * @param config AI模型配置
     * @return AI模型提供商
     */
    private Mono<AIModelProvider> getOrCreateAIModelProvider(String userId, AIModelConfig config) {
        // 检查缓存中是否已存在
        Map<String, AIModelProvider> userProviderMap = userProviders.computeIfAbsent(userId, k -> new HashMap<>());
        String key = config.getProvider() + ":" + config.getModelName();

        AIModelProvider provider = userProviderMap.get(key);
        if (provider != null) {
            return Mono.just(provider);
        }

        // 使用AIService创建新的提供商
        provider = aiService.createAIModelProvider(
                config.getProvider(),
                config.getModelName(),
                config.getApiKey(),
                config.getApiEndpoint()
        );

        if (provider != null) {
            userProviderMap.put(key, provider);
            return Mono.just(provider);
        }

        return Mono.error(new IllegalArgumentException("不支持的AI模型提供商: " + config.getProvider()));
    }

    /**
     * 设置是否使用LangChain4j实现
     *
     * @param useLangChain4j 是否使用LangChain4j
     */
    @Override
    public void setUseLangChain4j(boolean useLangChain4j) {
        // 委托给AIService
        aiService.setUseLangChain4j(useLangChain4j);
        // 清空缓存，强制重新创建提供商
        userProviders.clear();
    }

    /**
     * 清除用户的模型提供商缓存
     *
     * @param userId 用户ID
     * @return 操作结果
     */
    public Mono<Void> clearUserProviderCache(String userId) {
        return Mono.fromRunnable(() -> userProviders.remove(userId));
    }

    /**
     * 清除所有模型提供商缓存
     *
     * @return 操作结果
     */
    public Mono<Void> clearAllProviderCache() {
        return Mono.fromRunnable(userProviders::clear);
    }

}
