package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.jasypt.encryption.StringEncryptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import com.ainovel.server.domain.model.AIChatMessage;
import com.ainovel.server.domain.model.AIChatSession;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.UserAIModelConfig;
import com.ainovel.server.repository.AIChatMessageRepository;
import com.ainovel.server.repository.AIChatSessionRepository;
import com.ainovel.server.service.AIChatService;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.UserAIModelConfigService;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Slf4j
@Service
public class AIChatServiceImpl implements AIChatService {

    private final AIChatSessionRepository sessionRepository;
    private final AIChatMessageRepository messageRepository;
    private final UserAIModelConfigService userAIModelConfigService;
    private final AIService aiService;
    private final StringEncryptor encryptor;

    @Value("${ainovel.ai.default-system-model:gpt-3.5-turbo}")
    private String defaultSystemModelName;

    @Autowired
    public AIChatServiceImpl(AIChatSessionRepository sessionRepository,
            AIChatMessageRepository messageRepository,
            UserAIModelConfigService userAIModelConfigService,
            AIService aiService,
            StringEncryptor encryptor) {
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.userAIModelConfigService = userAIModelConfigService;
        this.aiService = aiService;
        this.encryptor = encryptor;
    }

    @Override
    public Mono<AIChatSession> createSession(String userId, String novelId, String modelName, Map<String, Object> metadata) {
        if (StringUtils.hasText(modelName)) {
            log.info("尝试使用用户指定的模型名称创建会话: userId={}, modelName={}", userId, modelName);
            String provider;
            try {
                provider = aiService.getProviderForModel(modelName);
            } catch (IllegalArgumentException e) {
                log.warn("用户指定的模型名称无效: {}", modelName);
                return Mono.error(new IllegalArgumentException("指定的模型名称无效: " + modelName));
            }
            return userAIModelConfigService.getValidatedConfig(userId, provider, modelName)
                    .flatMap(config -> {
                        log.info("找到用户 {} 的模型 {} 对应配置 ID: {}", userId, modelName, config.getId());
                        return createSessionInternal(userId, novelId, config.getId(), metadata);
                    })
                    .switchIfEmpty(Mono.defer(() -> {
                        log.warn("用户 {} 指定的模型 {} 未找到有效的配置", userId, modelName);
                        return Mono.error(new RuntimeException("您选择的模型 '" + modelName + "' 未配置或未验证，请先在模型设置中配置。"));
                    }));
        } else {
            log.info("未指定模型，开始为用户 {} 智能选择模型...", userId);
            return findSuitableModelConfig(userId)
                    .flatMap(config -> createSessionInternal(userId, novelId, config.getId(), metadata))
                    .switchIfEmpty(Mono.defer(() -> {
                        log.error("无法为用户 {} 找到任何已验证的模型配置。", userId);
                        return Mono.error(new RuntimeException("您还没有配置任何可用的AI模型。请先在设置中添加并验证模型API Key。"));
                    }));
        }
    }

    private Mono<AIChatSession> createSessionInternal(String userId, String novelId, String selectedModelConfigId, Map<String, Object> metadata) {
        String sessionId = UUID.randomUUID().toString();
        AIChatSession session = AIChatSession.builder()
                .sessionId(sessionId)
                .userId(userId)
                .novelId(novelId)
                .selectedModelConfigId(selectedModelConfigId)
                .metadata(metadata)
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .messageCount(0)
                .build();

        log.info("创建新会话: userId={}, sessionId={}, selectedModelConfigId={}", userId, sessionId, selectedModelConfigId);
        return sessionRepository.save(session);
    }

    private Mono<UserAIModelConfig> findSuitableModelConfig(String userId) {
        return userAIModelConfigService.getValidatedDefaultConfiguration(userId)
                .doOnNext(config -> log.info("找到用户 {} 的默认模型配置: configId={}, modelName={}", userId, config.getId(), config.getModelName()))
                .switchIfEmpty(Mono.defer(() -> {
                    log.info("用户 {} 无默认模型，尝试查找第一个可用模型...", userId);
                    return userAIModelConfigService.getFirstValidatedConfiguration(userId)
                            .doOnNext(config -> log.info("找到用户 {} 的第一个可用模型配置: configId={}, modelName={}", userId, config.getId(), config.getModelName()));
                }));
    }

