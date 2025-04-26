package com.ainovel.server.web.controller;

import com.ainovel.server.domain.model.ModelListingCapability;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.ModelInfo;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.AIProviderRegistryService;


import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 模型信息控制器
 * 提供获取模型信息的API
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/api/models")
public class ModelInfoController {
    
    @Autowired
    private AIService aiService;
    
    @Autowired
    private AIProviderRegistryService providerRegistryService;
    
    /**
     * 获取所有支持的提供商
     * 
     * @return 提供商列表
     */
    @GetMapping("/providers")
    public Flux<String> getProviders() {
        return aiService.getAvailableProviders();
    }
    
    /**
     * 获取指定提供商支持的模型列表
     * 
     * @param provider 提供商名称
     * @return 模型列表
     */
    @GetMapping("/providers/{provider}")
    public Flux<String> getModelsForProvider(@PathVariable String provider) {
        return aiService.getModelsForProvider(provider);
    }
    
    /**
     * 获取指定提供商支持的模型详细信息
     * 
     * @param provider 提供商名称
     * @return 模型信息列表
     */
    @GetMapping("/providers/{provider}/info")
    public Flux<ModelInfo> getModelInfosForProvider(@PathVariable String provider) {
        return aiService.getModelInfosForProvider(provider)
                .doOnError(e -> log.error("获取提供商 {} 的模型信息时出错: {}", provider, e.getMessage(), e));
    }
    
    /**
     * 使用API密钥获取指定提供商支持的模型详细信息
     * 
     * @param provider 提供商名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点 (可选)
     * @return 模型信息列表
     */
    @GetMapping("/providers/{provider}/info/auth")
    public Flux<ModelInfo> getModelInfosForProviderWithApiKey(
            @PathVariable String provider,
            @RequestParam String apiKey,
            @RequestParam(required = false) String apiEndpoint) {
        
        return aiService.getModelInfosForProviderWithApiKey(provider, apiKey, apiEndpoint)
                .doOnError(e -> log.error("使用API密钥获取提供商 {} 的模型信息时出错: {}", provider, e.getMessage(), e));
    }
    
    /**
     * 获取指定提供商的模型列表功能。
     *
     * @param provider 提供商名称
     * @return 模型列表功能 (NO_LISTING, LISTING_WITHOUT_KEY, LISTING_WITH_KEY, LISTING_WITH_OR_WITHOUT_KEY)
     */
    @GetMapping("/providers/{provider}/capability")
    public Mono<ResponseEntity<ModelListingCapability>> getProviderListingCapability(@PathVariable String provider) {
        return providerRegistryService.getProviderListingCapability(provider)
                .map(ResponseEntity::ok)
                .defaultIfEmpty(ResponseEntity.notFound().build())
                .doOnError(e -> log.error("获取提供商 {} 的列表能力时出错: {}", provider, e.getMessage()));
    }
    
    /**
     * 获取所有模型的分组信息
     * 
     * @return 模型分组信息
     */
    @GetMapping("/groups")
    public ResponseEntity<?> getModelGroups() {
        return ResponseEntity.ok(aiService.getModelGroups());
    }
}
