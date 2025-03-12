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
        log.debug("生成AI内容: {}", request.getPrompt());
        
        // 模拟处理延迟
        int processingTimeMs = calculateProcessingTime(request);
        
        return Mono.delay(Duration.ofMillis(processingTimeMs))
                .map(ignored -> createMockResponse(request))
                .doOnSuccess(response -> log.debug("AI内容生成完成，使用了{}个令牌", response.getTokenUsage().getTotalTokens()));
    }
    
    @Override
    @Timed(value = "ai.generate.content.stream", description = "Time taken to generate AI content stream")
    public Flux<String> generateContentStream(AIRequest request) {
        log.debug("流式生成AI内容: {}", request.getPrompt());
        
        // 生成模拟内容
        String content = generateMockContent(request);
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
    
    /**
     * 创建模拟响应
     */
    private AIResponse createMockResponse(AIRequest request) {
        String content = generateMockContent(request);
        
        // 计算令牌使用情况
        int promptTokens = calculateTokens(request.getPrompt());
        int completionTokens = calculateTokens(content);
        
        AIResponse.TokenUsage tokenUsage = AIResponse.TokenUsage.builder()
                .promptTokens(promptTokens)
                .completionTokens(completionTokens)
                .build();
        
        return AIResponse.builder()
                .id(UUID.randomUUID().toString())
                .model(request.getModel())
                .content(content)
                .tokenUsage(tokenUsage)
                .createdAt(LocalDateTime.now())
                .finishReason("stop")
                .build();
    }
    
    /**
     * 生成模拟内容
     */
    private String generateMockContent(AIRequest request) {
        Random random = ThreadLocalRandom.current();
        
        // 根据提示长度生成相应长度的响应
        int sentenceCount = 3 + random.nextInt(7); // 3-10句话
        StringBuilder content = new StringBuilder();
        
        for (int i = 0; i < sentenceCount; i++) {
            content.append(LOREM_IPSUM.get(random.nextInt(LOREM_IPSUM.size()))).append(" ");
        }
        
        return content.toString().trim();
    }
    
    /**
     * 计算处理时间（毫秒）
     */
    private int calculateProcessingTime(AIRequest request) {
        Random random = ThreadLocalRandom.current();
        
        // 基础处理时间
        int baseTime = 500;
        
        // 根据模型调整处理时间
        if ("gpt-4".equals(request.getModel()) || "claude-3-opus".equals(request.getModel())) {
            baseTime = 1000; // 更高级的模型处理更慢
        }
        
        // 根据提示长度和最大令牌数调整处理时间
        int promptFactor = calculateTokens(request.getPrompt()) / 10;
        int maxTokensFactor = request.getMaxTokens() / 100;
        
        // 添加随机波动
        int randomFactor = random.nextInt(300);
        
        return baseTime + promptFactor + maxTokensFactor + randomFactor;
    }
    
    /**
     * 简单计算文本的令牌数（粗略估计）
     */
    private int calculateTokens(String text) {
        if (text == null || text.isEmpty()) {
            return 0;
        }
        
        // 粗略估计：每4个字符约为1个令牌
        return text.length() / 4 + 1;
    }
}
