package com.ainovel.server.service.impl;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import com.ainovel.server.config.ProxyConfig;
import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
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
 * 基础AI服务实现 负责AI模型的基础功能和系统级信息，不包含用户特定配置。
 */
@Slf4j
@Service
public class AIServiceImpl implements AIService {

    // 是否使用LangChain4j实现
    private boolean useLangChain4j = true;
    @Autowired
    private ProxyConfig proxyConfig;

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
                "gemini-1.5-flash-latest",
                "gemini-1.5-pro-latest",
                "gemini-pro"
        ));

        modelGroups.put("siliconflow", List.of(
                "deepseek-ai/DeepSeek-V3",
                "Qwen/Qwen2.5-32B-Instruct",
                "Qwen/Qwen1.5-110B-Chat",
                "google/gemma-2-9b-it",
                "meta-llama/Meta-Llama-3.1-70B-Instruct"
        ));
    }

    @Override
    public Mono<AIResponse> generateContent(AIRequest request, String apiKey, String apiEndpoint) {
        if (!StringUtils.isNotBlank(apiKey)) {
            return Mono.error(new IllegalArgumentException("API密钥不能为空"));
        }
        String providerName = getProviderForModel(request.getModel());

        AIModelProvider provider = createAIModelProvider(
                providerName,
                request.getModel(),
                apiKey,
                apiEndpoint
        );

        if (provider == null) {
            return Mono.error(new IllegalArgumentException("无法为模型创建提供商: " + request.getModel()));
        }

        return provider.generateContent(request);
    }

    @Override
    public Flux<String> generateContentStream(AIRequest request, String apiKey, String apiEndpoint) {
        if (!StringUtils.isNotBlank(apiKey)) {
            return Flux.error(new IllegalArgumentException("API密钥不能为空"));
        }
        String providerName = getProviderForModel(request.getModel());

        AIModelProvider provider = createAIModelProvider(
                providerName,
                request.getModel(),
                apiKey,
                apiEndpoint
        );

        if (provider == null) {
            return Flux.error(new IllegalArgumentException("无法为模型创建提供商: " + request.getModel()));
        }

        return provider.generateContentStream(request);
    }

    @Override
    public Flux<String> getAvailableModels() {
        return Flux.fromIterable(modelGroups.values())
                .flatMap(Flux::fromIterable);
    }

    @Override
    public Mono<Double> estimateCost(AIRequest request, String apiKey, String apiEndpoint) {
        if (!StringUtils.isNotBlank(apiKey)) {
            return Mono.error(new IllegalArgumentException("API密钥不能为空"));
        }
        String providerName = getProviderForModel(request.getModel());

        AIModelProvider provider = createAIModelProvider(
                providerName,
                request.getModel(),
                apiKey,
                apiEndpoint
        );

        if (provider == null) {
            return Mono.error(new IllegalArgumentException("无法为模型创建提供商: " + request.getModel()));
        }

        return provider.estimateCost(request);
    }

    @Override
    public Mono<Boolean> validateApiKey(String userId, String provider, String modelName, String apiKey, String apiEndpoint) {
        if (!StringUtils.isNotBlank(apiKey)) {
            log.warn("验证 API Key 时发现 Key 为空，userId={}, provider={}, modelName={}", userId, provider, modelName);
            return Mono.just(false);
        }
        if (!modelGroups.containsKey(provider.toLowerCase())) {
            log.warn("尝试验证一个不受支持的提供商: provider={}", provider);
            return Mono.error(new IllegalArgumentException("不支持的提供商: " + provider));
        }

        AIModelProvider modelProvider = createAIModelProvider(provider, modelName, apiKey, apiEndpoint);
        if (modelProvider == null) {
            log.error("无法创建模型提供商实例以进行验证: provider={}, modelName={}", provider, modelName);
            return Mono.error(new IllegalArgumentException("无法为模型 " + modelName + " 创建提供商实例进行验证"));
        }

        return modelProvider.validateApiKey()
                .doOnError(e -> log.error("验证 API Key 时发生内部错误: userId={}, provider={}, modelName={}, error={}", userId, provider, modelName, e.getMessage()))
                .onErrorReturn(false);
    }

    @Override
    public void setUseLangChain4j(boolean useLangChain4j) {
        log.info("设置 useLangChain4j = {}", useLangChain4j);
        this.useLangChain4j = useLangChain4j;
    }

    @Override
    public String getProviderForModel(String modelName) {
        if (!StringUtils.isNotBlank(modelName)) {
            throw new IllegalArgumentException("模型名称不能为空");
        }
        for (Map.Entry<String, List<String>> entry : modelGroups.entrySet()) {
            if (entry.getValue().stream().anyMatch(model -> model.equalsIgnoreCase(modelName))) {
                return entry.getKey();
            }
        }
        log.warn("未找到模型 '{}' 对应的提供商", modelName);
        throw new IllegalArgumentException("未知的或系统不支持的模型: " + modelName);
    }

    @Override
    public Flux<String> getModelsForProvider(String provider) {
        if (!StringUtils.isNotBlank(provider)) {
            return Flux.error(new IllegalArgumentException("提供商名称不能为空"));
        }
        List<String> models = modelGroups.get(provider.toLowerCase());
        if (models == null) {
            log.warn("请求未知的提供商 '{}'", provider);
            return Flux.error(new IllegalArgumentException("未知的提供商: " + provider));
        }
        return Flux.fromIterable(models);
    }

    @Override
    public Flux<String> getAvailableProviders() {
        return Flux.fromIterable(modelGroups.keySet());
    }

    @Override
    public Map<String, List<String>> getModelGroups() {
        return new HashMap<>(modelGroups);
    }

    @Override
    public AIModelProvider createAIModelProvider(String provider, String modelName, String apiKey, String apiEndpoint) {
        String lowerCaseProvider = provider.toLowerCase();
        if (!StringUtils.isNotBlank(apiKey)) {
            log.error("尝试创建 Provider 时 API Key 为空: provider={}, modelName={}", provider, modelName);
            return null;
        }

        if (!modelGroups.containsKey(lowerCaseProvider)) {
            log.error("尝试为不受支持的提供商创建实例: provider={}", provider);
            return null;
        }

        List<String> supportedModels = modelGroups.get(lowerCaseProvider);
        if (supportedModels == null || supportedModels.stream().noneMatch(m -> m.equalsIgnoreCase(modelName))) {
            log.error("提供商 '{}' 不支持模型 '{}' 或模型名称无效", provider, modelName);
            return null;
        }

        log.debug("创建 AIModelProvider: provider={}, model={}, useLangChain4j={}, endpointProvided={}",
                lowerCaseProvider, modelName, useLangChain4j, StringUtils.isNotBlank(apiEndpoint));

        try {
            if (useLangChain4j) {
                return switch (lowerCaseProvider) {
                    case "openai" ->
                        new OpenAILangChain4jModelProvider(modelName, apiKey, apiEndpoint);
                    case "anthropic" ->
                        new AnthropicLangChain4jModelProvider(modelName, apiKey, apiEndpoint);
                    case "gemini" ->
                        new GeminiLangChain4jModelProvider(modelName, apiKey, apiEndpoint,proxyConfig);
                    case "siliconflow" ->
                        new SiliconFlowLangChain4jModelProvider(modelName, apiKey, apiEndpoint);
                    default -> {
                        log.error("LangChain4j 模式下不支持的提供商: {}", lowerCaseProvider);
                        yield null;
                    }
                };
            } else {
                return switch (lowerCaseProvider) {
                    case "openai" ->
                        new OpenAIModelProvider(modelName, apiKey, apiEndpoint);
                    case "anthropic" ->
                        new AnthropicModelProvider(modelName, apiKey, apiEndpoint);
                    case "gemini" ->
                        new GeminiModelProvider(modelName, apiKey, apiEndpoint);
                    case "siliconflow" ->
                        new SiliconFlowModelProvider(modelName, apiKey, apiEndpoint);
                    default -> {
                        log.error("原始模式下不支持的提供商: {}", lowerCaseProvider);
                        yield null;
                    }
                };
            }
        } catch (Exception e) {
            log.error("创建 AIModelProvider 实例时发生异常: provider={}, model={}, error={}",
                    provider, modelName, e.getMessage(), e);
            return null;
        }
    }
}
