package com.ainovel.server.service.impl;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.BaseAIRequest;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.ai.AIModelProvider;
import com.ainovel.server.service.ai.AnthropicModelProvider;
import com.ainovel.server.service.ai.GeminiModelProvider;
import com.ainovel.server.service.ai.OpenAIModelProvider;
import com.ainovel.server.service.ai.SiliconFlowModelProvider;
import com.ainovel.server.service.ai.langchain4j.AnthropicLangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.GeminiLangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.OpenAILangChain4jModelProvider;
import com.ainovel.server.service.ai.langchain4j.SiliconFlowLangChain4jModelProvider;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 基础AI服务实现
 * 负责AI模型的基础功能，不包含业务逻辑
 */
@Slf4j
@Service
public class AIServiceImpl implements AIService {
    
    // 是否使用LangChain4j实现
    private boolean useLangChain4j = true;
    
    // 模型分组信息
    private final Map<String, List<String>> modelGroups = new HashMap<>();
    
    public AIServiceImpl() {
        initializeModelGroups();
    }
    
    /**
     * 初始化模型分组信息
     */
    private void initializeModelGroups() {
        modelGroups.put("openai", List.of(
                "gpt-3.5-turbo",
                "gpt-4",
                "gpt-4-turbo",
                "gpt-4o"
        ));
        
        modelGroups.put("anthropic", List.of(
                "claude-3-opus",
                "claude-3-sonnet",
                "claude-3-haiku"
        ));
        
        modelGroups.put("gemini", List.of(
                "gemini-2.0-flash",
                "gemini-2.0-pro",
                "gemini-2.0-flash-lite"
        ));
        
        modelGroups.put("siliconflow", List.of(
                "deepseek-ai/DeepSeek-V2.5",
                "deepseek-ai/DeepSeek-R1",
                "Qwen/QwQ-32B",
                "Qwen/Qwen2-72B"
        ));
    }
    
    @Override
    public Mono<AIResponse> generateContent(BaseAIRequest request) {
        // 基础服务只负责创建提供商并调用，不负责获取用户配置
        if (request.getApiKey() == null || request.getApiKey().isEmpty()) {
            return Mono.error(new IllegalArgumentException("API密钥不能为空"));
        }
        
        AIModelProvider provider = createAIModelProvider(
                getProviderForModel(request.getModel()),
                request.getModel(),
                request.getApiKey(),
                request.getApiEndpoint()
        );
        
        if (provider == null) {
            return Mono.error(new IllegalArgumentException("不支持的AI模型: " + request.getModel()));
        }
        
        return provider.generateContent(convertToProviderRequest(request));
    }
    
