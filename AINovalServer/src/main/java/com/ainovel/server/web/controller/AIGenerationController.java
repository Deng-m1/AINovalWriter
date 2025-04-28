package com.ainovel.server.web.controller;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.GetMapping;

import com.ainovel.server.security.CurrentUser;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryRequest;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryResponse;
import com.ainovel.server.web.dto.SummarizeSceneRequest;
import com.ainovel.server.web.dto.SummarizeSceneResponse;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * AI生成控制器 提供场景摘要互转相关API
 */
@Slf4j
@RestController
@RequestMapping("/api/v1")
public class AIGenerationController extends ReactiveBaseController {

    private final NovelAIService novelAIService;
    private final ObjectMapper objectMapper;
    private final SceneService sceneService;
    private final NovelService novelService;
    
    // 用于存储摘要生成任务结果的缓存
    private final Map<String, SummarizeSceneResponse> summarizeTasks = new ConcurrentHashMap<>();

    @Autowired
    public AIGenerationController(NovelAIService novelAIService, ObjectMapper objectMapper,
                                 SceneService sceneService, NovelService novelService) {
        this.novelAIService = novelAIService;
        this.objectMapper = objectMapper;
        this.sceneService = sceneService;
        this.novelService = novelService;
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

        // 使用快速响应策略，不等待完整生成就返回
        // 生成一个唯一的任务ID
        String taskId = UUID.randomUUID().toString();
        
        // 立即返回处理中的响应，包含任务ID
        SummarizeSceneResponse processingResponse = new SummarizeSceneResponse();
        processingResponse.setSummary("摘要生成中，请稍候...");
        processingResponse.setTaskId(taskId);  // 假设已添加taskId字段
        processingResponse.setStatus("processing"); // 假设已添加status字段
        
        // 在后台异步执行实际生成任务
        final SummarizeSceneRequest finalRequest = request;
        novelAIService.summarizeScene(currentUser.getId(), sceneId, finalRequest)
                .doOnSubscribe(s -> log.info("开始后台生成场景摘要, userId: {}, sceneId: {}, taskId: {}", 
                        currentUser.getId(), sceneId, taskId))
                .doOnSuccess(response -> {
                    log.info("后台场景摘要生成成功, userId: {}, sceneId: {}, taskId: {}", 
                            currentUser.getId(), sceneId, taskId);
                    // 在这里可以保存结果到缓存或数据库
                    summarizeTasks.put(taskId, response);
                })
                .doOnError(e -> {
                    log.error("后台场景摘要生成失败, userId: {}, sceneId: {}, taskId: {}, 错误: {}", 
                            currentUser.getId(), sceneId, taskId, e.getMessage(), e);
                    // 保存错误状态
                    SummarizeSceneResponse errorResponse = new SummarizeSceneResponse();
                    errorResponse.setSummary("生成摘要时出错: " + e.getMessage());
                    errorResponse.setStatus("error");
                    summarizeTasks.put(taskId, errorResponse);
                })
                .subscribe(); // 触发异步执行但不阻塞当前请求
                
        // 立即返回处理中的响应
        return Mono.just(processingResponse);
    }
    
    /**
     * 查询摘要生成任务的状态
     *
     * @param currentUser 当前用户
     * @param taskId 任务ID
     * @return 摘要响应
     */
    @GetMapping("/scenes/summarize/tasks/{taskId}")
    public Mono<SummarizeSceneResponse> checkSummarizeTask(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String taskId) {
            
        log.info("查询摘要生成任务状态, userId: {}, taskId: {}", currentUser.getId(), taskId);
        
        SummarizeSceneResponse response = summarizeTasks.get(taskId);
        if (response == null) {
            // 任务不存在
            SummarizeSceneResponse notFoundResponse = new SummarizeSceneResponse();
            notFoundResponse.setSummary("找不到指定的任务");
            notFoundResponse.setStatus("not_found");
            return Mono.just(notFoundResponse);
        }
        
        return Mono.just(response);
    }