    @Override
    public Mono<AIChatSession> getSession(String userId, String sessionId) {
        return sessionRepository.findByUserIdAndSessionId(userId, sessionId);
    }

    @Override
    public Flux<AIChatSession> listUserSessions(String userId, int page, int size) {
        return sessionRepository.findByUserId(userId,
                PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "updatedAt")));
    }

    @Override
    public Mono<AIChatSession> updateSession(String userId, String sessionId, Map<String, Object> updates) {
        return sessionRepository.findByUserIdAndSessionId(userId, sessionId)
                .flatMap(session -> {
                    boolean needsSave = false;
                    Mono<AIChatSession> updateMono = Mono.just(session);

                    if (updates.containsKey("title") && updates.get("title") instanceof String) {
                        session.setTitle((String) updates.get("title"));
                        needsSave = true;
                    }
                    if (updates.containsKey("status") && updates.get("status") instanceof String) {
                        session.setStatus((String) updates.get("status"));
                        needsSave = true;
                    }
                    if (updates.containsKey("metadata") && updates.get("metadata") instanceof Map) {
                        session.setMetadata((Map<String, Object>) updates.get("metadata"));
                        needsSave = true;
                    }

                    if (updates.containsKey("selectedModelConfigId") && updates.get("selectedModelConfigId") instanceof String newSelectedModelConfigId) {
                        if (!newSelectedModelConfigId.equals(session.getSelectedModelConfigId())) {
                            log.info("用户 {} 尝试更新会话 {} 的模型配置为 ID: {}", userId, sessionId, newSelectedModelConfigId);
                            updateMono = userAIModelConfigService.getConfigurationById(userId, newSelectedModelConfigId)
                                    .filter(UserAIModelConfig::getIsValidated)
                                    .flatMap(config -> {
                                        log.info("找到并验证通过新的模型配置: configId={}, modelName={}", config.getId(), config.getModelName());
                                        session.setSelectedModelConfigId(newSelectedModelConfigId);
                                        session.setUpdatedAt(LocalDateTime.now());
                                        log.info("会话 {} 模型配置已更新为: {}", sessionId, newSelectedModelConfigId);
                                        return Mono.just(session);
                                    })
                                    .switchIfEmpty(Mono.defer(() -> {
                                        log.warn("用户 {} 尝试更新会话 {} 到模型配置ID {}，但未找到有效或已验证的配置", userId, sessionId, newSelectedModelConfigId);
                                        return Mono.error(new RuntimeException("无法更新到指定的模型配置 '" + newSelectedModelConfigId + "'，请确保配置存在且已验证。"));
                                    }));
                            needsSave = true;
                        }
                    }

                    final boolean finalNeedsSave = needsSave;
                    return updateMono.flatMap(updatedSession -> {
                        if (finalNeedsSave && !updatedSession.getStatus().equals("FAILED")) {
                            updatedSession.setUpdatedAt(LocalDateTime.now());
                            log.info("保存会话更新: userId={}, sessionId={}", userId, sessionId);
                            return sessionRepository.save(updatedSession);
                        }
                        return Mono.just(updatedSession);
                    });
                });
    }

    @Override
    public Mono<Void> deleteSession(String userId, String sessionId) {
        log.warn("准备删除会话及其消息: userId={}, sessionId={}", userId, sessionId);
        return messageRepository.deleteBySessionId(sessionId)
                .then(sessionRepository.deleteByUserIdAndSessionId(userId, sessionId))
                .doOnSuccess(v -> log.info("成功删除会话及其消息: userId={}, sessionId={}", userId, sessionId))
                .doOnError(e -> log.error("删除会话时出错: userId={}, sessionId={}", userId, sessionId, e));
    }

    @Override
    public Mono<AIChatMessage> sendMessage(String userId, String sessionId, String content, Map<String, Object> metadata) {
        return getSession(userId, sessionId)
                .switchIfEmpty(Mono.error(new RuntimeException("会话不存在或无权访问: " + sessionId)))
                .flatMap(session -> {
                    return userAIModelConfigService.getConfigurationById(userId, session.getSelectedModelConfigId())
                            .switchIfEmpty(Mono.error(new RuntimeException("无法找到或访问会话关联的模型配置: " + session.getSelectedModelConfigId())))
                            .flatMap(config -> {
                                if (!config.getIsValidated()) {
                                    log.error("发送消息失败，会话 {} 使用的模型配置 {} 未验证", sessionId, config.getId());
                                    return Mono.error(new RuntimeException("当前会话使用的模型配置无效或未验证。"));
                                }

                                String actualModelName = config.getModelName();
                                log.debug("会话 {} 使用模型配置 ID: {}, 实际模型名称: {}", sessionId, config.getId(), actualModelName);

                                AIChatMessage userMessage = AIChatMessage.builder()
                                        .sessionId(sessionId)
                                        .userId(userId)
                                        .role("user")
                                        .content(content)
                                        .modelName(actualModelName)
                                        .metadata(metadata)
                                        .status("SENT")
                                        .messageType("TEXT")
                                        .createdAt(LocalDateTime.now())
                                        .build();

                                return messageRepository.save(userMessage)
                                        .flatMap(savedUserMessage -> {
                                            session.setMessageCount(session.getMessageCount() + 1);

                                            String decryptedApiKey;
                                            try {
                                                decryptedApiKey = encryptor.decrypt(config.getApiKey());
                                            } catch (Exception e) {
                                                log.error("发送消息前解密 API Key 失败: userId={}, sessionId={}, configId={}", userId, sessionId, config.getId(), e);
                                                return Mono.error(new RuntimeException("处理请求失败，无法访问模型凭证。"));
                                            }

                                            AIRequest aiRequest = buildAIRequest(session, actualModelName, content, savedUserMessage.getId(), 20);

                                            log.debug("准备调用AI服务: userId={}, sessionId={}, model={}, provider={}, configId={}",
                                                    userId, sessionId, actualModelName, config.getProvider(), config.getId());

                                            return aiService.generateContent(aiRequest, decryptedApiKey, config.getApiEndpoint())
                                                    .flatMap(aiResponse -> {
                                                        AIChatMessage aiMessage = AIChatMessage.builder()
                                                                .sessionId(sessionId)
                                                                .userId(userId)
                                                                .role("assistant")
                                                                .content(aiResponse.getContent())
                                                                .modelName(actualModelName)
                                                                .metadata(aiResponse.getMetadata() != null ? aiResponse.getMetadata() : Map.of())
                                                                .status("DELIVERED")
                                                                .messageType("TEXT")
                                                                .parentMessageId(savedUserMessage.getId())
                                                                .tokenCount(aiResponse.getMetadata() != null ? (Integer) aiResponse.getMetadata().getOrDefault("tokenCount", 0) : 0)
                                                                .createdAt(LocalDateTime.now())
                                                                .build();

                                                        return messageRepository.save(aiMessage)
                                                                .flatMap(savedAiMessage -> {
                                                                    session.setLastMessageAt(LocalDateTime.now());
                                                                    session.setMessageCount(session.getMessageCount() + 1);
                                                                    return sessionRepository.save(session)
                                                                            .thenReturn(savedAiMessage);
                                                                });
                                                    });
                                        });
                            })
                            .onErrorResume(e -> {
                                log.error("处理消息时出错 (获取配置/解密/调用AI): userId={}, sessionId={}, error={}", userId, sessionId, e.getMessage(), e);
                                return Mono.error(new RuntimeException("获取AI响应失败: " + e.getMessage(), e));
                            });
                });
    }

    @Override
    public Flux<AIChatMessage> streamMessage(String userId, String sessionId, String content, Map<String, Object> metadata) {
        return getSession(userId, sessionId)
                .switchIfEmpty(Mono.error(new RuntimeException("会话不存在或无权访问: " + sessionId)))
                .flatMapMany(session -> {
                    return userAIModelConfigService.getConfigurationById(userId, session.getSelectedModelConfigId())
                            .switchIfEmpty(Mono.error(new RuntimeException("无法找到或访问会话关联的模型配置: " + session.getSelectedModelConfigId())))
                            .flatMapMany(config -> {
                                if (!config.getIsValidated()) {
                                    log.error("流式消息失败，会话 {} 使用的模型配置 {} 未验证", sessionId, config.getId());
                                    return Flux.error(new RuntimeException("当前会话使用的模型配置无效或未验证。"));
                                }

                                String actualModelName = config.getModelName();
                                log.debug("流式处理: 会话 {} 使用模型配置 ID: {}, 实际模型名称: {}", sessionId, config.getId(), actualModelName);

                                AIChatMessage userMessage = AIChatMessage.builder()
                                        .sessionId(sessionId)
                                        .userId(userId)
                                        .role("user")
                                        .content(content)
                                        .modelName(actualModelName)
                                        .metadata(metadata)
                                        .status("SENT")
                                        .messageType("TEXT")
                                        .createdAt(LocalDateTime.now())
                                        .build();

                                return messageRepository.save(userMessage)
                                        .flatMapMany(savedUserMessage -> {
                                            session.setMessageCount(session.getMessageCount() + 1);

                                            String decryptedApiKey;
                                            try {
                                                decryptedApiKey = encryptor.decrypt(config.getApiKey());
                                            } catch (Exception e) {
                                                log.error("流式消息前解密 API Key 失败: userId={}, sessionId={}, configId={}", userId, sessionId, config.getId(), e);
                                                return Flux.error(new RuntimeException("处理请求失败，无法访问模型凭证。"));
                                            }

                                            AIRequest aiRequest = buildAIRequest(session, actualModelName, content, savedUserMessage.getId(), 20);

                                            log.debug("准备调用流式AI服务: userId={}, sessionId={}, model={}, provider={}, configId={}",
                                                    userId, sessionId, actualModelName, config.getProvider(), config.getId());

                                            Flux<String> stream = aiService.generateContentStream(aiRequest, decryptedApiKey, config.getApiEndpoint());

                                            StringBuilder responseBuilder = new StringBuilder();
                                            Mono<AIChatMessage> saveFullMessageMono = Mono.defer(() -> {
                                                String fullContent = responseBuilder.toString();
                                                if (StringUtils.hasText(fullContent)) {
                                                    AIChatMessage aiMessage = AIChatMessage.builder()
                                                            .sessionId(sessionId)
                                                            .userId(userId)
                                                            .role("assistant")
                                                            .content(fullContent)
                                                            .modelName(actualModelName)
                                                            .metadata(Map.of("streamed", true))
                                                            .status("DELIVERED")
                                                            .messageType("TEXT")
                                                            .parentMessageId(savedUserMessage.getId())
                                                            .tokenCount(0)
                                                            .createdAt(LocalDateTime.now())
                                                            .build();
                                                    log.debug("流式传输完成，保存完整AI消息: sessionId={}, length={}", sessionId, fullContent.length());
                                                    return messageRepository.save(aiMessage)
                                                            .flatMap(savedMsg -> {
                                                                session.setLastMessageAt(LocalDateTime.now());
                                                                session.setMessageCount(session.getMessageCount() + 1);
                                                                return sessionRepository.save(session).thenReturn(savedMsg);
                                                            });
                                                } else {
                                                    log.warn("流式响应为空，不保存AI消息: sessionId={}", sessionId);
                                                    session.setLastMessageAt(LocalDateTime.now());
                                                    return sessionRepository.save(session).then(Mono.empty());
                                                }
                                            });

                                            return stream
                                                    .doOnNext(responseBuilder::append)
                                                    .map(chunk -> AIChatMessage.builder()
                                                    .sessionId(sessionId)
                                                    .role("assistant")
                                                    .content(chunk)
                                                    .modelName(actualModelName)
                                                    .messageType("STREAM_CHUNK")
                                                    .status("STREAMING")
                                                    .createdAt(LocalDateTime.now())
                                                    .build())
                                                    .doOnComplete(() -> log.info("流式传输完成: sessionId={}", sessionId))
                                                    .doOnError(e -> log.error("流式传输过程中出错: sessionId={}, error={}", sessionId, e.getMessage()))
                                                    .concatWith(saveFullMessageMono.onErrorResume(e -> {
                                                        log.error("保存完整流式消息时出错: sessionId={}", sessionId, e);
                                                        return Mono.empty();
                                                    }).flux());
                                        });
                            });
                });
    }

    private AIRequest buildAIRequest(AIChatSession session, String modelName, String newContent, String userMessageId, int historyLimit) {
        return getRecentMessages(session.getSessionId(), userMessageId, historyLimit)
                .collectList()
                .map(history -> {
                    List<AIRequest.Message> messages = new ArrayList<>();
                    if (history != null) {
                        history.stream()
                                .map(msg -> new AIRequest.Message(msg.getRole(), msg.getContent()))
                                .forEach(messages::add);
                    }
                    messages.add(new AIRequest.Message("user", newContent));

                    AIRequest request = new AIRequest();
                    request.setUserId(session.getUserId());
                    request.setModel(modelName);
                    request.setMessages(messages);
                    Map<String, Object> params = session.getMetadata() != null ? session.getMetadata() : Map.of();
                    request.setTemperature((Double) params.getOrDefault("temperature", 0.7));
                    request.setMaxTokens((Integer) params.getOrDefault("maxTokens", 1024));
                    request.setParameters(params);

                    log.debug("Built AIRequest for model: {}, messages count: {}", modelName, messages.size());
                    return request;
                }).block();
    }

    private Flux<AIChatMessage> getRecentMessages(String sessionId, String excludeMessageId, int limit) {
        return messageRepository.findBySessionIdOrderByCreatedAtDesc(sessionId, limit + 1)
                .filter(msg -> !msg.getId().equals(excludeMessageId))
                .take(limit)
                .collectList()
                .flatMapMany(list -> Flux.fromIterable(list).sort((m1, m2) -> m1.getCreatedAt().compareTo(m2.getCreatedAt())));
    }

    @Override
    public Flux<AIChatMessage> getSessionMessages(String userId, String sessionId, int limit) {
        return sessionRepository.findByUserIdAndSessionId(userId, sessionId)
                .switchIfEmpty(Mono.error(new SecurityException("无权访问此会话的消息")))
                .flatMapMany(session -> messageRepository.findBySessionIdOrderByCreatedAtDesc(sessionId, limit));
    }

    @Override
    public Mono<AIChatMessage> getMessage(String userId, String messageId) {
        return messageRepository.findById(messageId)
                .flatMap(message -> {
                    return sessionRepository.findByUserIdAndSessionId(userId, message.getSessionId())
                            .switchIfEmpty(Mono.error(new SecurityException("无权访问此消息")))
                            .thenReturn(message);
                });
    }

    @Override
    public Mono<Void> deleteMessage(String userId, String messageId) {
        return messageRepository.findById(messageId)
                .switchIfEmpty(Mono.error(new RuntimeException("消息不存在: " + messageId)))
                .flatMap(message -> sessionRepository.findByUserIdAndSessionId(userId, message.getSessionId())
                .switchIfEmpty(Mono.error(new SecurityException("无权删除此消息")))
                .then(messageRepository.deleteById(messageId)));
    }

    @Override
    public Mono<Long> countUserSessions(String userId) {
        return sessionRepository.countByUserId(userId);
    }

    @Override
    public Mono<Long> countSessionMessages(String sessionId) {
        return messageRepository.countBySessionId(sessionId);
    }
}
