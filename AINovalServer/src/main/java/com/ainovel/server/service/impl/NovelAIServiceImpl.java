package com.ainovel.server.service.impl;

import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;

import org.jasypt.encryption.StringEncryptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.UserAIModelConfig;
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
    private final StringEncryptor encryptor;

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
            SceneService sceneService,
            StringEncryptor encryptor) {
        this.aiService = aiService;
        this.knowledgeService = knowledgeService;
        this.novelService = novelService;
        this.promptService = promptService;
        this.userService = userService;
        this.sceneService = sceneService;
        this.encryptor = encryptor;
    }

    @Override
    public Mono<AIResponse> generateNovelContent(AIRequest request) {
        return enrichRequestWithContext(request)
                .flatMap(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMap(provider -> {
                                // 添加请求日志
                                log.info("开始向AI模型发送内容生成请求，用户ID: {}, 模型: {}",
                                        enrichedRequest.getUserId(), enrichedRequest.getModel());

                                // 直接使用业务请求调用提供商
                                return provider.generateContent(enrichedRequest)
                                        .doOnCancel(() -> {
                                            log.info("客户端取消了连接，但AI生成会在后台继续完成, 用户: {}, 模型: {}",
                                                    enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        })
                                        .doOnSuccess(resp -> {
                                            log.info("AI内容生成成功完成，用户ID: {}, 模型: {}",
                                                    enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        })
                                        .timeout(Duration.ofSeconds(600)) // 添加超时设置
                                        .onErrorResume(e -> {
                                            log.error("AI内容生成出错: {}", e.getMessage(), e);
                                            return Mono.error(new RuntimeException("AI内容生成失败: " + e.getMessage(), e));
                                        });
                            })
                            .retry(3); // 添加重试逻辑
                });
    }

    @Override
    public Flux<String> generateNovelContentStream(AIRequest request) {
        return enrichRequestWithContext(request)
                .flatMapMany(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMapMany(provider -> {
                                // 添加请求日志
                                log.info("开始向AI模型发送流式内容生成请求，用户ID: {}, 模型: {}",
                                        enrichedRequest.getUserId(), enrichedRequest.getModel());

                                // 记录开始时间和最后活动时间
                                final AtomicLong startTime = new AtomicLong(System.currentTimeMillis());
                                final AtomicLong lastActivityTime = new AtomicLong(System.currentTimeMillis());

                                // 直接使用业务请求调用提供商
                                return provider.generateContentStream(enrichedRequest)
                                        .doOnSubscribe(sub -> {
                                            log.info("流式生成已订阅，用户ID: {}, 模型: {}",
                                                    enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        })
                                        .doOnNext(chunk -> {
                                            // 只为非心跳消息更新活动时间
                                            if (!"heartbeat".equals(chunk)) {
                                                lastActivityTime.set(System.currentTimeMillis());
                                            }
                                        })
                                        .doOnComplete(() -> {
                                            long duration = System.currentTimeMillis() - startTime.get();
                                            log.info("流式内容生成成功完成，耗时: {}ms，用户ID: {}, 模型: {}",
                                                    duration, enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        })
                                        .doOnCancel(() -> {
                                            log.info("流式生成被取消，但模型会在后台继续生成，用户ID: {}, 模型: {}",
                                                    enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        })
                                        .timeout(Duration.ofSeconds(600)) // 添加超时设置
                                        .onErrorResume(e -> {
                                            log.error("流式内容生成出错: {}", e.getMessage(), e);
                                            return Flux.just("生成出错: " + e.getMessage());
                                        });
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
                                return provider.generateContent(enrichedRequest)
                                        .doOnError(e -> log.error("获取写作建议时出错: {}", e.getMessage(), e));
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
                                return provider.generateContent(enrichedRequest)
                                        .doOnError(e -> log.error("修改内容时出错: {}", e.getMessage(), e));
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
    public Flux<String> generateNextOutlinesStream(String novelId, String currentContext, Integer numberOfOptions, String authorGuidance) {
        log.info("为小说 {} 流式生成下一剧情大纲选项", novelId);

        // 设置默认值
        int optionsCount = numberOfOptions != null ? numberOfOptions : 3;
        String guidance = authorGuidance != null ? authorGuidance : "";

        return createNextOutlinesGenerationRequest(novelId, currentContext, optionsCount, guidance)
                .flatMapMany(request -> enrichRequestWithContext(request)
                .flatMapMany(enrichedRequest -> {
                    // 获取AI模型提供商并直接调用
                    return getAIModelProvider(enrichedRequest.getUserId(), enrichedRequest.getModel())
                            .flatMapMany(provider -> {
                                // 添加请求日志
                                log.info("开始向AI模型发送流式剧情大纲生成请求，用户ID: {}, 模型: {}",
                                        enrichedRequest.getUserId(), enrichedRequest.getModel());

                                // 记录开始时间和最后活动时间
                                final AtomicLong startTime = new AtomicLong(System.currentTimeMillis());
                                final AtomicLong lastActivityTime = new AtomicLong(System.currentTimeMillis());

                                // 直接使用业务请求调用提供商
                                return provider.generateContentStream(enrichedRequest)
                                        .doOnSubscribe(sub -> {
                                            log.info("流式剧情大纲生成已订阅，用户ID: {}, 模型: {}",
                                                    enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        })
                                        .doOnNext(chunk -> {
                                            // 只为非心跳消息更新活动时间
                                            if (!"心跳".equals(chunk) && !"heartbeat".equals(chunk)) {
                                                lastActivityTime.set(System.currentTimeMillis());
                                            }
                                        })
                                        .doOnComplete(() -> {
                                            long duration = System.currentTimeMillis() - startTime.get();
                                            log.info("流式剧情大纲生成成功完成，耗时: {}ms，用户ID: {}, 模型: {}",
                                                    duration, enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        })
                                        .doOnCancel(() -> {
                                            log.info("流式剧情大纲生成被取消，但模型会在后台继续生成，用户ID: {}, 模型: {}",
                                                    enrichedRequest.getUserId(), enrichedRequest.getModel());
                                        });
                            });
                }));
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
                            .replace("{{authorGuidance}}", authorGuidance.isEmpty() ? "" : "作者引导：" + authorGuidance);

                    AIRequest request = new AIRequest();
                    request.setNovelId(novelId);
                    request.setEnableContext(true);

                    // 设置较高的温度以获得多样性
                    request.setTemperature(0.8);
                    // 设置较大的最大令牌数，以确保生成足够详细的大纲
                    request.setMaxTokens(2000);

                    // 创建系统消息
                    AIRequest.Message systemMessage = new AIRequest.Message();
                    systemMessage.setRole("system");
                    systemMessage.setContent("你是一位专业的小说创作顾问，擅长为作者提供多样化的剧情发展选项。请确保每个选项都有明显的差异，提供真正不同的故事发展方向。");
                    request.getMessages().add(systemMessage);

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
        log.info("获取用户 {} 的AI模型提供商，请求的模型: {}", userId, modelName == null ? "默认" : modelName);
        // 如果没有指定模型名称，则使用用户的默认模型
        if (modelName == null || modelName.isEmpty()) {
            return userAIModelConfigService.getValidatedDefaultConfiguration(userId)
                    .doOnNext(config -> log.info("找到用户 {} 的默认配置: Provider={}, Model={}", userId, config.getProvider(), config.getModelName()))
                    .flatMap(config -> {
                        if (config == null) {
                            log.warn("用户 {} 没有配置有效的默认AI模型", userId);
                            return Mono.error(new IllegalArgumentException("用户没有配置默认AI模型"));
                        }
                        return getOrCreateAIModelProvider(userId, config);
                    })
                    .switchIfEmpty(Mono.defer(() -> { // 使用 defer 避免 switchIfEmpty 预先执行
                        log.warn("无法找到用户 {} 的默认AI模型配置", userId);
                        return Mono.error(new IllegalArgumentException("用户没有配置默认AI模型或默认配置无效"));
                    }));
        }

        // 如果指定了模型名称，则查找对应的配置
        return userAIModelConfigService.listConfigurations(userId)
                .filter(config -> modelName.equals(config.getModelName()))
                .next() // 获取第一个匹配的配置
                .doOnNext(config -> log.info("找到用户 {} 指定的模型配置: Provider={}, Model={}", userId, config.getProvider(), config.getModelName()))
                .flatMap(config -> getOrCreateAIModelProvider(userId, config))
                .switchIfEmpty(Mono.defer(() -> { // 使用 defer 避免 switchIfEmpty 预先执行
                    log.warn("找不到用户 {} 指定的AI模型配置: {}", userId, modelName);
                    return Mono.error(new IllegalArgumentException("找不到指定的AI模型配置: " + modelName));
                }));
    }

    /**
     * 获取或创建AI模型提供商
     *
     * @param userId 用户ID
     * @param config AI模型配置
     * @return AI模型提供商
     */
    private Mono<AIModelProvider> getOrCreateAIModelProvider(String userId, UserAIModelConfig config) {
        // 检查配置是否有效
        if (config == null || config.getProvider() == null || config.getModelName() == null) {
            log.error("尝试为用户 {} 创建提供商时遇到无效配置: {}", userId, config);
            return Mono.error(new IllegalArgumentException("无效的AI模型配置"));
        }
        // 检查API Key是否存在
        String encryptedApiKey = config.getApiKey();
        if (encryptedApiKey == null || encryptedApiKey.isBlank()) {
            log.error("用户 {} 的模型配置 Provider={}, Model={} 缺少 API Key", userId, config.getProvider(), config.getModelName());
            // 注意：根据你的业务逻辑，这里可能应该抛出错误或者返回一个表示配置错误的特定状态
            // return Mono.error(new IllegalArgumentException("模型配置缺少 API Key")); // 取消注释以强制要求API Key
        }

        // 检查缓存中是否已存在
        Map<String, AIModelProvider> userProviderMap = userProviders.computeIfAbsent(userId, k -> new HashMap<>());
        String key = config.getProvider() + ":" + config.getModelName();

        AIModelProvider provider = userProviderMap.get(key);
        if (provider != null) {
            log.info("从缓存获取用户 {} 的AI模型提供商: {}", userId, key);
            return Mono.just(provider);
        }

        log.info("缓存未命中，为用户 {} 创建新的AI模型提供商: Provider={}, Model={}, Endpoint={}",
                userId, config.getProvider(), config.getModelName(), config.getApiEndpoint());

        // 解密 API Key
        String decryptedApiKey = null;
        if (encryptedApiKey != null && !encryptedApiKey.isBlank()) {
            try {
                decryptedApiKey = encryptor.decrypt(encryptedApiKey);
                log.debug("用户 {} 的模型 Provider={}, Model={} API Key 解密成功", userId, config.getProvider(), config.getModelName());
            } catch (Exception e) {
                log.error("为用户 {} 的模型 Provider={}, Model={} 解密 API Key 时失败", userId, config.getProvider(), config.getModelName(), e);
                return Mono.error(new RuntimeException("创建AI模型提供商失败，无法解密API Key", e));
            }
        } else {
            log.warn("用户 {} 的模型 Provider={}, Model={} API Key 为空，继续尝试创建提供商（可能适用于本地或无需Key的模型）", userId, config.getProvider(), config.getModelName());
        }

        // 使用AIService创建新的提供商
        try {
            // 传递解密后的 API Key
            final String finalDecryptedApiKey = decryptedApiKey; // Effectively final for lambda
            AIModelProvider newProvider = aiService.createAIModelProvider(
                    config.getProvider(),
                    config.getModelName(),
                    finalDecryptedApiKey, // 使用解密后的 Key
                    config.getApiEndpoint()
            );

            if (newProvider != null) {
                userProviderMap.put(key, newProvider);
                log.info("成功创建并缓存了用户 {} 的AI模型提供商: {}", userId, key);
                return Mono.just(newProvider);
            } else {
                log.error("AIService未能为用户 {} 创建提供商: Provider={}, Model={}", userId, config.getProvider(), config.getModelName());
                return Mono.error(new IllegalArgumentException("无法创建AI模型提供商: " + config.getProvider()));
            }
        } catch (Exception e) {
            log.error("为用户 {} 创建AI模型提供商时出错: Provider={}, Model={}", userId, config.getProvider(), config.getModelName(), e);
            return Mono.error(new RuntimeException("创建AI模型提供商失败", e));
        }
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
                                        .flatMap(provider -> {
                                            // 添加请求日志
                                            log.info("开始向AI模型发送摘要生成请求，用户ID: {}, 模型: {}", userId, aiConfig.getModelName());

                                            // 使用Mono.fromFuture或unsubscribeOn确保即使订阅被取消，任务也会继续执行
                                            return provider.generateContent(aiRequest)
                                                .doOnCancel(() -> {
                                                    log.info("客户端取消了连接，但AI生成会在后台继续完成, 用户: {}, 模型: {}",
                                                            userId, aiConfig.getModelName());
                                                })
                                                .timeout(Duration.ofSeconds(600)) // 添加超时设置
                                                .doOnSuccess(resp -> {
                                                    log.info("AI摘要生成成功完成，用户ID: {}, 模型: {}", userId, aiConfig.getModelName());
                                                })
                                                .onErrorResume(e -> {
                                                    log.error("AI内容生成出错: {}", e.getMessage(), e);
                                                    return Mono.error(new RuntimeException("AI生成摘要失败: " + e.getMessage(), e));
                                                });
                                        })
                                        // 添加重试逻辑处理临时性网络错误
                                        .retry(3);
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
        // 使用PromptUtil工具类处理富文本和占位符替换
        Map<String, String> variables = new HashMap<>();
        variables.put("input", input);
        variables.put("context", context);

        // 添加兼容性，支持旧的占位符格式
        variables.put("content", input);
        variables.put("description", input);
        variables.put("instruction", input);

        return com.ainovel.server.common.util.PromptUtil.formatPromptTemplate(template, variables);
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
                                        .flatMapMany(provider -> {
                                            // 创建一个原子计数器跟踪最后活动时间戳
                                            final AtomicLong lastActivityTimestamp = new AtomicLong(System.currentTimeMillis());

                                            // 创建初始启动延迟，给模型足够时间建立连接
                                            // 用于避免在刚开始时被静默检测器误判为超时
                                            final long initialStartupTime = System.currentTimeMillis();
                                            final int startupGracePeriodSeconds = 60; // 增加到60秒启动宽限期

                                            // 创建静默检测流，每10秒检查一次是否有新活动
                                            // 但要延迟启动，等模型有足够时间建立连接
                                            Flux<String> silenceDetector = Flux.interval(Duration.ofSeconds(10))
                                                    .mapNotNull(tick -> {
                                                        long now = System.currentTimeMillis();

                                                        // 在启动宽限期内不执行静默检测
                                                        if (now - initialStartupTime < startupGracePeriodSeconds * 1000) {
                                                            log.debug("模型建立连接中，处于宽限期内 ({}/{}秒)，userId: {}, novelId: {}",
                                                                    (now - initialStartupTime) / 1000,
                                                                    startupGracePeriodSeconds,
                                                                    userId,
                                                                    novelId);
                                                            return null;
                                                        }

                                                        long lastActivity = lastActivityTimestamp.get();
                                                        // 如果超过60秒没有活动，且已经过了启动宽限期
                                                        if (now - lastActivity > 60000) {
                                                            log.info("检测到生成静默超过60秒，自动结束流, userId: {}, novelId: {}", userId, novelId);
                                                            return "[DONE]";
                                                        }
                                                        // 否则返回null，会被过滤掉
                                                        return null;
                                                    })
                                                    .filter(Objects::nonNull)
                                                    // 只取第一个[DONE]信号
                                                    .take(1);

                                            // 标记是否已完成生成
                                            final AtomicBoolean isStreamCompleted = new AtomicBoolean(false);

                                            // 主内容流，更新活动时间戳
                                            Flux<String> contentFlux = provider.generateContentStream(aiRequest)
                                                    .doOnSubscribe(sub -> {
                                                        log.info("模型流已订阅，启动宽限期 {} 秒, userId: {}, novelId: {}",
                                                                startupGracePeriodSeconds, userId, novelId);
                                                    })
                                                    .doOnNext(content -> {
                                                        if (!"heartbeat".equals(content)) {
                                                            log.debug("收到模型生成内容，更新活动时间戳, userId: {}, novelId: {}", userId, novelId);
                                                            lastActivityTimestamp.set(System.currentTimeMillis());
                                                        }
                                                    })
                                                    .concatWithValues("[DONE]");

                                            // 合并主流和静默检测流，取先发送的[DONE]
                                            return Flux.merge(contentFlux, silenceDetector)
                                                    // 过滤重复的[DONE]标记和heartbeat消息
                                                    .filter(content -> {
                                                        if (content.equals("[DONE]")) {
                                                            // 如果已经有[DONE]标记，则过滤掉
                                                            if (isStreamCompleted.get()) {
                                                                return false;
                                                            }
                                                            isStreamCompleted.set(true);
                                                            return true;
                                                        }
                                                        return !"heartbeat".equals(content);  // 过滤掉heartbeat消息
                                                    })
                                                    // 添加超时保护
                                                    .timeout(Duration.ofSeconds(300))
                                                    .onErrorResume(timeoutError -> {
                                                        log.warn("生成场景内容超时，userId: {}, novelId: {}", userId, novelId);
                                                        return Flux.just(
                                                                "AI模型响应超时，生成已中断。",
                                                                "[DONE]"
                                                        );
                                                    })
                                                    .doOnCancel(() -> {
                                                        log.info("流被取消，但允许模型后台继续生成，userId: {}, novelId: {}", userId, novelId);
                                                    });
                                        });
                            });
                })
                .onErrorResume(e -> {
                    log.error("生成场景内容时出错", e);
                    if (e instanceof AccessDeniedException) {
                        return Flux.error(e);
                    }
                    return Flux.just("生成场景内容时出错: " + e.getMessage(), "[DONE]");
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
