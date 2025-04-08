package com.ainovel.server.service.impl;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.User.AIModelConfig;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.KnowledgeService;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.NovelRagAssistant;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.PromptService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.service.UserAIModelConfigService;
import com.ainovel.server.service.UserPromptService;
import com.ainovel.server.service.UserService;
import com.ainovel.server.service.ai.AIModelProvider;
import com.ainovel.server.service.rag.RagService;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryRequest;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryResponse;
import com.ainovel.server.web.dto.SummarizeSceneRequest;
import com.ainovel.server.web.dto.SummarizeSceneResponse;

import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.rag.content.Content;
import dev.langchain4j.rag.content.retriever.ContentRetriever;
import dev.langchain4j.rag.query.Query;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

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
    private final SceneService sceneService;

    // 缓存用户的AI模型提供商
    private final Map<String, Map<String, AIModelProvider>> userProviders = new ConcurrentHashMap<>();

    @Autowired
    private ContentRetriever contentRetriever;

    @Autowired
    private NovelRagAssistant novelRagAssistant;

    @Autowired
    private RagService ragService;

    @Autowired
    private UserPromptService userPromptService;

    @Autowired
    private UserAIModelConfigService userAIModelConfigService;

    @Autowired
    public NovelAIServiceImpl(
            @Qualifier("AIServiceImpl") AIService aiService,
            KnowledgeService knowledgeService,
            NovelService novelService,
            PromptService promptService,
            UserService userService,
            SceneService sceneService) {
        this.aiService = aiService;
        this.knowledgeService = knowledgeService;
        this.novelService = novelService;
        this.promptService = promptService;
        this.userService = userService;
        this.sceneService = sceneService;
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
    public Mono<AIResponse> generateNextOutlines(String novelId, String currentContext, Integer numberOfOptions, String authorGuidance) {
        log.info("为小说 {} 生成下一剧情大纲选项", novelId);

        // 设置默认值
        int optionsCount = numberOfOptions != null ? numberOfOptions : 3;
        String guidance = authorGuidance != null ? authorGuidance : "";

        return createNextOutlinesGenerationRequest(novelId, currentContext, optionsCount, guidance)
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
        // 如果没有指定小说ID，则直接返回原始请求
        if (request.getNovelId() == null || request.getNovelId().isEmpty()) {
            return Mono.just(request);
        }

        log.info("为请求丰富上下文，小说ID: {}", request.getNovelId());

        // 获取是否启用RAG
        boolean enableRag = request.getMetadata() != null
                && request.getMetadata().getOrDefault("enableRag", "false").toString().equalsIgnoreCase("true");

        if (!enableRag) {
            // 如果未启用RAG，使用原有逻辑
            return getNovelContextFromDatabase(request);
        }

        log.info("为请求使用RAG检索上下文，小说ID: {}", request.getNovelId());

        // 从请求中提取查询文本
        String queryText = extractQueryTextFromRequest(request);

        if (queryText.isEmpty()) {
            return getNovelContextFromDatabase(request);
        }

        // 使用ContentRetriever检索相关上下文
        // 将可能阻塞的操作放在boundedElastic调度器上执行
        return Mono.fromCallable(() -> {
            List<Content> relevantContents = contentRetriever.retrieve(Query.from(queryText));

            // 将Content转换为TextSegment
            List<TextSegment> relevantSegments = relevantContents.stream()
                    .map(Content::textSegment)
                    .collect(Collectors.toList());

            if (relevantSegments.isEmpty()) {
                log.info("RAG未找到相关上下文，使用数据库检索");
                return request;
            }

            log.info("RAG检索到 {} 个相关段落", relevantSegments.size());

            // 格式化检索到的上下文
            String relevantContext = formatRetrievedContext(relevantSegments);

            // 将检索到的上下文添加到系统消息中
            if (request.getMessages() == null) {
                request.setMessages(new ArrayList<>());
            }

            // 添加系统消息
            AIRequest.Message systemMessage = new AIRequest.Message();
            systemMessage.setRole("system");
            systemMessage.setContent("你是一位小说创作助手。以下是一些相关的上下文信息，可能对回答有帮助：\n\n" + relevantContext);

            // 在消息列表开头插入系统消息
            if (!request.getMessages().isEmpty()) {
                request.getMessages().add(0, systemMessage);
            } else {
                request.getMessages().add(systemMessage);
            }

            // 在元数据中标记已使用RAG
            if (request.getMetadata() != null) {
                request.getMetadata().put("usedRag", "true");
            }

            return request;
        })
                .subscribeOn(Schedulers.boundedElastic()) // 在boundedElastic调度器上执行可能阻塞的操作
                .onErrorResume(e -> {
                    log.error("使用RAG检索上下文时出错", e);
                    return getNovelContextFromDatabase(request);
                });
    }

    /**
     * 从数据库获取小说上下文
     *
     * @param request AI请求
     * @return 丰富的AI请求
     */
    private Mono<AIRequest> getNovelContextFromDatabase(AIRequest request) {
        // 原有的从数据库获取上下文的逻辑
        return knowledgeService.retrieveRelevantContext(extractQueryTextFromRequest(request), request.getNovelId())
                .subscribeOn(Schedulers.boundedElastic()) // 在boundedElastic调度器上执行可能阻塞的操作
                .map(context -> {
                    if (context != null && !context.isEmpty()) {
                        log.info("从知识库中获取到相关上下文");

                        if (request.getMessages() == null) {
                            request.setMessages(new ArrayList<>());
                        }

                        // 创建系统消息
                        AIRequest.Message systemMessage = new AIRequest.Message();
                        systemMessage.setRole("system");
                        systemMessage.setContent("你是一位小说创作助手。以下是一些相关的上下文信息，可能对回答有帮助：\n\n" + context);

                        // 在消息列表开头插入系统消息
                        if (!request.getMessages().isEmpty()) {
                            request.getMessages().add(0, systemMessage);
                        } else {
                            request.getMessages().add(systemMessage);
                        }
                    }
                    return request;
                })
                .onErrorResume(e -> {
                    log.error("获取知识库上下文时出错", e);
                    return Mono.just(request);
                })
                .defaultIfEmpty(request);
    }

    /**
     * 从请求中提取查询文本
     *
     * @param request AI请求
     * @return 查询文本
     */
    private String extractQueryTextFromRequest(AIRequest request) {
        // 从消息列表中提取用户最后一条消息
        if (request.getMessages() != null && !request.getMessages().isEmpty()) {
            return request.getMessages().stream()
                    .filter(msg -> "user".equals(msg.getRole()))
                    .reduce((first, second) -> second) // 获取最后一条用户消息
                    .map(AIRequest.Message::getContent)
                    .orElse("");
        }

        // 如果没有消息，则使用提示文本
        return request.getPrompt() != null ? request.getPrompt() : "";
    }

    /**
     * 格式化检索到的上下文
     *
     * @param segments 文本段落列表
     * @return 格式化的上下文
     */
    private String formatRetrievedContext(List<TextSegment> segments) {
        StringBuilder builder = new StringBuilder();

        for (int i = 0; i < segments.size(); i++) {
            TextSegment segment = segments.get(i);
            builder.append("段落 #").append(i + 1).append(":\n");

            // 添加元数据信息（如果存在）
            if (segment.metadata() != null) {
                Map<String, Object> metadata = segment.metadata().toMap();
                if (metadata.containsKey("title")) {
                    builder.append("标题: ").append(metadata.get("title")).append("\n");
                }
                if (metadata.containsKey("sourceType")) {
                    String sourceType = metadata.get("sourceType").toString();
                    if ("scene".equals(sourceType)) {
                        builder.append("类型: 场景\n");
                    } else if ("novel_metadata".equals(sourceType)) {
                        builder.append("类型: 小说元数据\n");
                    } else {
                        builder.append("类型: ").append(sourceType).append("\n");
                    }
                }
            }

            // 添加文本内容
            builder.append(segment.text()).append("\n\n");
        }

        return builder.toString();
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
     * 创建下一剧情大纲生成请求
     *
     * @param novelId 小说ID
     * @param currentContext 当前剧情上下文
     * @param numberOfOptions 希望生成的选项数量
     * @param authorGuidance 作者引导
     * @return AI请求
     */
    private Mono<AIRequest> createNextOutlinesGenerationRequest(String novelId, String currentContext, int numberOfOptions, String authorGuidance) {
        return promptService.getNextOutlinesGenerationPrompt()
                .map(promptTemplate -> {
                    // 根据提示词模板替换变量
                    String prompt = promptTemplate
                            .replace("{{context}}", currentContext)
                            .replace("{{numberOfOptions}}", String.valueOf(numberOfOptions))
                            .replace("{{authorGuidance}}", authorGuidance.isEmpty() ? "" : "作者希望: " + authorGuidance);

                    AIRequest request = new AIRequest();
                    request.setNovelId(novelId);
                    request.setEnableContext(true);

                    // 设置较高的温度以获得多样性
                    request.setTemperature(0.8);

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
    @Override
    public Mono<Void> clearUserProviderCache(String userId) {
        return Mono.fromRunnable(() -> userProviders.remove(userId));
    }

    /**
     * 清除所有模型提供商缓存
     *
     * @return 操作结果
     */
    @Override
    public Mono<Void> clearAllProviderCache() {
        return Mono.fromRunnable(userProviders::clear);
    }

    /**
     * 为指定场景生成摘要
     *
     * @param userId 用户ID
     * @param sceneId 场景ID
     * @param request 摘要请求参数
     * @return 包含摘要的响应
     */
    @Override
    public Mono<SummarizeSceneResponse> summarizeScene(String userId, String sceneId, SummarizeSceneRequest request) {
        return sceneService.findSceneById(sceneId)
                .flatMap(scene -> {
                    // 权限校验
                    return novelService.findNovelById(scene.getNovelId())
                            .flatMap(novel -> {
                                if (!novel.getAuthor().getId().equals(userId)) {
                                    return Mono.error(new AccessDeniedException("用户无权访问该场景"));
                                }

                                // 并行获取RAG上下文和用户Prompt模板
                                Mono<String> contextMono = ragService.retrieveRelevantContext(
                                        scene.getNovelId(), sceneId, AIFeatureType.SCENE_TO_SUMMARY);

                                Mono<String> promptTemplateMono = userPromptService.getPromptTemplate(
                                        userId, AIFeatureType.SCENE_TO_SUMMARY);

                                // 返回包含场景、上下文、模板的Tuple
                                return Mono.zip(Mono.just(scene.getContent()), contextMono, promptTemplateMono);
                            });
                })
                .flatMap(tuple -> {
                    String sceneContent = tuple.getT1();
                    String context = tuple.getT2();
                    String promptTemplate = tuple.getT3();

                    // 构建最终Prompt
                    String finalPrompt = buildFinalPrompt(promptTemplate, context, sceneContent);

                    // 获取AI配置并调用LLM
                    return userAIModelConfigService.getValidatedDefaultConfiguration(userId)
                            .flatMap(aiConfig -> {
                                AIRequest aiRequest = new AIRequest();
                                aiRequest.setUserId(userId);
                                aiRequest.setModel(aiConfig.getModelName());

                                // 创建系统消息
                                AIRequest.Message systemMessage = new AIRequest.Message();
                                systemMessage.setRole("system");
                                systemMessage.setContent("你是一个专业的小说编辑，需要为小说场景生成简洁的摘要。");
                                aiRequest.getMessages().add(systemMessage);

                                // 创建用户消息
                                AIRequest.Message userMessage = new AIRequest.Message();
                                userMessage.setRole("user");
                                userMessage.setContent(finalPrompt);
                                aiRequest.getMessages().add(userMessage);

                                // 设置生成参数
                                aiRequest.setTemperature(0.7);
                                aiRequest.setMaxTokens(500);

                                // 获取AI模型提供商
                                return getAIModelProvider(userId, aiConfig.getModelName())
                                        .flatMap(provider -> provider.generateContent(aiRequest));
                            })
                            .map(response -> new SummarizeSceneResponse(response.getContent()));
                })
                .onErrorResume(e -> {
                    log.error("生成场景摘要时出错", e);
                    if (e instanceof AccessDeniedException) {
                        return Mono.error(e);
                    }
                    return Mono.error(new RuntimeException("生成摘要失败: " + e.getMessage()));
                });
    }

    /**
     * 构建最终提示词
     */
    private String buildFinalPrompt(String template, String context, String input) {
        return template
                .replace("{input}", input)
                .replace("{context}", context);
    }

    /**
     * 根据摘要生成场景内容 (流式)
     *
     * @param userId 用户ID
     * @param novelId 小说ID
     * @param request 生成场景请求参数
     * @return 生成的场景内容流
     */
    @Override
    public Flux<String> generateSceneFromSummaryStream(String userId, String novelId, GenerateSceneFromSummaryRequest request) {
        log.info("根据摘要生成场景内容(流式), userId: {}, novelId: {}", userId, novelId);

        // 验证用户对小说的访问权限
        return novelService.findNovelById(novelId)
                .flatMap(novel -> {
                    if (!novel.getAuthor().getId().equals(userId)) {
                        return Mono.error(new AccessDeniedException("用户无权访问该小说"));
                    }

                    // 并行获取RAG上下文和用户Prompt模板
                    Mono<String> contextMono = ragService.retrieveRelevantContext(
                            novelId, request.getChapterId(), request.getSummary(), AIFeatureType.SUMMARY_TO_SCENE);

                    Mono<String> promptTemplateMono = userPromptService.getPromptTemplate(
                            userId, AIFeatureType.SUMMARY_TO_SCENE);

                    // 返回包含上下文、模板的Tuple
                    return Mono.zip(contextMono, promptTemplateMono);
                })
                .flatMapMany(tuple -> {
                    String context = tuple.getT1();
                    String promptTemplate = tuple.getT2();

                    // 构建最终Prompt，包含用户风格指令
                    String styleInstructions = request.getStyleInstructions() != null ? request.getStyleInstructions() : "";
                    String inputWithStyle = request.getSummary() + (styleInstructions.isEmpty() ? "" : "\n\n风格要求: " + styleInstructions);

                    String finalPrompt = buildFinalPrompt(promptTemplate, context, inputWithStyle);

                    // 获取AI配置并调用LLM (流式)
                    return userAIModelConfigService.getValidatedDefaultConfiguration(userId)
                            .flatMapMany(aiConfig -> {
                                AIRequest aiRequest = new AIRequest();
                                aiRequest.setUserId(userId);
                                aiRequest.setNovelId(novelId);
                                aiRequest.setModel(aiConfig.getModelName());

                                // 创建系统消息
                                AIRequest.Message systemMessage = new AIRequest.Message();
                                systemMessage.setRole("system");
                                systemMessage.setContent("你是一位富有创意的小说家，需要根据摘要生成详细的小说场景内容。");
                                aiRequest.getMessages().add(systemMessage);

                                // 创建用户消息
                                AIRequest.Message userMessage = new AIRequest.Message();
                                userMessage.setRole("user");
                                userMessage.setContent(finalPrompt);
                                aiRequest.getMessages().add(userMessage);

                                // 设置生成参数 - 场景生成可以设置稍高的温度以增加创意性
                                aiRequest.setTemperature(0.8);
                                aiRequest.setMaxTokens(2000);

                                // 获取AI模型提供商并调用流式生成
                                return getAIModelProvider(userId, aiConfig.getModelName())
                                        .flatMapMany(provider -> provider.generateContentStream(aiRequest));
                            });
                })
                .onErrorResume(e -> {
                    log.error("生成场景内容时出错", e);
                    if (e instanceof AccessDeniedException) {
                        return Flux.error(e);
                    }
                    return Flux.error(new RuntimeException("生成场景内容时出错: " + e.getMessage()));
                });
    }

    /**
     * 根据摘要生成场景内容 (非流式)
     *
     * @param userId 用户ID
     * @param novelId 小说ID
     * @param request 生成场景请求参数
     * @return 包含生成场景内容的响应
     */
    @Override
    public Mono<GenerateSceneFromSummaryResponse> generateSceneFromSummary(String userId, String novelId, GenerateSceneFromSummaryRequest request) {
        log.info("根据摘要生成场景内容(非流式), userId: {}, novelId: {}", userId, novelId);

        // 使用流式API并收集结果
        return generateSceneFromSummaryStream(userId, novelId, request)
                .collect(StringBuilder::new, StringBuilder::append)
                .map(sb -> new GenerateSceneFromSummaryResponse(sb.toString()));
    }

}
