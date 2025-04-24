package com.ainovel.server.service.ai.registry;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.ModelInfo;
import com.ainovel.server.domain.model.ModelListingCapability;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;

/**
 * AI提供商注册表
 * 存储和管理各种AI提供商的元数据和能力信息
 */
@Service
@Slf4j
public class AIProviderRegistry {

    // 存储提供商的模型列表能力
    private final Map<String, ModelListingCapability> providerCapabilities = new ConcurrentHashMap<>();
    
    // 存储提供商的默认API端点
    private final Map<String, String> defaultApiEndpoints = new ConcurrentHashMap<>();
    
    // 存储提供商的默认模型列表
    private final Map<String, Map<String, ModelInfo>> defaultModels = new ConcurrentHashMap<>();

    @PostConstruct
    public void init() {
        log.info("初始化AI提供商注册表");
        
        // 注册提供商能力
        registerProviderCapability("openai", ModelListingCapability.LISTING_WITH_KEY);
        registerProviderCapability("anthropic", ModelListingCapability.LISTING_WITH_KEY);
        registerProviderCapability("gemini", ModelListingCapability.LISTING_WITH_KEY);
        registerProviderCapability("openrouter", ModelListingCapability.LISTING_WITHOUT_KEY);
        registerProviderCapability("siliconflow", ModelListingCapability.LISTING_WITH_KEY);
        registerProviderCapability("x-ai", ModelListingCapability.LISTING_WITH_KEY);
        registerProviderCapability("grok", ModelListingCapability.LISTING_WITH_KEY);
        
        // 注册默认API端点
        registerDefaultApiEndpoint("openai", "https://api.openai.com/v1");
        registerDefaultApiEndpoint("anthropic", "https://api.anthropic.com");
        registerDefaultApiEndpoint("gemini", "https://generativelanguage.googleapis.com/");
        registerDefaultApiEndpoint("openrouter", "https://openrouter.ai/api/v1");
        registerDefaultApiEndpoint("siliconflow", "https://api.siliconflow.cn/v1");
        registerDefaultApiEndpoint("x-ai", "https://api.x.ai/v1");
        registerDefaultApiEndpoint("grok", "https://api.x.ai/v1");
    }
    
    /**
     * 注册提供商的模型列表能力
     *
     * @param providerName 提供商名称
     * @param capability 模型列表能力
     */
    public void registerProviderCapability(String providerName, ModelListingCapability capability) {
        providerCapabilities.put(providerName.toLowerCase(), capability);
    }
    
    /**
     * 获取提供商的模型列表能力
     *
     * @param providerName 提供商名称
     * @return 模型列表能力，如果提供商未注册则返回NO_LISTING
     */
    public ModelListingCapability getProviderCapability(String providerName) {
        return providerCapabilities.getOrDefault(
            providerName.toLowerCase(), 
            ModelListingCapability.NO_LISTING
        );
    }
    
    /**
     * 注册提供商的默认API端点
     *
     * @param providerName 提供商名称
     * @param apiEndpoint 默认API端点
     */
    public void registerDefaultApiEndpoint(String providerName, String apiEndpoint) {
        defaultApiEndpoints.put(providerName.toLowerCase(), apiEndpoint);
    }
    
    /**
     * 获取提供商的默认API端点
     *
     * @param providerName 提供商名称
     * @return 默认API端点，如果提供商未注册则返回null
     */
    public String getDefaultApiEndpoint(String providerName) {
        return defaultApiEndpoints.get(providerName.toLowerCase());
    }
    
    /**
     * 注册提供商的默认模型
     *
     * @param providerName 提供商名称
     * @param modelId 模型ID
     * @param modelInfo 模型信息
     */
    public void registerDefaultModel(String providerName, String modelId, ModelInfo modelInfo) {
        String provider = providerName.toLowerCase();
        defaultModels.computeIfAbsent(provider, k -> new ConcurrentHashMap<>())
                   .put(modelId, modelInfo);
    }
    
    /**
     * 获取提供商的所有默认模型
     *
     * @param providerName 提供商名称
     * @return 默认模型列表，如果提供商未注册则返回空Map
     */
    public Map<String, ModelInfo> getDefaultModels(String providerName) {
        return defaultModels.getOrDefault(
            providerName.toLowerCase(), 
            Collections.emptyMap()
        );
    }
    
    /**
     * 获取提供商的默认模型IDs
     *
     * @param providerName 提供商名称
     * @return 默认模型ID集合
     */
    public Set<String> getDefaultModelIds(String providerName) {
        return defaultModels.getOrDefault(
            providerName.toLowerCase(), 
            Collections.emptyMap()
        ).keySet();
    }
    
    /**
     * 获取所有注册的提供商
     *
     * @return 提供商名称集合
     */
    public Set<String> getAllProviders() {
        return providerCapabilities.keySet();
    }
} 