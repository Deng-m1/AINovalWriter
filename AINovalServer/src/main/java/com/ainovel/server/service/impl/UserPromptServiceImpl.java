package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.UserPromptTemplate;
import com.ainovel.server.repository.UserPromptTemplateRepository;
import com.ainovel.server.service.UserPromptService;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户提示词服务实现类 负责管理用户自定义提示词
 */
@Slf4j
@Service
public class UserPromptServiceImpl implements UserPromptService {

    private final UserPromptTemplateRepository userPromptTemplateRepository;

    // 默认提示词模板
    private static final Map<AIFeatureType, String> DEFAULT_TEMPLATES = new HashMap<>();

    static {
        // 初始化默认提示词模板
        DEFAULT_TEMPLATES.put(AIFeatureType.SCENE_TO_SUMMARY,
                "请根据以下小说场景内容，生成一段简洁的摘要。\n场景内容:\n{input}\n参考信息:\n{context}");

        DEFAULT_TEMPLATES.put(AIFeatureType.SUMMARY_TO_SCENE,
                "请根据以下摘要/大纲，结合参考信息，生成一段详细的小说场景。\n摘要/大纲:\n{input}\n参考信息:\n{context}");
    }

    @Autowired
    public UserPromptServiceImpl(UserPromptTemplateRepository userPromptTemplateRepository) {
        this.userPromptTemplateRepository = userPromptTemplateRepository;
    }

    @Override
    @Cacheable(value = "userPrompts", key = "#userId + ':' + #featureType")
    public Mono<String> getPromptTemplate(String userId, AIFeatureType featureType) {
        log.info("获取用户提示词模板, userId: {}, featureType: {}", userId, featureType);

        return userPromptTemplateRepository.findByUserIdAndFeatureType(userId, featureType)
                .map(UserPromptTemplate::getPromptText)
                .switchIfEmpty(getDefaultPromptTemplate(featureType));
    }

    @Override
    public Flux<UserPromptTemplate> getUserCustomPrompts(String userId) {
        log.info("获取用户所有自定义提示词, userId: {}", userId);

        return userPromptTemplateRepository.findByUserId(userId);
    }

    @Override
    @CacheEvict(value = "userPrompts", key = "#userId + ':' + #featureType")
    public Mono<UserPromptTemplate> saveOrUpdateUserPrompt(String userId, AIFeatureType featureType, String promptText) {
        log.info("保存或更新用户提示词, userId: {}, featureType: {}", userId, featureType);

        return userPromptTemplateRepository.findByUserIdAndFeatureType(userId, featureType)
                .flatMap(existingTemplate -> {
                    existingTemplate.setPromptText(promptText);
                    existingTemplate.setUpdatedAt(LocalDateTime.now());
                    return userPromptTemplateRepository.save(existingTemplate);
                })
                .switchIfEmpty(Mono.defer(() -> {
                    UserPromptTemplate newTemplate = UserPromptTemplate.builder()
                            .userId(userId)
                            .featureType(featureType)
                            .promptText(promptText)
                            .createdAt(LocalDateTime.now())
                            .updatedAt(LocalDateTime.now())
                            .build();
                    return userPromptTemplateRepository.save(newTemplate);
                }));
    }

    @Override
    @CacheEvict(value = "userPrompts", key = "#userId + ':' + #featureType")
    public Mono<Void> deleteUserPrompt(String userId, AIFeatureType featureType) {
        log.info("删除用户提示词, userId: {}, featureType: {}", userId, featureType);

        return userPromptTemplateRepository.deleteByUserIdAndFeatureType(userId, featureType);
    }

    @Override
    @Cacheable(value = "defaultPrompts", key = "#featureType")
    public Mono<String> getDefaultPromptTemplate(AIFeatureType featureType) {
        log.info("获取默认提示词模板, featureType: {}", featureType);

        String defaultTemplate = DEFAULT_TEMPLATES.getOrDefault(featureType,
                "请根据提供的信息进行创作。\n内容:\n{input}\n参考信息:\n{context}");

        return Mono.just(defaultTemplate);
    }
}
