package com.ainovel.server.service.impl;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.User.AIModelConfig;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.UserService;
import com.ainovel.server.service.ai.AIModelProvider;
import com.ainovel.server.service.ai.AnthropicModelProvider;
import com.ainovel.server.service.ai.GeminiModelProvider;
import com.ainovel.server.service.ai.OpenAIModelProvider;
import com.ainovel.server.service.ai.SiliconFlowModelProvider;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * AI服务实现
 */
@Service
public class AIServiceImpl implements AIService {
    
    private final UserService userService;
    
    // 缓存用户的AI模型提供商
    private final Map<String, Map<String, AIModelProvider>> userProviders = new ConcurrentHashMap<>();
    
    @Autowired
    public AIServiceImpl(UserService userService) {
        this.userService = userService;
    }
    
    @Override
    public Mono<AIResponse> generateContent(AIRequest request) {
        return getAIModelProvider(request.getUserId(), request.getModel())
                .flatMap(provider -> provider.generateContent(request));
    }
    
    @Override
    public Flux<String> generateContentStream(AIRequest request) {
        return getAIModelProvider(request.getUserId(), request.getModel())
                .flatMapMany(provider -> provider.generateContentStream(request));
    }
    
    @Override
    public Flux<String> getAvailableModels() {
        // 返回支持的模型列表
        return Flux.just(
                "gpt-3.5-turbo",
                "gpt-4",
                "gpt-4-turbo",
                "gpt-4o",
                "claude-3-opus",
                "claude-3-sonnet",
                "claude-3-haiku",
                "gemini-2.0-flash",
                "gemini-2.0-pro",
                "gemini-2.0-flash-lite",
                "deepseek-ai/DeepSeek-V2.5",
                "deepseek-ai/DeepSeek-R1",
                "Qwen/QwQ-32B",
                "Qwen/Qwen2-72B"
        );
    }
    
    @Override
    public Mono<Double> estimateCost(AIRequest request) {
        return getAIModelProvider(request.getUserId(), request.getModel())
                .flatMap(provider -> provider.estimateCost(request));
    }
    
    @Override
    public Mono<Boolean> validateApiKey(String userId, String provider, String modelName, String apiKey) {
        AIModelProvider modelProvider = createAIModelProvider(provider, modelName, apiKey, null);
        return modelProvider.validateApiKey();
    }
    
    /**
     * 获取AI模型提供商
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return AI模型提供商
     */
    private Mono<AIModelProvider> getAIModelProvider(String userId, String modelName) {
        // 如果没有指定模型名称，则使用用户的默认模型
        if (modelName == null || modelName.isEmpty()) {
            return userService.getUserDefaultAIModelConfig(userId)
                    .flatMap(config -> {
                        if (config == null) {
                            return Mono.error(new IllegalArgumentException("用户没有配置默认AI模型"));
                        }
                        return getOrCreateAIModelProvider(userId, config);
                    });
        }
        
        // 如果指定了模型名称，则查找对应的配置
        return userService.getUserAIModelConfigs(userId)
                .filter(config -> modelName.equals(config.getModelName()))
                .next()
                .flatMap(config -> getOrCreateAIModelProvider(userId, config))
                .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到指定的AI模型配置: " + modelName)));
    }
    
    /**
     * 获取或创建AI模型提供商
     * @param userId 用户ID
     * @param config AI模型配置
     * @return AI模型提供商
     */
    private Mono<AIModelProvider> getOrCreateAIModelProvider(String userId, AIModelConfig config) {
        // 检查缓存中是否已存在
        Map<String, AIModelProvider> userProviderMap = userProviders.computeIfAbsent(userId, k -> new HashMap<>());
        String key = config.getProvider() + ":" + config.getModelName();
        
        AIModelProvider provider = userProviderMap.get(key);
        if (provider != null) {
            return Mono.just(provider);
        }
        
        // 创建新的提供商
        provider = createAIModelProvider(
                config.getProvider(),
                config.getModelName(),
                config.getApiKey(),
                config.getApiEndpoint()
        );
        
        if (provider != null) {
            userProviderMap.put(key, provider);
            return Mono.just(provider);
        }
        
        return Mono.error(new IllegalArgumentException("不支持的AI模型提供商: " + config.getProvider()));
    }
    
    /**
     * 创建AI模型提供商
     * @param provider 提供商名称
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @return AI模型提供商
     */
    private AIModelProvider createAIModelProvider(String provider, String modelName, String apiKey, String apiEndpoint) {
        return switch (provider.toLowerCase()) {
            case "openai" -> new OpenAIModelProvider(modelName, apiKey, apiEndpoint);
            case "anthropic" -> new AnthropicModelProvider(modelName, apiKey, apiEndpoint);
            case "gemini" -> new GeminiModelProvider(modelName, apiKey, apiEndpoint);
            case "siliconflow" -> new SiliconFlowModelProvider(modelName, apiKey, apiEndpoint);
            default -> null;
        };
    }
} 