package com.ainovel.server.web.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.UserAIModelConfig;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.UserAIModelConfigService;
import com.ainovel.server.web.dto.CreateUserAIModelConfigRequest;
import com.ainovel.server.web.dto.ListUserConfigsRequest;
import com.ainovel.server.web.dto.ProviderModelsRequest;
import com.ainovel.server.web.dto.UpdateUserAIModelConfigRequest;
import com.ainovel.server.web.dto.UserAIModelConfigResponse;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Slf4j
@RestController
@RequestMapping("/api/v1/user-ai-configs")
@Tag(name = "用户AI模型配置管理", description = "管理用户个人配置的AI模型及其凭证 (所有操作使用POST)")
public class UserAIModelConfigController {

    private final UserAIModelConfigService configService;
    private final AIService aiService;

    @Autowired
    public UserAIModelConfigController(UserAIModelConfigService configService, AIService aiService) {
        this.configService = configService;
        this.aiService = aiService;
    }

    @PostMapping("/providers/list")
    @Operation(summary = "获取系统支持的AI提供商列表")
    public Mono<List<String>> listAvailableProviders() {
        return aiService.getAvailableProviders().collectList();
    }

    @PostMapping("/providers/models/list")
    @Operation(summary = "获取指定AI提供商支持的模型列表")
    public Mono<List<String>> listModelsForProvider(
            @Valid @RequestBody ProviderModelsRequest request) {
        return aiService.getModelsForProvider(request.provider()).collectList();
    }

    @PostMapping("/users/{userId}/create")
    @Operation(summary = "添加新的用户AI模型配置")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<UserAIModelConfigResponse> addConfiguration(
            @Parameter(description = "用户ID", required = true) @PathVariable String userId,
            @Valid @RequestBody CreateUserAIModelConfigRequest request) {
        log.debug("Request to add config for user {}: {}", userId, request);
        return configService.addConfiguration(userId, request.provider(), request.modelName(), request.alias(), request.apiKey(), request.apiEndpoint())
                .map(UserAIModelConfigResponse::fromEntity)
                .doOnError(e -> log.error("Error adding config for user {}: {}", userId, e.getMessage()));
    }

    @PostMapping("/users/{userId}/list")
    @Operation(summary = "列出用户所有的AI模型配置")
    public Mono<List<UserAIModelConfigResponse>> listConfigurations(
            @Parameter(description = "用户ID", required = true) @PathVariable String userId,
            @RequestBody(required = false) ListUserConfigsRequest request) {
        boolean validatedOnly = request != null && request.validatedOnly() != null && request.validatedOnly();
        log.debug("Request to list configs for user {}: validatedOnly={}", userId, validatedOnly);
        Flux<UserAIModelConfig> configsFlux = validatedOnly
                ? configService.listValidatedConfigurations(userId)
                : configService.listConfigurations(userId);
        return configsFlux.map(UserAIModelConfigResponse::fromEntity).collectList();
    }

    @PostMapping("/users/{userId}/get/{configId}")
    @Operation(summary = "获取指定ID的用户AI模型配置")
    public Mono<ResponseEntity<UserAIModelConfigResponse>> getConfigurationById(
            @Parameter(description = "用户ID", required = true) @PathVariable String userId,
            @Parameter(description = "配置ID", required = true) @PathVariable String configId) {
        log.debug("Request to get config by ID for user {}: configId={}", userId, configId);
        return configService.getConfigurationById(userId, configId)
                .map(UserAIModelConfigResponse::fromEntity)
                .map(ResponseEntity::ok)
                .defaultIfEmpty(ResponseEntity.notFound().build());
    }

