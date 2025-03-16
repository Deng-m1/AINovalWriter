package com.ainovel.server.service.impl;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.BaseAIRequest;
import com.ainovel.server.service.AIService;
import com.ainovel.server.service.ai.AIModelProvider;

import io.micrometer.core.annotation.Timed;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 模拟AI服务实现类
 * 用于性能测试和开发环境
 */
@Slf4j
@Service
public class MockAIServiceImpl implements AIService {
    
    private static final List<String> AVAILABLE_MODELS = List.of(
            "gpt-3.5-turbo", 
            "gpt-4", 
            "claude-3-opus", 
            "claude-3-sonnet", 
            "llama-3-70b");
    
    private static final List<String> LOREM_IPSUM = List.of(
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.",
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum.",
            "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia.",
            "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit.",
            "Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet.",
            "Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam.",
            "At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis.");
    
    // 是否使用LangChain4j标志
    private boolean useLangChain4j = false;
    
    @Override
    @Timed(value = "ai.generate.content", description = "Time taken to generate AI content")
    public Mono<AIResponse> generateContent(BaseAIRequest request) {
        log.debug("生成AI内容");
        
        // 模拟处理延迟
        int processingTimeMs = 1000;
        
        return Mono.delay(Duration.ofMillis(processingTimeMs))
                .map(ignored -> createMockResponse())
                .doOnSuccess(response -> log.debug("AI内容生成完成"));
    }
    
    @Override
    @Timed(value = "ai.generate.content.stream", description = "Time taken to generate AI content stream")
    public Flux<String> generateContentStream(BaseAIRequest request) {
        log.debug("流式生成AI内容");
        
        // 生成模拟内容
        String content = generateMockContent();
        String[] words = content.split(" ");
        
        // 模拟流式响应，每次返回一个单词
        return Flux.fromArray(words)
                .delayElements(Duration.ofMillis(50)) // 每个单词之间的延迟
                .doOnComplete(() -> log.debug("流式AI内容生成完成"));
    }
    
    @Override
    public Flux<String> getAvailableModels() {
        return Flux.fromIterable(AVAILABLE_MODELS);
    }
    
    @Override
    public Mono<Double> estimateCost(BaseAIRequest request) {
        // 模拟成本估算
        return Mono.just(0.01); // 固定返回一个很小的值
    }
    
    @Override
    public Mono<Boolean> validateApiKey(String userId, String provider, String modelName, String apiKey) {
        // 模拟API密钥验证，始终返回成功
        return Mono.just(true);
    }
    
    @Override
    public String getProviderForModel(String modelName) {
        // 简单实现，根据模型名称前缀判断提供商
        if (modelName.startsWith("gpt")) {
            return "openai";
        } else if (modelName.startsWith("claude")) {
            return "anthropic";
        } else if (modelName.startsWith("gemini")) {
            return "gemini";
        } else if (modelName.startsWith("llama")) {
            return "siliconflow";
        }
        return "unknown";
    }
    
    @Override
    public Flux<String> getModelsForProvider(String provider) {
        // 简单实现，根据提供商名称返回对应的模型
        List<String> models;
        switch (provider.toLowerCase()) {
            case "openai":
                models = List.of("gpt-3.5-turbo", "gpt-4");
                break;
            case "anthropic":
                models = List.of("claude-3-opus", "claude-3-sonnet");
                break;
            case "gemini":
                models = List.of("gemini-pro", "gemini-ultra");
                break;
            case "siliconflow":
                models = List.of("llama-3-70b");
                break;
            default:
                models = List.of();
        }
        return Flux.fromIterable(models);
    }
    
    @Override
    public Flux<String> getAvailableProviders() {
        return Flux.fromIterable(List.of("openai", "anthropic", "gemini", "siliconflow"));
    }
    
    @Override
    public Map<String, List<String>> getModelGroups() {
        Map<String, List<String>> groups = new HashMap<>();
        groups.put("openai", List.of("gpt-3.5-turbo", "gpt-4"));
        groups.put("anthropic", List.of("claude-3-opus", "claude-3-sonnet"));
        groups.put("gemini", List.of("gemini-pro", "gemini-ultra"));
        groups.put("siliconflow", List.of("llama-3-70b"));
        return groups;
    }
    
    @Override
    public Mono<Void> clearUserProviderCache(String userId) {
        // 模拟实现，不做任何操作
        return Mono.empty();
    }
    
    @Override
    public Mono<Void> clearAllProviderCache() {
        // 模拟实现，不做任何操作
        return Mono.empty();
    }
    
    @Override
    public Mono<Void> setModelProviderProxy(String userId, String modelName, String proxyHost, int proxyPort) {
        // 模拟实现，不做任何操作
        return Mono.empty();
    }
    
    @Override
    public Mono<Void> disableModelProviderProxy(String userId, String modelName) {
        // 模拟实现，不做任何操作
        return Mono.empty();
    }
    
    @Override
    public Mono<Boolean> isModelProviderProxyEnabled(String userId, String modelName) {
        // 模拟实现，始终返回false
        return Mono.just(false);
    }
    
    @Override
    public AIModelProvider createAIModelProvider(String provider, String modelName, String apiKey, String apiEndpoint) {
        log.debug("创建模拟AI模型提供商: provider={}, model={}", provider, modelName);
        // 返回null，因为这是一个模拟实现
        return null;
    }
    
    @Override
    public void setUseLangChain4j(boolean useLangChain4j) {
        this.useLangChain4j = useLangChain4j;
        log.debug("设置使用LangChain4j: {}", useLangChain4j);
    }
    
    /**
     * 创建模拟响应
     */
    private AIResponse createMockResponse() {
        AIResponse response = new AIResponse();
        response.setId(UUID.randomUUID().toString());
        response.setModel("mock-model");
        response.setContent(generateMockContent());
        
        AIResponse.TokenUsage tokenUsage = new AIResponse.TokenUsage();
        tokenUsage.setPromptTokens(100);
        tokenUsage.setCompletionTokens(200);
        
        response.setTokenUsage(tokenUsage);
        response.setCreatedAt(LocalDateTime.now());
        response.setFinishReason("stop");
        
        return response;
    }
    
    /**
     * 生成模拟内容
     */
    private String generateMockContent() {
        Random random = ThreadLocalRandom.current();
        
        // 生成3-10句话
        int sentenceCount = 3 + random.nextInt(7);
        StringBuilder content = new StringBuilder();
        
        for (int i = 0; i < sentenceCount; i++) {
            content.append(LOREM_IPSUM.get(random.nextInt(LOREM_IPSUM.size()))).append(" ");
        }
        
        return content.toString().trim();
    }
}
