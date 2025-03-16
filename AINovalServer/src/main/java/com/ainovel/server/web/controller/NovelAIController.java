package com.ainovel.server.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.AIRequest;
import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.web.dto.RevisionRequest;
import com.ainovel.server.web.dto.SuggestionRequest;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说AI控制器
 */
@RestController
@RequestMapping("/api/novels")
public class NovelAIController {
    
    private final NovelAIService novelAIService;
    
    @Autowired
    public NovelAIController(NovelAIService novelAIService) {
        this.novelAIService = novelAIService;
    }
    
    /**
     * 生成小说内容
     * @param request AI请求
     * @return AI响应
     */
    @PostMapping("/ai/generate")
    public Mono<AIResponse> generateNovelContent(@RequestBody AIRequest request) {
        return novelAIService.generateNovelContent(request);
    }
    
    /**
     * 生成小说内容（流式）
     * @param request AI请求
     * @return 流式AI响应
     */
    @PostMapping(value = "/ai/generate/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> generateNovelContentStream(@RequestBody AIRequest request) {
        return novelAIService.generateNovelContentStream(request)
                .map(content -> ServerSentEvent.<String>builder()
                        .data(content)
                        .build());
    }
    
    /**
     * 获取创作建议
     * @param novelId 小说ID
     * @param request 建议请求
     * @return 创作建议
     */
    @PostMapping("/{novelId}/ai/suggest")
    public Mono<AIResponse> getWritingSuggestion(
            @PathVariable String novelId,
            @RequestBody SuggestionRequest request) {
        return novelAIService.getWritingSuggestion(
                novelId,
                request.getSceneId(),
                request.getSuggestionType());
    }
    
    /**
     * 获取创作建议（流式）
     * @param novelId 小说ID
     * @param request 建议请求
     * @return 流式创作建议
     */
    @PostMapping(value = "/{novelId}/ai/suggest/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> getWritingSuggestionStream(
            @PathVariable String novelId,
            @RequestBody SuggestionRequest request) {
        return novelAIService.getWritingSuggestionStream(
                novelId,
                request.getSceneId(),
                request.getSuggestionType())
                .map(content -> ServerSentEvent.<String>builder()
                        .data(content)
                        .build());
    }
    
    /**
     * 修改内容
     * @param novelId 小说ID
     * @param request 修改请求
     * @return 修改后的内容
     */
    @PostMapping("/{novelId}/ai/revise")
    public Mono<AIResponse> reviseContent(
            @PathVariable String novelId,
            @RequestBody RevisionRequest request) {
        return novelAIService.reviseContent(
                novelId,
                request.getSceneId(),
                request.getContent(),
                request.getInstruction());
    }
    
    /**
     * 修改内容（流式）
     * @param novelId 小说ID
     * @param request 修改请求
     * @return 流式修改后的内容
     */
    @PostMapping(value = "/{novelId}/ai/revise/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> reviseContentStream(
            @PathVariable String novelId,
            @RequestBody RevisionRequest request) {
        return novelAIService.reviseContentStream(
                novelId,
                request.getSceneId(),
                request.getContent(),
                request.getInstruction())
                .map(content -> ServerSentEvent.<String>builder()
                        .data(content)
                        .build());
    }
    
    /**
     * 生成角色
     * @param novelId 小说ID
     * @param description 角色描述
     * @return 生成的角色信息
     */
    @PostMapping("/{novelId}/ai/generate-character")
    public Mono<AIResponse> generateCharacter(
            @PathVariable String novelId,
            @RequestParam String description) {
        return novelAIService.generateCharacter(novelId, description);
    }
    
    /**
     * 生成情节
     * @param novelId 小说ID
     * @param description 情节描述
     * @return 生成的情节信息
     */
    @PostMapping("/{novelId}/ai/generate-plot")
    public Mono<AIResponse> generatePlot(
            @PathVariable String novelId,
            @RequestParam String description) {
        return novelAIService.generatePlot(novelId, description);
    }
    
    /**
     * 生成设定
     * @param novelId 小说ID
     * @param description 设定描述
     * @return 生成的设定信息
     */
    @PostMapping("/{novelId}/ai/generate-setting")
    public Mono<AIResponse> generateSetting(
            @PathVariable String novelId,
            @RequestParam String description) {
        return novelAIService.generateSetting(novelId, description);
    }
} 