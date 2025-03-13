package com.ainovel.server.service.impl;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.service.AIService;

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
    
    @Override
    @Timed(value = "ai.generate.content", description = "Time taken to generate AI content")
    public Mono<AIResponse> generateContent(AIRequest request) {
        log.debug("生成AI内容");
        
        // 模拟处理延迟
        int processingTimeMs = 1000;
        
        return Mono.delay(Duration.ofMillis(processingTimeMs))
                .map(ignored -> createMockResponse())
                .doOnSuccess(response -> log.debug("AI内容生成完成"));
    }
    
    @Override
    @Timed(value = "ai.generate.content.stream", description = "Time taken to generate AI content stream")
    public Flux<String> generateContentStream(AIRequest request) {
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
    public Mono<Double> estimateCost(AIRequest request) {
        // 模拟成本估算
        return Mono.just(0.01); // 固定返回一个很小的值
    }
    
    @Override
    public Mono<Boolean> validateApiKey(String userId, String provider, String modelName, String apiKey) {
        // 模拟API密钥验证，始终返回成功
        return Mono.just(true);
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
