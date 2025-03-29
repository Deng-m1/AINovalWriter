package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Objects;


import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import com.ainovel.server.domain.model.UserAIModelConfig;
import com.ainovel.server.repository.UserAIModelConfigRepository;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.UserAIModelConfigService;
import org.jasypt.encryption.StringEncryptor; // Add Jasypt import

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Slf4j
@Service
public class UserAIModelConfigServiceImpl implements UserAIModelConfigService {

    private final UserAIModelConfigRepository configRepository;
    private final AIService aiService;
    private final StringEncryptor encryptor;

    @Autowired
    public UserAIModelConfigServiceImpl(UserAIModelConfigRepository configRepository,
                                        @Qualifier("AIServiceImpl") AIService aiService,
            StringEncryptor encryptor) {
        this.configRepository = configRepository;
        this.aiService = aiService;
        this.encryptor = encryptor;
    }

    @Override
    public Mono<UserAIModelConfig> addConfiguration(String userId, String provider, String modelName, String alias, String apiKey, String apiEndpoint) {
        if (!StringUtils.hasText(userId) || !StringUtils.hasText(provider) || !StringUtils.hasText(modelName) || !StringUtils.hasText(apiKey)) {
            return Mono.error(new IllegalArgumentException("用户ID、提供商、模型名称和API Key不能为空"));
        }

        String lowerCaseProvider = provider.toLowerCase();
        String encryptedApiKey;
        try {
            encryptedApiKey = encryptor.encrypt(apiKey);
        } catch (Exception e) {
            log.error("加密 API Key 时出错 for user {}", userId, e);
            return Mono.error(new RuntimeException("API Key 加密失败"));
        }

        return aiService.getModelsForProvider(lowerCaseProvider)
                .collectList()
                .flatMap(supportedModels -> {
                    if (!supportedModels.contains(modelName)) {
                        return Mono.error(new IllegalArgumentException("提供商 '" + lowerCaseProvider + "' 不支持模型 '" + modelName + "'"));
                    }

                    UserAIModelConfig newConfig = UserAIModelConfig.builder()
                            .userId(userId)
                            .provider(lowerCaseProvider)
                            .modelName(modelName)
                            .alias(StringUtils.hasText(alias) ? alias : modelName)
                            .apiKey(encryptedApiKey)
                            .apiEndpoint(apiEndpoint)
                            .isValidated(false)
                            .isDefault(false)
                            .createdAt(LocalDateTime.now())
                            .updatedAt(LocalDateTime.now())
                            .build();

                    return configRepository.save(newConfig)
                            .flatMap(this::performValidation)
                            .onErrorResume(e -> {
                                log.error("添加配置失败: userId={}, provider={}, modelName={}", userId, lowerCaseProvider, modelName, e);
                                if (e.getMessage() != null && e.getMessage().contains("duplicate key error")) {
                                    return Mono.error(new RuntimeException("添加配置失败，已存在相同的模型配置。"));
                                }
                                return Mono.error(new RuntimeException("添加配置时发生数据库错误。", e));
                            });
                })
                .onErrorResume(IllegalArgumentException.class, e -> {
                    log.warn("添加配置检查失败: {}", e.getMessage());
                    return Mono.error(e);
                });
    }

    @Override
    public Mono<UserAIModelConfig> updateConfiguration(String userId, String configId, Map<String, Object> updates) {
        return configRepository.findByUserIdAndId(userId, configId)
                .switchIfEmpty(Mono.error(new RuntimeException("配置不存在或无权访问")))
                .flatMap(config -> {
                    boolean needsRevalidation = false;
                    boolean apiKeyUpdated = false;
                    String newApiKey = null;

                    if (updates.containsKey("alias") && StringUtils.hasText((String) updates.get("alias"))) {
                        config.setAlias((String) updates.get("alias"));
                    }
                    if (updates.containsKey("apiKey") && StringUtils.hasText((String) updates.get("apiKey"))) {
                        newApiKey = (String) updates.get("apiKey");
                        needsRevalidation = true;
                        apiKeyUpdated = true;
                    }
                    if (updates.containsKey("apiEndpoint")) {
                        String newEndpoint = (String) updates.get("apiEndpoint");
                        if (!Objects.equals(config.getApiEndpoint(), newEndpoint)) {
                            config.setApiEndpoint(newEndpoint);
                            needsRevalidation = true;
                        }
                    }
                    if (updates.containsKey("isDefault")) {
                        log.warn("尝试通过 updateConfiguration 修改 isDefault 状态，已忽略。请使用 setDefaultConfiguration。 userId={}, configId={}", userId, configId);
                    }

                    config.setUpdatedAt(LocalDateTime.now());

                    if (apiKeyUpdated) {
                        try {
                            config.setApiKey(encryptor.encrypt(newApiKey));
                        } catch (Exception e) {
                            log.error("更新配置时加密 API Key 失败: userId={}, configId={}", userId, configId, e);
                            return Mono.error(new RuntimeException("API Key 加密失败"));
                        }
                    }

                    if (needsRevalidation) {
                        config.setIsValidated(false);
                        config.setValidationError(null);
                        return configRepository.save(config).flatMap(this::performValidation);
                    } else {
                        return configRepository.save(config);
                    }
                });
    }