    /**
     * 为指定场景生成摘要（使用SSE流式响应）
     *
     * @param currentUser 当前用户
     * @param sceneId 场景ID
     * @param request 摘要请求
     * @return 流式生成内容
     */
    @PostMapping(
            value = "/scenes/{sceneId}/summarize-stream",
            produces = MediaType.TEXT_EVENT_STREAM_VALUE
    )
    public Flux<ServerSentEvent<String>> summarizeSceneStream(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String sceneId,
            @RequestBody(required = false) SummarizeSceneRequest requestBody) {

        log.info("场景生成摘要请求(流式), userId: {}, sceneId: {}", currentUser.getId(), sceneId);

        // 如果请求为null，创建一个空请求
        final SummarizeSceneRequest request = requestBody != null ? requestBody : new SummarizeSceneRequest();
        final long startTime = System.currentTimeMillis();
        final AtomicBoolean hasReceivedContent = new AtomicBoolean(false);
        final AtomicBoolean isStreamCompleted = new AtomicBoolean(false);
        final AtomicLong firstContentTime = new AtomicLong(0);

        // 创建单次调用的流式响应转换器
        return sceneService.findSceneById(sceneId)
                .flatMapMany(scene -> {
                    // 权限校验
                    return novelService.findNovelById(scene.getNovelId())
                            .flatMapMany(novel -> {
                                if (!novel.getAuthor().getId().equals(currentUser.getId())) {
                                    return Flux.error(new AccessDeniedException("用户无权访问该场景"));
                                }

                                // 构建生成摘要的Mono
                                Mono<SummarizeSceneResponse> summarizeMono = 
                                        novelAIService.summarizeScene(currentUser.getId(), sceneId, request);
                                
                                // 将Mono转换为Flux<String>，只包含一个元素（摘要内容）
                                Flux<String> contentFlux = summarizeMono
                                        .map(SummarizeSceneResponse::getSummary)
                                        .flux()
                                        .doOnNext(content -> {
                                            if (!hasReceivedContent.get()) {
                                                hasReceivedContent.set(true);
                                                firstContentTime.set(System.currentTimeMillis());
                                                log.info("接收到摘要内容, 耗时: {}ms", 
                                                        firstContentTime.get() - startTime);
                                            }
                                        })
                                        .concatWithValues("[DONE]")
                                        .onErrorResume(e -> {
                                            log.error("生成摘要出错: {}", e.getMessage(), e);
                                            return Flux.just("生成摘要时出错: " + e.getMessage(), "[DONE]");
                                        });

                                // 转换为ServerSentEvent
                                Flux<ServerSentEvent<String>> eventFlux = contentFlux
                                        .map(content -> {
                                            if ("[DONE]".equals(content)) {
                                                isStreamCompleted.set(true);
                                                log.info("摘要生成完成，发送完成事件，总耗时: {}ms", 
                                                        System.currentTimeMillis() - startTime);
                                                return ServerSentEvent.<String>builder()
                                                        .event("complete")
                                                        .data("{\"data\":\"[DONE]\"}")
                                                        .build();
                                            }

                                            try {
                                                Map<String, String> dataMap = new HashMap<>();
                                                dataMap.put("data", content);
                                                String jsonData = objectMapper.writeValueAsString(dataMap);

                                                return ServerSentEvent.<String>builder()
                                                        .event("message")
                                                        .data(jsonData)
                                                        .build();
                                            } catch (JsonProcessingException e) {
                                                log.error("序列化内容失败", e);
                                                return ServerSentEvent.<String>builder()
                                                        .event("error")
                                                        .data("{\"error\":\"内容序列化失败\"}")
                                                        .build();
                                            }
                                        });

                                // 创建keepalive流
                                Flux<ServerSentEvent<String>> keepaliveStream = Flux.interval(Duration.ofSeconds(15))
                                        .map(i -> {
                                            log.debug("发送SSE keepalive 注释 #{}", i);
                                            return ServerSentEvent.<String>builder()
                                                    .comment("keepalive")
                                                    .build();
                                        })
                                        .takeWhile(event -> !isStreamCompleted.get());

                                // 合并内容流和keepalive流
                                return Flux.merge(eventFlux, keepaliveStream)
                                        .timeout(Duration.ofMinutes(5))
                                        .onErrorResume(e -> {
                                            log.error("处理SSE流时出错: {}", e.getMessage(), e);
                                            try {
                                                isStreamCompleted.set(true);
                                                Map<String, String> errorMap = new HashMap<>();
                                                errorMap.put("error", e.getMessage());
                                                String jsonError = objectMapper.writeValueAsString(errorMap);
                                                return Flux.just(
                                                        ServerSentEvent.<String>builder()
                                                                .event("error")
                                                                .data(jsonError)
                                                                .build(),
                                                        ServerSentEvent.<String>builder()
                                                                .event("complete")
                                                                .data("{\"data\":\"[DONE]\"}")
                                                                .build()
                                                );
                                            } catch (JsonProcessingException jsonError) {
                                                return Flux.just(
                                                        ServerSentEvent.<String>builder()
                                                                .event("error")
                                                                .data("{\"error\":\"序列化错误信息失败\"}")
                                                                .build(),
                                                        ServerSentEvent.<String>builder()
                                                                .event("complete")
                                                                .data("{\"data\":\"[DONE]\"}")
                                                                .build()
                                                );
                                            }
                                        });
                            });
                })
                .doOnCancel(() -> {
                    log.info("客户端取消了SSE连接，总耗时: {}ms", System.currentTimeMillis() - startTime);
                });
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

        final long startTime = System.currentTimeMillis();

        return requestMono
                .doOnNext(request -> {
                    log.info("摘要长度: {}, 样式说明长度: {}, 章节ID: {}, userId: {}, novelId: {}",
                            request.getSummary().length(),
                            request.getAdditionalInstructions() != null ? request.getAdditionalInstructions().length() : 0,
                            request.getChapterId(),
                            currentUser.getId(),
                            novelId);
                })
                .flatMapMany(request -> {
                    final AtomicBoolean hasReceivedContent = new AtomicBoolean(false);
                    final AtomicBoolean isStreamCompleted = new AtomicBoolean(false);
                    final AtomicLong firstContentTime = new AtomicLong(0);

                    // 主内容流
                    Flux<ServerSentEvent<String>> contentStream = novelAIService.generateSceneFromSummaryStream(currentUser.getId(), novelId, request)
                            .filter(contentChunk -> {
                                // 过滤heartbeat消息 - NovelAIServiceImpl 现在应该已经过滤了，但双重保险
                                return !"heartbeat".equals(contentChunk);
                            })
                            .map(contentChunk -> {
                                try {
                                    if (!hasReceivedContent.get() && !"[DONE]".equals(contentChunk)) {
                                        hasReceivedContent.set(true);
                                        firstContentTime.set(System.currentTimeMillis());
                                        log.info("收到首个内容块，耗时: {}ms", firstContentTime.get() - startTime);
                                    }

                                    if ("[DONE]".equals(contentChunk)) {
                                        log.info("生成完成，发送完成事件，总耗时: {}ms", System.currentTimeMillis() - startTime);
                                        isStreamCompleted.set(true);
                                        return ServerSentEvent.<String>builder()
                                                .event("complete")
                                                .data("{\"data\":\"[DONE]\"}")
                                                .build();
                                    }

                                    Map<String, String> dataMap = new HashMap<>();
                                    dataMap.put("data", contentChunk);
                                    String jsonData = objectMapper.writeValueAsString(dataMap);

                                    return ServerSentEvent.<String>builder()
                                            .event("message")
                                            .data(jsonData)
                                            .build();
                                } catch (JsonProcessingException e) {
                                    log.error("序列化内容块失败", e);
                                    return ServerSentEvent.<String>builder() // 返回错误事件，而不是 null
                                            .event("error")
                                            .data("{\"error\":\"内容序列化失败\"}")
                                            .build();
                                }
                            });

                    // 添加监听器以跟踪流的完成状态 (这部分保留)
                    contentStream = contentStream.doOnNext(event -> {
                        if (event != null && event.event() != null && event.event().equals("complete")) {
                            isStreamCompleted.set(true);
                            log.debug("内容流已完成，将停止发送控制器心跳");
                        }
                    });

                    // **移除 gracePeriodStream **
                    // 创建简化的控制器级别心跳事件流 (仅用于保持连接)
                    Flux<ServerSentEvent<String>> keepaliveStream = Flux.interval(Duration.ofSeconds(15)) // 每15秒发送一次
                            .map(i -> {
                                log.debug("发送SSE keepalive 注释 #{}", i);
                                return ServerSentEvent.<String>builder()
                                        .comment("keepalive") // 使用 SSE 注释进行 keepalive
                                        .build();
                            })
                            // 只要主内容流没有完成，就继续发送 keepalive
                            .takeWhile(event -> !isStreamCompleted.get());

                    // **只合并内容流和控制器 keepalive 流**
                    return Flux.merge(contentStream, keepaliveStream)
                            .onErrorResume(e -> { // 保留现有的错误处理
                                log.error("生成场景内容流时出错: {}", e.getMessage(), e);
                                try {
                                    isStreamCompleted.set(true); // 出错时也标记为完成
                                    Map<String, String> errorMap = new HashMap<>();
                                    errorMap.put("error", e.getMessage());
                                    String jsonError = objectMapper.writeValueAsString(errorMap);
                                    return Flux.just(
                                            ServerSentEvent.<String>builder()
                                                    .event("error")
                                                    .data(jsonError)
                                                    .build(),
                                            ServerSentEvent.<String>builder()
                                                    .event("complete")
                                                    .data("{\"data\":\"[DONE]\"}")
                                                    .build()
                                    );
                                } catch (JsonProcessingException jsonError) {
                                    return Flux.just(
                                            ServerSentEvent.<String>builder()
                                                    .event("error")
                                                    .data("{\"error\":\"序列化错误信息失败\"}")
                                                    .build(),
                                            ServerSentEvent.<String>builder()
                                                    .event("complete")
                                                    .data("{\"data\":\"[DONE]\"}")
                                                    .build()
                                    );
                                }
                            })
                            .timeout(Duration.ofMinutes(5)) // 保留全局超时
                            .switchIfEmpty(Mono.just( // 保留空流处理
                                    ServerSentEvent.<String>builder()
                                            .event("complete")
                                            .data("{\"data\":\"[DONE]\"}")
                                            .build()))
                            .concatWith(Mono.defer(() -> { // 保留备用完成事件
                                if (!isStreamCompleted.get()) {
                                    log.info("添加备用完成事件，确保流正确关闭");
                                    return Mono.just(ServerSentEvent.<String>builder()
                                            .event("complete")
                                            .data("{\"data\":\"[DONE]\"}")
                                            .build());
                                }
                                return Mono.empty();
                            }));
                })
                .doOnCancel(() -> {
                    log.info("客户端取消了SSE连接，总耗时: {}ms", System.currentTimeMillis() - startTime);
                    // 注意：这里的取消是客户端发起的，与之前的10秒超时不同
                })
                .doOnError(e -> {
                    log.error("处理SSE流时发生顶层错误: {}", e.getMessage(), e);
                });
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