    @Override
    public Flux<String> generateContentStream(BaseAIRequest request) {
        // 基础服务只负责创建提供商并调用，不负责获取用户配置
        if (request.getApiKey() == null || request.getApiKey().isEmpty()) {
            return Flux.error(new IllegalArgumentException("API密钥不能为空"));
        }
        
        AIModelProvider provider = createAIModelProvider(
                getProviderForModel(request.getModel()),
                request.getModel(),
                request.getApiKey(),
                request.getApiEndpoint()
        );
        
        if (provider == null) {
            return Flux.error(new IllegalArgumentException("不支持的AI模型: " + request.getModel()));
        }
        
        return provider.generateContentStream(convertToProviderRequest(request));
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
    public Mono<Double> estimateCost(BaseAIRequest request) {
        // 基础服务只负责创建提供商并调用，不负责获取用户配置
        if (request.getApiKey() == null || request.getApiKey().isEmpty()) {
            return Mono.error(new IllegalArgumentException("API密钥不能为空"));
        }
        
        AIModelProvider provider = createAIModelProvider(
                getProviderForModel(request.getModel()),
                request.getModel(),
                request.getApiKey(),
                request.getApiEndpoint()
        );
        
        if (provider == null) {
            return Mono.error(new IllegalArgumentException("不支持的AI模型: " + request.getModel()));
        }
        
        return provider.estimateCost(convertToProviderRequest(request));
    }
    
    @Override
    public Mono<Boolean> validateApiKey(String userId, String provider, String modelName, String apiKey) {
        AIModelProvider modelProvider = createAIModelProvider(provider, modelName, apiKey, null);
        return modelProvider.validateApiKey();
    }
    
    /**
     * 设置是否使用LangChain4j实现
     * @param useLangChain4j 是否使用LangChain4j
     */
    @Override
    public void setUseLangChain4j(boolean useLangChain4j) {
        this.useLangChain4j = useLangChain4j;
    }
    
    /**
     * 将BaseAIRequest转换为AIModelProvider需要的请求格式
     * 这里假设AIModelProvider使用com.ainovel.server.domain.model.AIRequest
     * 如果实际使用的是其他格式，需要相应调整
     * @param baseRequest 基础AI请求
     * @return 提供商需要的请求格式
     */
    private com.ainovel.server.domain.model.AIRequest convertToProviderRequest(BaseAIRequest baseRequest) {
        com.ainovel.server.domain.model.AIRequest providerRequest = new com.ainovel.server.domain.model.AIRequest();
        
        // 复制基本字段
        providerRequest.setUserId(baseRequest.getUserId());
        providerRequest.setModel(baseRequest.getModel());
        providerRequest.setPrompt(baseRequest.getPrompt());
        providerRequest.setMaxTokens(baseRequest.getMaxTokens());
        providerRequest.setTemperature(baseRequest.getTemperature());
        providerRequest.setParameters(baseRequest.getParameters());
        
        // 转换消息
        if (baseRequest.getMessages() != null && !baseRequest.getMessages().isEmpty()) {
            List<com.ainovel.server.domain.model.AIRequest.Message> providerMessages = new java.util.ArrayList<>();
            
            for (BaseAIRequest.Message baseMessage : baseRequest.getMessages()) {
                com.ainovel.server.domain.model.AIRequest.Message providerMessage = 
                        new com.ainovel.server.domain.model.AIRequest.Message();
                providerMessage.setRole(baseMessage.getRole());
                providerMessage.setContent(baseMessage.getContent());
                providerMessages.add(providerMessage);
            }
            
            providerRequest.setMessages(providerMessages);
        }
        
        return providerRequest;
    }
    
    /**
     * 获取模型的提供商名称
     * @param modelName 模型名称
     * @return 提供商名称
     */
    @Override
    public String getProviderForModel(String modelName) {
        for (Map.Entry<String, List<String>> entry : modelGroups.entrySet()) {
            if (entry.getValue().contains(modelName)) {
                return entry.getKey();
            }
        }
        throw new IllegalArgumentException("未知的模型: " + modelName);
    }
    
    /**
     * 获取提供商支持的模型列表
     * @param provider 提供商名称
     * @return 模型列表
     */
    @Override
    public Flux<String> getModelsForProvider(String provider) {
        List<String> models = modelGroups.get(provider.toLowerCase());
        if (models == null) {
            return Flux.error(new IllegalArgumentException("未知的提供商: " + provider));
        }
        return Flux.fromIterable(models);
    }
    
    /**
     * 获取所有支持的提供商
     * @return 提供商列表
     */
    @Override
    public Flux<String> getAvailableProviders() {
        return Flux.fromIterable(modelGroups.keySet());
    }
    
    /**
     * 获取模型分组信息
     * @return 模型分组信息
     */
    @Override
    public Map<String, List<String>> getModelGroups() {
        return modelGroups;
    }
    
    /**
     * 清除用户的模型提供商缓存
     * 基础服务不再维护缓存，此方法为空实现
     * @param userId 用户ID
     * @return 操作结果
     */
    @Override
    public Mono<Void> clearUserProviderCache(String userId) {
        // 基础服务不再维护缓存
        return Mono.empty();
    }
    
    /**
     * 清除所有模型提供商缓存
     * 基础服务不再维护缓存，此方法为空实现
     * @return 操作结果
     */
    @Override
    public Mono<Void> clearAllProviderCache() {
        // 基础服务不再维护缓存
        return Mono.empty();
    }
    
    /**
     * 设置模型提供商的代理
     * @param userId 用户ID
     * @param modelName 模型名称
     * @param proxyHost 代理主机
     * @param proxyPort 代理端口
     * @return 操作结果
     */
    @Override
    public Mono<Void> setModelProviderProxy(String userId, String modelName, String proxyHost, int proxyPort) {
        // 基础服务不再维护缓存，此方法需要在业务层实现
        return Mono.error(new UnsupportedOperationException("此方法需要在业务层实现"));
    }
    
    /**
     * 禁用模型提供商的代理
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return 操作结果
     */
    @Override
    public Mono<Void> disableModelProviderProxy(String userId, String modelName) {
        // 基础服务不再维护缓存，此方法需要在业务层实现
        return Mono.error(new UnsupportedOperationException("此方法需要在业务层实现"));
    }
    
    /**
     * 检查模型提供商的代理是否已启用
     * @param userId 用户ID
     * @param modelName 模型名称
     * @return 是否已启用
     */
    @Override
    public Mono<Boolean> isModelProviderProxyEnabled(String userId, String modelName) {
        // 基础服务不再维护缓存，此方法需要在业务层实现
        return Mono.error(new UnsupportedOperationException("此方法需要在业务层实现"));
    }
    
    /**
     * 创建AI模型提供商
     * @param provider 提供商名称
     * @param modelName 模型名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @return AI模型提供商
     */
    @Override
    public AIModelProvider createAIModelProvider(String provider, String modelName, String apiKey, String apiEndpoint) {
        if (useLangChain4j) {
            // 使用LangChain4j实现
            return switch (provider.toLowerCase()) {
                case "openai" -> new OpenAILangChain4jModelProvider(modelName, apiKey, apiEndpoint);
                case "anthropic" -> new AnthropicLangChain4jModelProvider(modelName, apiKey, apiEndpoint);
                case "gemini" -> new GeminiLangChain4jModelProvider(modelName, apiKey, apiEndpoint);
                case "siliconflow" -> new SiliconFlowLangChain4jModelProvider(modelName, apiKey, apiEndpoint);
                default -> null;
            };
        } else {
            // 使用原始实现
            return switch (provider.toLowerCase()) {
                case "openai" -> new OpenAIModelProvider(modelName, apiKey, apiEndpoint);
                case "anthropic" -> new AnthropicModelProvider(modelName, apiKey, apiEndpoint);
                case "gemini" -> new GeminiModelProvider(modelName, apiKey, apiEndpoint);
                case "siliconflow" -> new SiliconFlowModelProvider(modelName, apiKey, apiEndpoint);
                default -> null;
            };
        }
    }
} 