package com.ainovel.server.repository;

import org.springframework.data.mongodb.repository.ReactiveMongoRepository;

import com.ainovel.server.domain.model.AIChatMessage;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

public interface AIChatMessageRepository extends ReactiveMongoRepository<AIChatMessage, String> {

    Flux<AIChatMessage> findBySessionIdOrderByCreatedAtDesc(String sessionId, int limit);

    Mono<AIChatMessage> findByIdAndUserId(String id, String userId);

    Mono<Void> deleteByIdAndUserId(String id, String userId);

    Mono<Long> countBySessionId(String sessionId);

    Mono<Void> deleteBySessionId(String sessionId);
}
