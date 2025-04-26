package com.ainovel.server.service.impl;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ainovel.server.config.ProxyConfig;
import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.ModelInfo;
import com.ainovel.server.domain.model.ModelListingCapability;
import com.ainovel.server.service.AIProviderRegistryService;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.ai.AIModelProvider;

import com.ainovel.server.service.ai.factory.AIModelProviderFactory;
import com.ainovel.server.service.ai.capability.ProviderCapabilityService;

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
    private final NovelService novelService;
    private final AIProviderRegistryService providerRegistryService;

    private final AIModelProviderFactory providerFactory;
    private final ProviderCapabilityService capabilityService;

    @Autowired
    public AIServiceImpl(
            NovelService novelService,
            AIProviderRegistryService providerRegistryService,
            AIModelProviderFactory providerFactory,
            ProviderCapabilityService capabilityService) {
        this.novelService = novelService;
        this.providerRegistryService = providerRegistryService;
        this.providerFactory = providerFactory;
        this.capabilityService = capabilityService;
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
                "google/gemini-2.5-pro-exp-03-25:free",
                "deepseek/deepseek-v3-base:free",
                "x-ai/grok-3-beta",
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
                "meta-llama/Meta-Llama-3.1-70B-Instruct",
                "meta-llama/Meta-Llama-3.1-70B-Instruct"
        ));
        
        // 更新X.AI的modelGroups，添加所有Grok模型
        modelGroups.put("x-ai", List.of(
                "x-ai/grok-3-beta",
                "x-ai/grok-3",
                "x-ai/grok-3-fast-beta",
                "x-ai/grok-3-mini-beta",
                "x-ai/grok-3-mini-fast-beta",
                "x-ai/grok-2-vision-1212"
        ));

        modelGroups.put("openrouter", List.of(
                "openai/gpt-3.5-turbo",
                "openai/gpt-4",
                "openai/gpt-4-turbo",
                "openai/gpt-4o",
                "anthropic/claude-3-opus",
                "anthropic/claude-3-sonnet",
                "anthropic/claude-3-haiku",
                "google/gemini-pro",
                "google/gemini-1.5-pro",
                "meta-llama/llama-3-70b-instruct",
                "meta-llama/llama-3-8b-instruct"
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
            log.warn("请求未知的提供商 '{}' 的模型名称列表", provider);
            // 即使未知，也返回空列表，避免前端报错
            return Flux.empty();
            // return Flux.error(new IllegalArgumentException("未知的提供商: " + provider));
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
    public Flux<ModelInfo> getModelInfosForProvider(String provider) {
        if (!StringUtils.isNotBlank(provider)) {
            return Flux.error(new IllegalArgumentException("提供商名称不能为空"));
        }
        String lowerCaseProvider = provider.toLowerCase();

        // 1. 获取提供商能力
        return providerRegistryService.getProviderListingCapability(lowerCaseProvider)
                .flatMapMany(capability -> {
                    log.info("提供商 '{}' 的能力是: {}", lowerCaseProvider, capability);
                    // 2. 根据能力决定行为
                    if (capability == ModelListingCapability.LISTING_WITHOUT_KEY /* || capability == ModelListingCapability.LISTING_WITH_OR_WITHOUT_KEY */ ) {
                        log.info("提供商 '{}' 支持无密钥列出模型，尝试调用实际 provider", lowerCaseProvider);
                        // 尝试获取实际的 Provider 实例并调用 listModels()
                        // 注意：createAIModelProvider 可能需要 modelName 和 apiKey，这里需要调整
                        // 简化处理：假设 createAIModelProvider 能处理 dummy key，或者有其他方式获取实例
                        try {
                            String defaultEndpoint = capabilityService.getDefaultApiEndpoint(lowerCaseProvider);
                            
                            // 获取默认模型ID用于创建临时提供商实例
                            return capabilityService.getDefaultModels(lowerCaseProvider)
                                .switchIfEmpty(Mono.error(new RuntimeException("未找到提供商 " + lowerCaseProvider + " 的默认模型")))
                                .take(1)  // 只取第一个模型，用于创建临时实例
                                .flatMap(firstModel -> {
                                    // 创建临时提供商实例用于获取模型列表
                                    AIModelProvider providerInstance = providerFactory.createProvider(
                                            lowerCaseProvider,
                                            firstModel.getId(),
                                            "dummy-key-for-listing",
                                            null // 使用默认端点
                                    );
                                    
                                    if (providerInstance != null) {
                                        return providerInstance.listModels()
                                                .doOnError(e -> log.error("调用提供商 '{}' 的 listModels 失败，将回退到默认列表", lowerCaseProvider, e))
                                                .onErrorResume(e -> getDefaultModelInfos(lowerCaseProvider)); // 出错时回退
                                    } else {
                                        log.warn("无法创建提供商 '{}' 的实例，将回退到默认列表", lowerCaseProvider);
                                        return getDefaultModelInfos(lowerCaseProvider);
                                    }
                                });
                        } catch (Exception e) {
                            log.error("尝试为提供商 '{}' 获取实际模型列表时出错，将回退到默认列表", lowerCaseProvider, e);
                            return getDefaultModelInfos(lowerCaseProvider);
                        }
                    } else {
                        // 能力为 NO_LISTING 或 LISTING_WITH_KEY，返回默认模型信息
                        log.info("提供商 '{}' 能力为 {}，返回默认模型列表", lowerCaseProvider, capability);
                        return getDefaultModelInfos(lowerCaseProvider);
                    }
                })
                .switchIfEmpty(Flux.defer(() -> {
                    // 如果获取能力失败或提供商未知，也返回默认列表
                    log.warn("无法获取提供商 '{}' 的能力或提供商未知，返回默认模型列表", lowerCaseProvider);
                    return getDefaultModelInfos(lowerCaseProvider);
                }));
    }

    // 辅助方法：获取默认模型信息
    private Flux<ModelInfo> getDefaultModelInfos(String lowerCaseProvider) {
        List<String> modelNames = modelGroups.get(lowerCaseProvider);
        if (modelNames == null || modelNames.isEmpty()) {
            log.warn("无法找到提供商 '{}' 的默认模型名称列表", lowerCaseProvider);
            return Flux.empty(); // 如果连默认的都没有，返回空
        }

        List<ModelInfo> models = new ArrayList<>();
        for (String modelName : modelNames) {
            // 创建基础的 ModelInfo 对象
            models.add(ModelInfo.basic(modelName, modelName, lowerCaseProvider)
                    .withDescription(lowerCaseProvider + "的" + modelName + "模型")
                    .withMaxTokens(8192) // 使用合理的默认值
                    .withUnifiedPrice(0.001)); // 使用合理的默认值
        }
        log.info("为提供商 '{}' 返回了 {} 个默认模型信息", lowerCaseProvider, models.size());
        return Flux.fromIterable(models);
    }

    @Override
    public Flux<ModelInfo> getModelInfosForProviderWithApiKey(String provider, String apiKey, String apiEndpoint) {
        if (!StringUtils.isNotBlank(provider)) {
            return Flux.error(new IllegalArgumentException("提供商名称不能为空"));
        }

        if (!StringUtils.isNotBlank(apiKey)) {
            return Flux.error(new IllegalArgumentException("API密钥不能为空"));
        }

        String lowerCaseProvider = provider.toLowerCase();
        
        // 检查提供商是否已知 (通过modelGroups)
        if (!modelGroups.containsKey(lowerCaseProvider)) {
            log.warn("请求未知的提供商 '{}'", provider);
            return Flux.error(new IllegalArgumentException("未知的提供商: " + provider));
        }

        // 尝试获取该提供商的默认模型ID，用于创建Provider实例
        return capabilityService.getDefaultModels(lowerCaseProvider)
            .take(1) // 只取第一个默认模型
            .switchIfEmpty(Mono.defer(() -> {
                // 如果capabilityService没有默认模型，尝试从modelGroups获取第一个作为后备
                List<String> modelsFromGroup = modelGroups.get(lowerCaseProvider);
                if (modelsFromGroup != null && !modelsFromGroup.isEmpty()) {
                    log.info("使用modelGroups中的第一个模型: {} 作为默认模型", modelsFromGroup.get(0));
                    return Mono.just(ModelInfo.basic(modelsFromGroup.get(0), modelsFromGroup.get(0), lowerCaseProvider));
                } else {
                    log.error("无法为提供商 '{}' 找到任何模型", lowerCaseProvider);
                    return Mono.error(new RuntimeException("无法为提供商 " + lowerCaseProvider + " 找到任何模型"));
                }
            }))
            .flatMap(defaultModel -> {
                try {
                    log.info("为提供商 '{}' 创建Provider实例，使用模型 '{}'", lowerCaseProvider, defaultModel.getId());
                    
                    // 创建Provider实例
                    AIModelProvider providerInstance = providerFactory.createProvider(
                        lowerCaseProvider,
                        defaultModel.getId(),
                        apiKey,
                        apiEndpoint
                    );
                    
                    if (providerInstance != null) {
                        log.info("成功创建Provider实例，调用listModelsWithApiKey获取模型列表");
                        // 调用实例的listModelsWithApiKey方法
                        return providerInstance.listModelsWithApiKey(apiKey, apiEndpoint)
                            .collectList()
                            .flatMapMany(models -> {
                                log.info("使用API密钥获取提供商 '{}' 的模型信息列表成功: count={}", lowerCaseProvider, models.size());
                                return Flux.fromIterable(models);
                            })
                            .onErrorResume(e -> {
                                log.error("调用提供商 '{}' 的listModelsWithApiKey失败: {}", lowerCaseProvider, e.getMessage(), e);
                                return Flux.error(new RuntimeException("获取模型列表失败: " + e.getMessage()));
                            });
                    } else {
                        log.error("无法创建提供商 '{}' 的Provider实例", lowerCaseProvider);
                        return Mono.error(new RuntimeException("无法创建提供商实例: " + lowerCaseProvider));
                    }
                } catch (Exception e) {
                    log.error("为提供商 '{}' 创建Provider实例或获取模型时出错: {}", lowerCaseProvider, e.getMessage(), e);
                    return Mono.error(new RuntimeException("获取模型列表时发生内部错误: " + e.getMessage()));
                }
            });
    }

    @Override
    public AIModelProvider createAIModelProvider(String providerName, String modelName, String apiKey, String apiEndpoint) {
        return providerFactory.createProvider(providerName, modelName, apiKey, apiEndpoint);
    }
}
