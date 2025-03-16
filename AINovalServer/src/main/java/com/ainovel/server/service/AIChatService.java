package com.ainovel.server.service;

import java.util.Map;

import com.ainovel.server.domain.model.AIChatMessage;
import com.ainovel.server.domain.model.AIChatSession;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

public interface AIChatService {

    // 会话管理
    Mono<AIChatSession> createSession(String userId, String novelId, String modelName, Map<String, Object> metadata);

    Mono<AIChatSession> getSession(String userId, String sessionId);

    Flux<AIChatSession> listUserSessions(String userId, int page, int size);

    Mono<AIChatSession> updateSession(String userId, String sessionId, Map<String, Object> updates);

    Mono<Void> deleteSession(String userId, String sessionId);

    // 消息管理
    Mono<AIChatMessage> sendMessage(String userId, String sessionId, String content, Map<String, Object> metadata);

    Flux<AIChatMessage> streamMessage(String userId, String sessionId, String content, Map<String, Object> metadata);

    Flux<AIChatMessage> getSessionMessages(String userId, String sessionId, int limit);

    Mono<AIChatMessage> getMessage(String userId, String messageId);

    Mono<Void> deleteMessage(String userId, String messageId);

    // 统计
    Mono<Long> countUserSessions(String userId);

    Mono<Long> countSessionMessages(String sessionId);
}
