package com.ainovel.server.web.controller;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.service.AIService;
import com.ainovel.server.web.base.ReactiveBaseController;

import io.micrometer.core.annotation.Timed;
import lombok.RequiredArgsConstructor;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * AI控制器
 */
@RestController
@RequestMapping("/ai")
@RequiredArgsConstructor
public class AIController extends ReactiveBaseController {
    
    private final AIService aiService;
    
    /**
     * 生成内容（非流式）
     * @param request AI请求
     * @return AI响应
     */
    @PostMapping("/generate")
    @Timed(value = "api.ai.generate", description = "Time taken to handle AI generate request")
    public Mono<AIResponse> generateContent(@RequestBody AIRequest request) {
        return aiService.generateContent(request);
    }
    
    /**
     * 生成内容（流式）
     * @param request AI请求
     * @return 流式AI响应
     */
    @PostMapping(value = "/generate/stream", produces = MediaType.APPLICATION_STREAM_JSON_VALUE)
    @Timed(value = "api.ai.generate.stream", description = "Time taken to handle AI generate stream request")
    public Flux<String> generateContentStream(@RequestBody AIRequest request) {
        return aiService.generateContentStream(request);
    }
    
    /**
     * 获取可用的AI模型列表
     * @return 模型列表
     */
    @GetMapping("/models")
    @Timed(value = "api.ai.models", description = "Time taken to get available AI models")
    public Flux<String> getAvailableModels() {
        return aiService.getAvailableModels();
    }
} 