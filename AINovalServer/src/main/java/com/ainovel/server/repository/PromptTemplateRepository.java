package com.ainovel.server.repository;

import org.springframework.data.mongodb.repository.ReactiveMongoRepository;
import org.springframework.stereotype.Repository;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.PromptTemplate;

import reactor.core.publisher.Flux;

/**
 * 提示词模板存储库接口
 */
@Repository
public interface PromptTemplateRepository extends ReactiveMongoRepository<PromptTemplate, String> {
    
    /**
     * 查询公共模板
     * 
     * @return 公共模板列表
     */
    Flux<PromptTemplate> findByIsPublicTrue();
    
    /**
     * 查询用户私有模板
     * 
     * @param authorId 作者ID
     * @return 用户私有模板列表
     */
    Flux<PromptTemplate> findByIsPublicFalseAndAuthorId(String authorId);
    
    /**
     * 查询用户收藏的模板
     * 
     * @param authorId 作者ID
     * @return 用户收藏的模板列表
     */
    Flux<PromptTemplate> findByIsPublicFalseAndAuthorIdAndIsFavoriteTrue(String authorId);
    
    /**
     * 查询指定功能类型的公共模板
     * 
     * @param featureType 功能类型
     * @return 指定功能类型的公共模板列表
     */
    Flux<PromptTemplate> findByIsPublicTrueAndFeatureType(AIFeatureType featureType);
    
    /**
     * 查询指定功能类型的用户私有模板
     * 
     * @param authorId 作者ID
     * @param featureType 功能类型
     * @return 指定功能类型的用户私有模板列表
     */
    Flux<PromptTemplate> findByIsPublicFalseAndAuthorIdAndFeatureType(String authorId, AIFeatureType featureType);
    
    /**
     * 查询指定功能类型的用户收藏模板
     * 
     * @param authorId 作者ID
     * @param featureType 功能类型
     * @return 指定功能类型的用户收藏模板列表
     */
    Flux<PromptTemplate> findByIsPublicFalseAndAuthorIdAndFeatureTypeAndIsFavoriteTrue(
            String authorId, AIFeatureType featureType);
} 