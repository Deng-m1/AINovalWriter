package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIChatMessage;
import com.ainovel.server.domain.model.AIChatSession;
import com.ainovel.server.repository.AIChatMessageRepository;
import com.ainovel.server.repository.AIChatSessionRepository;
import com.ainovel.server.service.AIChatService;
import com.ainovel.server.service.NovelAIService;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Slf4j
@Service
public class AIChatServiceImpl implements AIChatService {

    private final AIChatSessionRepository sessionRepository;
    private final AIChatMessageRepository messageRepository;
    private final NovelAIService novelAIService;

    @Autowired
    public AIChatServiceImpl(AIChatSessionRepository sessionRepository,
            AIChatMessageRepository messageRepository,
            NovelAIService novelAIService) {
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.novelAIService = novelAIService;
    }

    @Override
    public Mono<AIChatSession> createSession(String userId, String novelId, String modelName, Map<String, Object> metadata) {
        String sessionId = UUID.randomUUID().toString();
        AIChatSession session = AIChatSession.builder()
                .sessionId(sessionId)
                .userId(userId)
                .novelId(novelId)
                .modelName(modelName)
                .metadata(metadata)
                .status("ACTIVE")
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .messageCount(0)
                .build();

        return sessionRepository.save(session);
    }

    @Override
    public Mono<AIChatSession> getSession(String userId, String sessionId) {
        return sessionRepository.findByUserIdAndSessionId(userId, sessionId);
    }

    @Override
    public Flux<AIChatSession> listUserSessions(String userId, int page, int size) {
        return sessionRepository.findByUserId(userId,
                PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "lastMessageAt")));
    }

    @Override
    public Mono<AIChatSession> updateSession(String userId, String sessionId, Map<String, Object> updates) {
        return sessionRepository.findByUserIdAndSessionId(userId, sessionId)
                .flatMap(session -> {
                    if (updates.containsKey("title")) {
                        session.setTitle((String) updates.get("title"));
                    }
                    if (updates.containsKey("status")) {
                        session.setStatus((String) updates.get("status"));
                    }
                    if (updates.containsKey("metadata")) {
                        session.setMetadata((Map<String, Object>) updates.get("metadata"));
                    }
                    session.setUpdatedAt(LocalDateTime.now());
                    return sessionRepository.save(session);
                });
    }

    @Override
    public Mono<Void> deleteSession(String userId, String sessionId) {
        return sessionRepository.deleteByUserIdAndSessionId(userId, sessionId)
                .then(messageRepository.deleteBySessionId(sessionId));
    }

    @Override
    public Mono<AIChatMessage> sendMessage(String userId, String sessionId, String content, Map<String, Object> metadata) {
        return getSession(userId, sessionId)
                .flatMap(session -> {
                    // 保存用户消息
                    AIChatMessage userMessage = AIChatMessage.builder()
                            .sessionId(sessionId)
                            .userId(userId)
                            .role("user")
                            .content(content)
                            .novelId(session.getNovelId())
                            .modelName(session.getModelName())
                            .metadata(metadata)
                            .status("SENT")
                            .messageType("TEXT")
                            .createdAt(LocalDateTime.now())
                            .build();

                    return messageRepository.save(userMessage)
                            .flatMap(savedMessage -> {
                                // 更新会话最后消息时间和消息计数
                                session.setLastMessageAt(LocalDateTime.now());
                                session.setMessageCount(session.getMessageCount() + 1);
                                return sessionRepository.save(session)
                                        .thenReturn(savedMessage);
                            })
                            .flatMap(savedMessage -> {
                                // 调用AI服务获取响应
                                return novelAIService.generateChatResponse(userId, sessionId, content, metadata)
                                        .flatMap(aiResponse -> {
                                            // 保存AI响应消息
                                            AIChatMessage aiMessage = AIChatMessage.builder()
                                                    .sessionId(sessionId)
                                                    .userId(userId)
                                                    .role("assistant")
                                                    .content(aiResponse.getContent())
                                                    .novelId(session.getNovelId())
                                                    .modelName(session.getModelName())
                                                    .metadata(aiResponse.getMetadata() != null ? aiResponse.getMetadata() : Map.of())
                                                    .status("DELIVERED")
                                                    .messageType("TEXT")
                                                    .parentMessageId(savedMessage.getId())
                                                    .tokenCount(aiResponse.getMetadata() != null ? (Integer) aiResponse.getMetadata().getOrDefault("tokenCount", 0) : 0)
                                                    .createdAt(LocalDateTime.now())
                                                    .build();

                                            return messageRepository.save(aiMessage)
                                                    .flatMap(savedAiMessage -> {
                                                        // 再次更新会话
                                                        session.setLastMessageAt(LocalDateTime.now());
                                                        session.setMessageCount(session.getMessageCount() + 1);
                                                        return sessionRepository.save(session)
                                                                .thenReturn(savedAiMessage);
                                                    });
                                        });
                            });
                });
    }

    @Override
    public Flux<AIChatMessage> streamMessage(String userId, String sessionId, String content, Map<String, Object> metadata) {
        return getSession(userId, sessionId)
                .flatMapMany(session -> {
                    // 保存用户消息
                    AIChatMessage userMessage = AIChatMessage.builder()
                            .sessionId(sessionId)
                            .userId(userId)
                            .role("user")
                            .content(content)
                            .novelId(session.getNovelId())
                            .modelName(session.getModelName())
                            .metadata(metadata)
                            .status("SENT")
                            .messageType("TEXT")
                            .createdAt(LocalDateTime.now())
                            .build();

                    return messageRepository.save(userMessage)
                            .flatMapMany(savedMessage -> {
                                // 更新会话
                                session.setLastMessageAt(LocalDateTime.now());
                                session.setMessageCount(session.getMessageCount() + 1);

                                return sessionRepository.save(session)
                                        .thenMany(
                                                // 调用流式AI服务
                                                novelAIService.generateChatResponseStream(userId, sessionId, content, metadata)
                                                        .collect(StringBuilder::new, StringBuilder::append)
                                                        .flatMapMany(fullResponse -> {
                                                            // 保存完整的AI响应
                                                            AIChatMessage aiMessage = AIChatMessage.builder()
                                                                    .sessionId(sessionId)
                                                                    .userId(userId)
                                                                    .role("assistant")
                                                                    .content(fullResponse.toString())
                                                                    .novelId(session.getNovelId())
                                                                    .modelName(session.getModelName())
                                                                    .metadata(Map.of("streamed", true))
                                                                    .status("DELIVERED")
                                                                    .messageType("TEXT")
                                                                    .parentMessageId(savedMessage.getId())
                                                                    .createdAt(LocalDateTime.now())
                                                                    .build();

                                                            return messageRepository.save(aiMessage)
                                                                    .thenMany(Flux.just(aiMessage));
                                                        })
                                        );
                            });
                });
    }

    @Override
    public Flux<AIChatMessage> getSessionMessages(String userId, String sessionId, int limit) {
        return messageRepository.findBySessionIdOrderByCreatedAtDesc(sessionId, limit);
    }

    @Override
    public Mono<AIChatMessage> getMessage(String userId, String messageId) {
        return messageRepository.findByIdAndUserId(messageId, userId);
    }

    @Override
    public Mono<Void> deleteMessage(String userId, String messageId) {
        return messageRepository.deleteByIdAndUserId(messageId, userId);
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
