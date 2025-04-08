package com.ainovel.server.repository;

import org.springframework.data.mongodb.repository.ReactiveMongoRepository;
import org.springframework.stereotype.Repository;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.UserPromptTemplate;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户提示词模板仓库
 * 提供对用户提示词模板的存储和查询操作
 */
@Repository
public interface UserPromptTemplateRepository extends ReactiveMongoRepository<UserPromptTemplate, String> {
    
    /**
     * 根据用户ID和功能类型查找用户提示词模板
     *
     * @param userId 用户ID
     * @param featureType 功能类型
     * @return 用户提示词模板
     */
    Mono<UserPromptTemplate> findByUserIdAndFeatureType(String userId, AIFeatureType featureType);
    
    /**
     * 根据用户ID查找所有用户提示词模板
     *
     * @param userId 用户ID
     * @return 用户提示词模板流
     */
    Flux<UserPromptTemplate> findByUserId(String userId);
    
    /**
     * 根据用户ID和功能类型删除用户提示词模板
     *
     * @param userId 用户ID
     * @param featureType 功能类型
     * @return 操作结果
     */
    Mono<Void> deleteByUserIdAndFeatureType(String userId, AIFeatureType featureType);
} 