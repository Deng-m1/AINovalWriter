package com.ainovel.server.web.controller;

import java.time.Duration;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.security.CurrentUser;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryRequest;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryResponse;
import com.ainovel.server.web.dto.SummarizeSceneRequest;
import com.ainovel.server.web.dto.SummarizeSceneResponse;

import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * AI生成控制器
 * 提供场景摘要互转相关API
 */
@Slf4j
@RestController
@RequestMapping("/api/ai")
public class AIGenerationController extends ReactiveBaseController {
    
    private final NovelAIService novelAIService;
    
    @Autowired
    public AIGenerationController(NovelAIService novelAIService) {
        this.novelAIService = novelAIService;
    }
    
    /**
     * 为指定场景生成摘要
     *
     * @param currentUser 当前用户
     * @param sceneId 场景ID
     * @param request 摘要请求
     * @return 摘要响应
     */
    @PostMapping("/scenes/{sceneId}/summarize")
    public Mono<SummarizeSceneResponse> summarizeScene(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String sceneId,
            @RequestBody(required = false) SummarizeSceneRequest request) {
        
        log.info("场景生成摘要请求, userId: {}, sceneId: {}", currentUser.getId(), sceneId);
        
        // 如果请求为null，创建一个空请求
        if (request == null) {
            request = new SummarizeSceneRequest();
        }
        
        return novelAIService.summarizeScene(currentUser.getId(), sceneId, request);
    }
    
    /**
     * 根据摘要生成场景内容（流式）
     *
     * @param currentUser 当前用户
     * @param novelId 小说ID
     * @param requestMono 生成场景请求
     * @return 流式生成内容
     */
    @PostMapping(
            value = "/novels/{novelId}/scenes/generate-from-summary",
            produces = MediaType.TEXT_EVENT_STREAM_VALUE
    )
    public Flux<ServerSentEvent<String>> generateSceneFromSummaryStream(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String novelId,
            @Valid @RequestBody Mono<GenerateSceneFromSummaryRequest> requestMono) {
        
        log.info("摘要生成场景内容请求(流式), userId: {}, novelId: {}", currentUser.getId(), novelId);
        
        return requestMono.flatMapMany(request ->
                novelAIService.generateSceneFromSummaryStream(currentUser.getId(), novelId, request)
                        .map(contentChunk -> ServerSentEvent.<String>builder()
                                .event("message")
                                .data(contentChunk)
                                .build())
                        // 添加心跳事件防止连接超时
                        .mergeWith(Flux.interval(Duration.ofSeconds(15))
                                .map(i -> ServerSentEvent.<String>builder()
                                        .comment("keepalive")
                                        .build()))
                        .onErrorResume(e -> {
                            // 处理流中的错误，发送错误事件
                            log.error("生成场景内容流时出错", e);
                            return Flux.just(ServerSentEvent.<String>builder()
                                    .event("error")
                                    .data("{\"error\": \"" + e.getMessage() + "\"}")
                                    .build());
                        })
                        // 发送完成事件
                        .concatWith(Flux.just(ServerSentEvent.<String>builder()
                                .event("complete")
                                .data("")
                                .build()))
        );
    }
    
    /**
     * 根据摘要生成场景内容（非流式）
     *
     * @param currentUser 当前用户
     * @param novelId 小说ID
     * @param request 生成场景请求
     * @return 生成场景响应
     */
    @PostMapping("/novels/{novelId}/scenes/generate-from-summary-sync")
    public Mono<GenerateSceneFromSummaryResponse> generateSceneFromSummary(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String novelId,
            @Valid @RequestBody GenerateSceneFromSummaryRequest request) {
        
        log.info("摘要生成场景内容请求(非流式), userId: {}, novelId: {}", currentUser.getId(), novelId);
        
        return novelAIService.generateSceneFromSummary(currentUser.getId(), novelId, request);
    }
} 