    @PostMapping("/users/{userId}/update/{configId}")
    @Operation(summary = "更新指定ID的用户AI模型配置")
    public Mono<ResponseEntity<UserAIModelConfigResponse>> updateConfiguration(
            @Parameter(description = "用户ID", required = true) @PathVariable String userId,
            @Parameter(description = "配置ID", required = true) @PathVariable String configId,
            @Valid @RequestBody UpdateUserAIModelConfigRequest request) {
        log.debug("Request to update config for user {}: configId={}, updates={}", userId, configId, request);
        Map<String, Object> updates = new java.util.HashMap<>();
        if (request.alias() != null) {
            updates.put("alias", request.alias());
        }
        if (request.apiKey() != null) {
            updates.put("apiKey", request.apiKey());
        }
        if (request.apiEndpoint() != null) {
            updates.put("apiEndpoint", request.apiEndpoint());
        }
        if (updates.isEmpty()) {
            log.warn("Update request for user {} config {} has no fields to update.", userId, configId);
            return Mono.just(ResponseEntity.badRequest().build());
        }

        return configService.updateConfiguration(userId, configId, updates)
                .map(UserAIModelConfigResponse::fromEntity)
                .map(ResponseEntity::ok)
                .onErrorResume(e -> {
                    log.error("更新配置失败: userId={}, configId={}, error={}", userId, configId, e.getMessage(), e);
                    if (e instanceof IllegalArgumentException) {
                        return Mono.just(ResponseEntity.badRequest().build());
                    }
                    if (e instanceof RuntimeException && e.getMessage() != null && e.getMessage().contains("配置不存在")) {
                        return Mono.just(ResponseEntity.notFound().build());
                    }
                    if (e instanceof RuntimeException && e.getMessage() != null && e.getMessage().contains("加密失败")) {
                        return Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).<UserAIModelConfigResponse>build());
                    }
                    return Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).<UserAIModelConfigResponse>build());
                });
    }

    @PostMapping("/users/{userId}/delete/{configId}")
    @Operation(summary = "删除指定ID的用户AI模型配置")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteConfiguration(
            @Parameter(description = "用户ID", required = true) @PathVariable String userId,
            @Parameter(description = "配置ID", required = true) @PathVariable String configId) {
        log.debug("Request to delete config for user {}: configId={}", userId, configId);
        return configService.deleteConfiguration(userId, configId);
    }

    @PostMapping("/users/{userId}/validate/{configId}")
    @Operation(summary = "手动触发指定配置的API Key验证")
    public Mono<ResponseEntity<UserAIModelConfigResponse>> validateConfiguration(
            @Parameter(description = "用户ID", required = true) @PathVariable String userId,
            @Parameter(description = "配置ID", required = true) @PathVariable String configId) {
        log.debug("Request to validate config for user {}: configId={}", userId, configId);
        return configService.validateConfiguration(userId, configId)
                .map(UserAIModelConfigResponse::fromEntity)
                .map(ResponseEntity::ok)
                .defaultIfEmpty(ResponseEntity.notFound().build());
    }

    @PostMapping("/users/{userId}/set-default/{configId}")
    @Operation(summary = "设置指定配置为用户的默认模型")
    public Mono<ResponseEntity<UserAIModelConfigResponse>> setDefaultConfiguration(
            @Parameter(description = "用户ID", required = true) @PathVariable String userId,
            @Parameter(description = "配置ID", required = true) @PathVariable String configId) {
        log.debug("Request to set default config for user {}: configId={}", userId, configId);
        return configService.setDefaultConfiguration(userId, configId)
                .map(UserAIModelConfigResponse::fromEntity)
                .map(ResponseEntity::ok)
                .onErrorResume(IllegalArgumentException.class, e -> {
                    log.warn("设置默认配置失败 (参数错误): userId={}, configId={}, error={}", userId, configId, e.getMessage());
                    return Mono.just(ResponseEntity.badRequest().build());
                })
                .onErrorResume(RuntimeException.class, e -> {
                    log.error("设置默认配置失败 (运行时错误): userId={}, configId={}, error={}", userId, configId, e.getMessage(), e);
                    if (e.getMessage() != null && e.getMessage().contains("配置不存在")) {
                        return Mono.just(ResponseEntity.notFound().build());
                    }
                    return Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build());
                });
    }
}
