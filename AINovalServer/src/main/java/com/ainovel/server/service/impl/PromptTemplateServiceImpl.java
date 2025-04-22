package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.OptimizationResult;
import com.ainovel.server.domain.model.OptimizationSection;
import com.ainovel.server.domain.model.OptimizationStatistics;
import com.ainovel.server.domain.model.OptimizationStyle;
import com.ainovel.server.domain.model.PromptTemplate;
import com.ainovel.server.repository.PromptTemplateRepository;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.PromptTemplateService;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 提示词模板服务实现类
 * 提供提示词模板管理和优化的服务
 */
@Slf4j
@Service
public class PromptTemplateServiceImpl implements PromptTemplateService {

    private final PromptTemplateRepository promptTemplateRepository;
    private final ReactiveMongoTemplate mongoTemplate;
    private final AIService aiService;

    @Autowired
    public PromptTemplateServiceImpl(
            PromptTemplateRepository promptTemplateRepository,
            ReactiveMongoTemplate mongoTemplate,
            AIService aiService) {
        this.promptTemplateRepository = promptTemplateRepository;
        this.mongoTemplate = mongoTemplate;
        this.aiService = aiService;
    }

    @Override
    public Flux<PromptTemplate> getPromptTemplates(String userId, String type) {
        Query query = new Query();
        
        switch (type.toUpperCase()) {
            case "PUBLIC":
                query.addCriteria(Criteria.where("isPublic").is(true));
                break;
            case "PRIVATE":
                query.addCriteria(Criteria.where("isPublic").is(false).and("authorId").is(userId));
                break;
            case "FAVORITE":
                query.addCriteria(Criteria.where("isPublic").is(false)
                        .and("authorId").is(userId)
                        .and("isFavorite").is(true));
                break;
            case "ALL":
            default:
                query.addCriteria(new Criteria().orOperator(
                        Criteria.where("isPublic").is(true),
                        Criteria.where("authorId").is(userId)
                ));
                break;
        }
        
        return mongoTemplate.find(query, PromptTemplate.class);
    }

    @Override
    public Flux<PromptTemplate> getPromptTemplatesByFeatureType(String userId, AIFeatureType featureType, String type) {
        Query query = new Query();
        query.addCriteria(Criteria.where("featureType").is(featureType));
        
        switch (type.toUpperCase()) {
            case "PUBLIC":
                query.addCriteria(Criteria.where("isPublic").is(true));
                break;
            case "PRIVATE":
                query.addCriteria(Criteria.where("isPublic").is(false).and("authorId").is(userId));
                break;
            case "FAVORITE":
                query.addCriteria(Criteria.where("isPublic").is(false)
                        .and("authorId").is(userId)
                        .and("isFavorite").is(true));
                break;
            case "ALL":
            default:
                query.addCriteria(new Criteria().orOperator(
                        Criteria.where("isPublic").is(true),
                        Criteria.where("authorId").is(userId)
                ));
                break;
        }
        
        return mongoTemplate.find(query, PromptTemplate.class);
    }

    @Override
    public Mono<PromptTemplate> getPromptTemplateById(String userId, String templateId) {
        return promptTemplateRepository.findById(templateId)
                .switchIfEmpty(Mono.error(new IllegalArgumentException("提示词模板不存在: " + templateId)));
    }

    @Override
    public Mono<PromptTemplate> createPromptTemplate(String userId, String name, String content, AIFeatureType featureType) {
        LocalDateTime now = LocalDateTime.now();
        
        PromptTemplate template = PromptTemplate.builder()
                .id(UUID.randomUUID().toString())
                .name(name)
                .content(content)
                .featureType(featureType)
                .isPublic(false) // 默认为私有模板
                .authorId(userId)
                .sourceTemplateId(null)
                .isVerified(false)
                .isFavorite(false)
                .createdAt(now)
                .updatedAt(now)
                .build();
        
        return promptTemplateRepository.save(template);
    }

