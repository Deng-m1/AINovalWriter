package com.ainovel.server.repository;

import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.ReactiveMongoRepository;

import com.ainovel.server.domain.model.AIChatSession;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

public interface AIChatSessionRepository extends ReactiveMongoRepository<AIChatSession, String> {

    Mono<AIChatSession> findByUserIdAndSessionId(String userId, String sessionId);

    Flux<AIChatSession> findByUserId(String userId, Pageable pageable);

    Mono<Void> deleteByUserIdAndSessionId(String userId, String sessionId);

    Mono<Long> countByUserId(String userId);
}