    @Override
    public Mono<Void> deleteConfiguration(String userId, String configId) {
        return configRepository.deleteByUserIdAndId(userId, configId);
    }

    @Override
    public Mono<UserAIModelConfig> getConfigurationById(String userId, String configId) {
        return configRepository.findByUserIdAndId(userId, configId);
    }

    @Override
    public Flux<UserAIModelConfig> listConfigurations(String userId) {
        return configRepository.findByUserId(userId);
    }

    @Override
    public Flux<UserAIModelConfig> listValidatedConfigurations(String userId) {
        return configRepository.findByUserIdAndIsValidated(userId, true);
    }

    @Override
    public Mono<UserAIModelConfig> validateConfiguration(String userId, String configId) {
        return configRepository.findByUserIdAndId(userId, configId)
                .switchIfEmpty(Mono.error(new RuntimeException("配置不存在或无权访问")))
                .flatMap(this::performValidation);
    }

    @Override
    public Mono<UserAIModelConfig> getValidatedConfig(String userId, String provider, String modelName) {
        return configRepository.findByUserIdAndProviderAndModelNameAndIsValidated(userId, provider.toLowerCase(), modelName, true)
                .switchIfEmpty(Mono.error(new RuntimeException("未找到用户 '" + userId + "' 的模型 '" + provider + "/" + modelName + "' 的已验证配置")));
    }

    @Override
    @Transactional
    public Mono<UserAIModelConfig> setDefaultConfiguration(String userId, String configId) {
        return configRepository.findByUserIdAndId(userId, configId)
                .switchIfEmpty(Mono.error(new RuntimeException("配置不存在或无权访问")))
                .flatMap(configToSetDefault -> {
                    if (!configToSetDefault.getIsValidated()) {
                        return Mono.error(new IllegalArgumentException("无法将未验证的配置设为默认"));
                    }
                    if (configToSetDefault.isDefault()) {
                        return Mono.just(configToSetDefault);
                    }

                    return configRepository.findByUserIdAndIsDefaultIsTrue(userId)
                            .flatMap(currentDefault -> {
                                if (!currentDefault.getId().equals(configId)) {
                                    currentDefault.setDefault(false);
                                    currentDefault.setUpdatedAt(LocalDateTime.now());
                                    return configRepository.save(currentDefault);
                                }
                                return Mono.empty();
                            })
                            .thenMany(configRepository.findByUserIdAndIsDefaultIsFalse(userId))
                            .filter(config -> !config.getId().equals(configId))
                            .flatMap(config -> {
                                if (config.isDefault()) {
                                    config.setDefault(false);
                                    config.setUpdatedAt(LocalDateTime.now());
                                    return configRepository.save(config);
                                }
                                return Mono.empty();
                            })
                            .then()
                            .then(Mono.fromCallable(() -> {
                                configToSetDefault.setDefault(true);
                                configToSetDefault.setUpdatedAt(LocalDateTime.now());
                                return configToSetDefault;
                            }))
                            .flatMap(configRepository::save);
                });
    }

    @Override
    public Mono<UserAIModelConfig> getValidatedDefaultConfiguration(String userId) {
        return configRepository.findByUserIdAndIsDefaultIsTrue(userId)
                .filter(config -> config.getIsValidated());
    }

    @Override
    public Mono<UserAIModelConfig> getFirstValidatedConfiguration(String userId) {
        return configRepository.findByUserIdAndIsValidated(userId, true)
                .next();
    }

    private Mono<UserAIModelConfig> performValidation(UserAIModelConfig config) {
        String decryptedApiKey;
        try {
            decryptedApiKey = encryptor.decrypt(config.getApiKey());
        } catch (Exception e) {
            log.error("验证前解密 API Key 失败: userId={}, configId={}, provider={}, model={}", config.getUserId(), config.getId(), config.getProvider(), config.getModelName(), e);
            config.setIsValidated(false);
            config.setValidationError("API Key 解密失败，无法验证");
            config.setUpdatedAt(LocalDateTime.now());
            return configRepository.save(config);
        }

        log.info("开始验证配置 (使用解密后Key): userId={}, provider={}, model={}", config.getUserId(), config.getProvider(), config.getModelName());
        return aiService.validateApiKey(config.getUserId(), config.getProvider(), config.getModelName(), decryptedApiKey, config.getApiEndpoint())
                .flatMap(isValid -> {
                    log.info("配置验证结果: userId={}, provider={}, model={}, isValid={}", config.getUserId(), config.getProvider(), config.getModelName(), isValid);
                    config.setIsValidated(isValid);
                    config.setValidationError(isValid ? null : "API Key 验证失败");
                    config.setUpdatedAt(LocalDateTime.now());
                    return configRepository.save(config);
                })
                .onErrorResume(e -> {
                    log.error("验证配置时 AI Service 调用出错: userId={}, provider={}, model={}, error={}", config.getUserId(), config.getProvider(), config.getModelName(), e.getMessage());
                    config.setIsValidated(false);
                    config.setValidationError("验证过程中发生错误: " + e.getMessage());
                    config.setUpdatedAt(LocalDateTime.now());
                    return configRepository.save(config);
                });
    }
}