    @Override
    public Mono<PromptTemplate> updatePromptTemplate(String userId, String templateId, String name, String content) {
        return getPromptTemplateById(userId, templateId)
                .flatMap(template -> {
                    // 检查权限（只有私有模板且作者是当前用户才能更新）
                    if (template.isPublic() || !userId.equals(template.getAuthorId())) {
                        return Mono.error(new IllegalArgumentException("无权修改此模板"));
                    }
                    
                    Update update = new Update();
                    if (name != null && !name.isEmpty()) {
                        update.set("name", name);
                    }
                    if (content != null && !content.isEmpty()) {
                        update.set("content", content);
                    }
                    
                    update.set("updatedAt", LocalDateTime.now());
                    
                    return mongoTemplate.updateFirst(
                            Query.query(Criteria.where("_id").is(templateId)),
                            update,
                            PromptTemplate.class)
                            .then(getPromptTemplateById(userId, templateId));
                });
    }

    @Override
    public Mono<Void> deletePromptTemplate(String userId, String templateId) {
        return getPromptTemplateById(userId, templateId)
                .flatMap(template -> {
                    // 检查权限（只有私有模板且作者是当前用户才能删除）
                    if (template.isPublic() || !userId.equals(template.getAuthorId())) {
                        return Mono.error(new IllegalArgumentException("无权删除此模板"));
                    }
                    
                    return promptTemplateRepository.delete(template);
                });
    }

    @Override
    public Mono<PromptTemplate> copyPublicTemplate(String userId, String templateId) {
        return getPromptTemplateById(userId, templateId)
                .flatMap(template -> {
                    // 检查是否为公共模板
                    if (!template.isPublic()) {
                        return Mono.error(new IllegalArgumentException("只能复制公共模板"));
                    }
                    
                    LocalDateTime now = LocalDateTime.now();
                    String newName = template.getName() + " (复制)";
                    
                    PromptTemplate newTemplate = PromptTemplate.builder()
                            .id(UUID.randomUUID().toString())
                            .name(newName)
                            .content(template.getContent())
                            .featureType(template.getFeatureType())
                            .isPublic(false)
                            .authorId(userId)
                            .sourceTemplateId(template.getId())
                            .isVerified(false)
                            .isFavorite(false)
                            .createdAt(now)
                            .updatedAt(now)
                            .build();
                    
                    return promptTemplateRepository.save(newTemplate);
                });
    }

    @Override
    public Mono<PromptTemplate> toggleTemplateFavorite(String userId, String templateId) {
        return getPromptTemplateById(userId, templateId)
                .flatMap(template -> {
                    // 检查权限（只有私有模板且作者是当前用户才能收藏）
                    if (template.isPublic() || !userId.equals(template.getAuthorId())) {
                        return Mono.error(new IllegalArgumentException("无权收藏此模板"));
                    }
                    
                    Update update = new Update();
                    update.set("isFavorite", !template.isFavorite());
                    update.set("updatedAt", LocalDateTime.now());
                    
                    return mongoTemplate.updateFirst(
                            Query.query(Criteria.where("_id").is(templateId)),
                            update,
                            PromptTemplate.class)
                            .then(getPromptTemplateById(userId, templateId));
                });
    }

    @Override
    public Mono<OptimizationResult> optimizePromptTemplate(String userId, String templateId, String content,
            OptimizationStyle style, Double preserveRatio) {
        
        return getPromptTemplateById(userId, templateId)
                .flatMap(template -> {
                    // 检查权限（只有私有模板且作者是当前用户才能优化并保存）
                    if (template.isPublic() || !userId.equals(template.getAuthorId())) {
                        return Mono.error(new IllegalArgumentException("无权优化此模板"));
                    }
                    
                    // 调用AI服务优化提示词
                    return optimizePrompt(userId, content, style, preserveRatio)
                            .flatMap(result -> {
                                // 优化成功后更新模板内容
                                template.setContent(result.getOptimizedContent());
                                template.setUpdatedAt(LocalDateTime.now());
                                
                                return promptTemplateRepository.save(template)
                                        .thenReturn(result);
                            });
                });
    }

