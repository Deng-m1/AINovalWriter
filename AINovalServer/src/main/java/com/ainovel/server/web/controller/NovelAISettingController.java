package com.ainovel.server.web.controller;

import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.domain.model.User;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.web.dto.request.GenerateSettingsRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/v1/novels/{novelId}/ai")
@RequiredArgsConstructor
@Tag(name = "Novel AI Setting", description = "小说 AI 设定生成相关 API")
public class NovelAISettingController {

    private final NovelAIService novelAIService;

    @PostMapping("/generate-settings")
    @Operation(summary = "AI 生成小说设定条目",
               description = "根据指定的章节范围和设定类型，使用 AI 生成小说设定条目建议。",
               responses = {
                   @ApiResponse(responseCode = "200", description = "成功生成设定建议",
                                content = @Content(mediaType = "application/json",
                                                   schema = @Schema(type = "array", implementation = NovelSettingItem.class))),
                   @ApiResponse(responseCode = "400", description = "请求参数无效"),
                   @ApiResponse(responseCode = "401", description = "用户未认证"),
                   @ApiResponse(responseCode = "403", description = "用户无权限操作该小说"),
                   @ApiResponse(responseCode = "404", description = "小说或章节未找到"),
                   @ApiResponse(responseCode = "500", description = "服务器内部错误或 AI 服务调用失败")
               })
    public Mono<ResponseEntity<List<NovelSettingItem>>> generateSettings(
            @Parameter(description = "小说ID", required = true) @PathVariable String novelId,
            @Parameter(description = "当前登录用户", hidden = true) @AuthenticationPrincipal User currentUser,
            @Parameter(description = "生成设定请求参数", required = true) @Valid @RequestBody GenerateSettingsRequest request) {
        
        if (currentUser == null) {
            log.warn("Attempt to generate settings without authentication for novelId: {}", novelId);
            return Mono.just(ResponseEntity.status(401).build());
        }
        log.info("User {} requesting AI setting generation for novel {}", currentUser.getUsername(), novelId);

        return novelAIService.generateNovelSettings(novelId, currentUser.getId(), request)
                .map(ResponseEntity::ok)
                .doOnError(e -> log.error("Error generating AI settings for novel {}: {}", novelId, e.getMessage(), e))
                .onErrorResume(IllegalArgumentException.class, e ->
                    Mono.just(ResponseEntity.badRequest().build())) // Simplified error handling for brevity
                .onErrorResume(RuntimeException.class, e -> // Catch other runtime errors from service
                    Mono.just(ResponseEntity.status(500).build()));
    }
} 