package com.ainovel.server.web.controller;

import com.ainovel.server.service.NextOutlineService;
import com.ainovel.server.web.dto.NextOutlineDTO;
import com.ainovel.server.web.dto.OutlineGenerationChunk;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import jakarta.validation.Valid;

import java.time.Duration;
import java.util.UUID;

/**
 * 剧情推演控制器
 */
@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/novels/{novelId}/next-outlines")
public class NextOutlineController {

    private final NextOutlineService nextOutlineService;
    private static final String SSE_EVENT_NAME = "outline-chunk";

    /**
     * 生成剧情大纲
     *
     * @param novelId 小说ID
     * @param request 生成请求
     * @return 生成的剧情大纲列表
     */
    @PostMapping("/generate")
    public Mono<ResponseEntity<NextOutlineDTO.GenerateResponse>> generateNextOutlines(
            @PathVariable String novelId,
            @Valid @RequestBody NextOutlineDTO.GenerateRequest request) {

        log.info("生成剧情大纲: novelId={}, startChapter={}, endChapter={}, numOptions={}",
                novelId, request.getStartChapterId(), request.getEndChapterId(), request.getNumOptions());

        long startTime = System.currentTimeMillis();

        return nextOutlineService.generateNextOutlines(novelId, request)
                .map(response -> {
                    long endTime = System.currentTimeMillis();
                    response.setGenerationTimeMs(endTime - startTime);
                    return ResponseEntity.ok(response);
                });
    }

    /**
     * 流式生成剧情大纲
     *
     * @param novelId 小说ID
     * @param request 生成请求
     * @return 流式生成的剧情大纲块 (OutlineGenerationChunk)
     */
    @PostMapping(value = "/generate-stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<OutlineGenerationChunk>> generateNextOutlinesStream(
            @PathVariable String novelId,
            @Valid @RequestBody NextOutlineDTO.GenerateRequest request) {

        log.info("请求流式生成剧情大纲: novelId={}, startChapter={}, endChapter={}, numOptions={}",
                novelId, request.getStartChapterId(), request.getEndChapterId(), request.getNumOptions());

        return nextOutlineService.generateNextOutlinesStream(novelId, request)
                .map(chunk -> ServerSentEvent.<OutlineGenerationChunk>builder()
                        .id(chunk.getOptionId() + "-" + UUID.randomUUID().toString())
                        .event(SSE_EVENT_NAME)
                        .data(chunk)
                        .retry(Duration.ofSeconds(10))
                        .build())
                .doOnSubscribe(subscription -> log.info("SSE 连接建立 for generate-stream, novelId: {}", novelId))
                .doOnCancel(() -> log.info("SSE 连接关闭 for generate-stream, novelId: {}", novelId))
                .doOnError(error -> log.error("SSE 流错误 for generate-stream, novelId: {}: {}", novelId, error.getMessage(), error));
    }
    
    /**
     * 重新生成单个剧情大纲选项 (流式)
     *
     * @param novelId 小说ID
     * @param request 重新生成请求
     * @return 流式生成的剧情大纲块 (OutlineGenerationChunk)
     */
    @PostMapping(value = "/regenerate-option", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<OutlineGenerationChunk>> regenerateOutlineOption(
            @PathVariable String novelId,
            @Valid @RequestBody NextOutlineDTO.RegenerateOptionRequest request) {

        log.info("请求流式重新生成单个剧情大纲: novelId={}, optionId={}, configId={}",
                novelId, request.getOptionId(), request.getSelectedConfigId());

        return nextOutlineService.regenerateOutlineOption(novelId, request)
                .map(chunk -> ServerSentEvent.<OutlineGenerationChunk>builder()
                        .id(chunk.getOptionId() + "-" + UUID.randomUUID().toString())
                        .event(SSE_EVENT_NAME)
                        .data(chunk)
                        .retry(Duration.ofSeconds(10))
                        .build())
                 .doOnSubscribe(subscription -> log.info("SSE 连接建立 for regenerate-option, novelId: {}, optionId: {}", novelId, request.getOptionId()))
                .doOnCancel(() -> log.info("SSE 连接关闭 for regenerate-option, novelId: {}, optionId: {}", novelId, request.getOptionId()))
                .doOnError(error -> log.error("SSE 流错误 for regenerate-option, novelId: {}, optionId: {}: {}", novelId, request.getOptionId(), error.getMessage(), error));
    }

    /**
     * 保存选中的剧情大纲
     *
     * @param novelId 小说ID
     * @param request 保存请求
     * @return 保存结果
     */
    @PostMapping("/save")
    public Mono<ResponseEntity<NextOutlineDTO.SaveResponse>> saveNextOutline(
            @PathVariable String novelId,
            @Valid @RequestBody NextOutlineDTO.SaveRequest request) {

        log.info("保存剧情大纲: novelId={}, outlineId={}", novelId, request.getOutlineId());

        return nextOutlineService.saveNextOutline(novelId, request)
                .map(ResponseEntity::ok);
    }
}