    @Override
    public Mono<OptimizationResult> optimizePrompt(String userId, String content, OptimizationStyle style,
            Double preserveRatio) {
        // 这里调用AI服务进行提示词优化，实际项目中应该调用具体的AI服务
        
        // 模拟优化结果
        return Mono.fromCallable(new Callable<OptimizationResult>() {
            @Override
            public OptimizationResult call() throws Exception {
                // 简单的模拟逻辑，实际实现中应当调用AIService
                String optimized = "优化后的内容: " + content;
                
                // 创建区块和统计
                List<OptimizationSection> sections = new ArrayList<>();
                sections.add(OptimizationSection.builder()
                        .title("优化区块1")
                        .content(optimized.substring(0, Math.min(50, optimized.length())))
                        .original(content.substring(0, Math.min(50, content.length())))
                        .type("modified")
                        .build());
                
                OptimizationStatistics stats = OptimizationStatistics.builder()
                        .originalTokens(content.length() / 4)
                        .optimizedTokens(optimized.length() / 4)
                        .originalLength(content.length())
                        .optimizedLength(optimized.length())
                        .efficiency(1.2)
                        .build();
                
                return OptimizationResult.builder()
                        .optimizedContent(optimized)
                        .sections(sections)
                        .statistics(stats)
                        .build();
            }
        });
    }

    @Override
    public Flux<OptimizationResult> optimizePromptTemplateStream(String userId, String templateId, String content,
            OptimizationStyle style, Double preserveRatio) {
        
        return getPromptTemplateById(userId, templateId)
                .flatMapMany(template -> {
                    // 检查权限（只有私有模板且作者是当前用户才能优化并保存）
                    if (template.isPublic() || !userId.equals(template.getAuthorId())) {
                        return Flux.error(new IllegalArgumentException("无权优化此模板"));
                    }
                    
                    // 调用流式优化
                    return optimizePromptStream(userId, content, style, preserveRatio)
                            .doOnNext(result -> {
                                // 对于最后一个结果，更新模板内容
                                template.setContent(result.getOptimizedContent());
                                template.setUpdatedAt(LocalDateTime.now());
                                
                                promptTemplateRepository.save(template).subscribe();
                            });
                });
    }

    @Override
    public Flux<OptimizationResult> optimizePromptStream(String userId, String content, OptimizationStyle style,
            Double preserveRatio) {
        // 模拟流式输出，实际项目中应调用AI服务提供的流式接口
        
        return Flux.fromIterable(Arrays.asList(
                createProgressOptimizationResult(content, 0.3),
                createProgressOptimizationResult(content, 0.6),
                createProgressOptimizationResult(content, 1.0)
        )).delayElements(java.time.Duration.ofMillis(500));
    }
    
    // 创建进度优化结果
    private OptimizationResult createProgressOptimizationResult(String content, double progress) {
        String optimized = String.format("优化完成 %.0f%%: ", progress * 100) + content;
        
        List<OptimizationSection> sections = new ArrayList<>();
        sections.add(OptimizationSection.builder()
                .title(String.format("进度 %.0f%%", progress * 100))
                .content(optimized.substring(0, Math.min(50, optimized.length())))
                .original(content.substring(0, Math.min(50, content.length())))
                .type("modified")
                .build());
        
        OptimizationStatistics stats = OptimizationStatistics.builder()
                .originalTokens(content.length() / 4)
                .optimizedTokens(optimized.length() / 4)
                .originalLength(content.length())
                .optimizedLength(optimized.length())
                .efficiency(1.0 + (0.2 * progress))
                .build();
        
        return OptimizationResult.builder()
                .optimizedContent(optimized)
                .sections(sections)
                .statistics(stats)
                .build();
    }
} 