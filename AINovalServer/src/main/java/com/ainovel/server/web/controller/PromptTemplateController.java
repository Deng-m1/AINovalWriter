package com.ainovel.server.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.OptimizationStyle;
import com.ainovel.server.security.CurrentUser;
import com.ainovel.server.service.PromptTemplateService;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.*;

import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 提示词模板控制器
 * 提供提示词模板管理和优化的API接口
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/api/users/me/prompt-templates")
public class PromptTemplateController extends ReactiveBaseController {

    private final PromptTemplateService promptTemplateService;

    @Autowired
    public PromptTemplateController(PromptTemplateService promptTemplateService) {
        this.promptTemplateService = promptTemplateService;
    }

    /**
     * 获取提示词模板列表
     *
     * @param currentUser 当前用户
     * @param type 模板类型（ALL, PUBLIC, PRIVATE, FAVORITE，默认为ALL）
     * @param featureType 功能类型（可选）
     * @return 提示词模板列表
     */
    @GetMapping
    public Flux<PromptTemplateDto> getPromptTemplates(
            @AuthenticationPrincipal CurrentUser currentUser,
            @RequestParam(required = false, defaultValue = "ALL") String type,
            @RequestParam(required = false) String featureType) {
        
        log.info("获取提示词模板列表, userId: {}, type: {}, featureType: {}", 
                currentUser.getId(), type, featureType);
        
        if (featureType != null && !featureType.isEmpty()) {
            AIFeatureType aiFeatureType = convertToAIFeatureType(featureType);
            return promptTemplateService.getPromptTemplatesByFeatureType(
                    currentUser.getId(), aiFeatureType, type)
                    .map(PromptTemplateDto::fromEntity);
        } else {
            return promptTemplateService.getPromptTemplates(currentUser.getId(), type)
                    .map(PromptTemplateDto::fromEntity);
        }
    }

    /**
     * 获取提示词模板详情
     *
     * @param currentUser 当前用户
     * @param templateId 模板ID
     * @return 提示词模板详情
     */
    @GetMapping("/{templateId}")
    public Mono<PromptTemplateDto> getPromptTemplateById(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String templateId) {
        
        log.info("获取提示词模板详情, userId: {}, templateId: {}", 
                currentUser.getId(), templateId);
        
        return promptTemplateService.getPromptTemplateById(currentUser.getId(), templateId)
                .map(PromptTemplateDto::fromEntity);
    }

    /**
     * 创建提示词模板
     *
     * @param currentUser 当前用户
     * @param request 创建请求
     * @return 创建的提示词模板
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<PromptTemplateDto> createPromptTemplate(
            @AuthenticationPrincipal CurrentUser currentUser,
            @Valid @RequestBody Mono<CreatePromptTemplateRequest> request) {
        
        return request.flatMap(req -> {
            log.info("创建提示词模板, userId: {}, name: {}", 
                    currentUser.getId(), req.getName());
            
            AIFeatureType featureType = convertToAIFeatureType(req.getFeatureType());
            
            return promptTemplateService.createPromptTemplate(
                    currentUser.getId(), 
                    req.getName(), 
                    req.getContent(), 
                    featureType)
                    .map(PromptTemplateDto::fromEntity);
        });
    }

    /**
     * 更新提示词模板
     *
     * @param currentUser 当前用户
     * @param templateId 模板ID
     * @param request 更新请求
     * @return 更新后的提示词模板
     */
    @PutMapping("/{templateId}")
    public Mono<PromptTemplateDto> updatePromptTemplate(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String templateId,
            @Valid @RequestBody Mono<UpdatePromptTemplateRequest> request) {
        
        return request.flatMap(req -> {
            log.info("更新提示词模板, userId: {}, templateId: {}", 
                    currentUser.getId(), templateId);
            
            return promptTemplateService.updatePromptTemplate(
                    currentUser.getId(), 
                    templateId, 
                    req.getName(), 
                    req.getContent())
                    .map(PromptTemplateDto::fromEntity);
        });
    }

    /**
     * 删除提示词模板
     *
     * @param currentUser 当前用户
     * @param templateId 模板ID
     * @return 无内容响应
     */
    @DeleteMapping("/{templateId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deletePromptTemplate(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String templateId) {
        
        log.info("删除提示词模板, userId: {}, templateId: {}", 
                currentUser.getId(), templateId);
        
        return promptTemplateService.deletePromptTemplate(currentUser.getId(), templateId);
    }

    /**
     * 从公共模板复制创建私有模板
     *
     * @param currentUser 当前用户
     * @param templateId 公共模板ID
     * @return 新创建的私有模板
     */
    @PostMapping("/copy/{templateId}")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<PromptTemplateDto> copyPublicTemplate(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String templateId) {
        
        log.info("复制公共模板, userId: {}, templateId: {}", 
                currentUser.getId(), templateId);
        
        return promptTemplateService.copyPublicTemplate(currentUser.getId(), templateId)
                .map(PromptTemplateDto::fromEntity);
    }

    /**
     * 切换模板收藏状态
     *
     * @param currentUser 当前用户
     * @param templateId 模板ID
     * @return 更新后的模板
     */
    @PostMapping("/{templateId}/favorite")
    public Mono<PromptTemplateDto> toggleTemplateFavorite(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String templateId) {
        
        log.info("切换模板收藏状态, userId: {}, templateId: {}", 
                currentUser.getId(), templateId);
        
        return promptTemplateService.toggleTemplateFavorite(currentUser.getId(), templateId)
                .map(PromptTemplateDto::fromEntity);
    }

    /**
     * 优化提示词
     *
     * @param currentUser 当前用户
     * @param templateId 模板ID (如果为空表示不保存)
     * @param request 优化请求
     * @return 优化结果
     */
    @PostMapping("/{templateId}/optimize")
    public Mono<OptimizationResultDto> optimizePromptTemplate(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String templateId,
            @Valid @RequestBody Mono<OptimizePromptRequest> request) {
        
        return request.flatMap(req -> {
            log.info("优化提示词模板, userId: {}, templateId: {}", 
                    currentUser.getId(), templateId);
            
            OptimizationStyle style = convertToOptimizationStyle(req.getStyle());
            
            return promptTemplateService.optimizePromptTemplate(
                    currentUser.getId(), 
                    templateId, 
                    req.getContent(), 
                    style, 
                    req.getPreserveRatio())
                    .map(OptimizationResultDto::fromEntity);
        });
    }

    /**
     * 优化提示词 (无关联模板)
     *
     * @param currentUser 当前用户
     * @param request 优化请求
     * @return 优化结果
     */
    @PostMapping("/optimize")
    public Mono<OptimizationResultDto> optimizePrompt(
            @AuthenticationPrincipal CurrentUser currentUser,
            @Valid @RequestBody Mono<OptimizePromptRequest> request) {
        
        return request.flatMap(req -> {
            log.info("优化提示词, userId: {}", currentUser.getId());
            
            OptimizationStyle style = convertToOptimizationStyle(req.getStyle());
            
            return promptTemplateService.optimizePrompt(
                    currentUser.getId(), 
                    req.getContent(), 
                    style, 
                    req.getPreserveRatio())
                    .map(OptimizationResultDto::fromEntity);
        });
    }

    /**
     * 流式优化提示词模板
     *
     * @param currentUser 当前用户
     * @param templateId 模板ID
     * @param request 优化请求
     * @return 流式优化结果
     */
    @PostMapping(value = "/{templateId}/optimize-stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<OptimizationResultDto>> optimizePromptTemplateStream(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String templateId,
            @Valid @RequestBody Mono<OptimizePromptRequest> request) {
        
        return request.flatMapMany(req -> {
            log.info("流式优化提示词模板, userId: {}, templateId: {}", 
                    currentUser.getId(), templateId);
            
            OptimizationStyle style = convertToOptimizationStyle(req.getStyle());
            
            return promptTemplateService.optimizePromptTemplateStream(
                    currentUser.getId(), 
                    templateId, 
                    req.getContent(), 
                    style, 
                    req.getPreserveRatio())
                    .map(result -> ServerSentEvent.<OptimizationResultDto>builder()
                            .data(OptimizationResultDto.fromEntity(result))
                            .build());
        });
    }

    /**
     * 流式优化提示词 (无关联模板)
     *
     * @param currentUser 当前用户
     * @param request 优化请求
     * @return 流式优化结果
     */
    @PostMapping(value = "/optimize-stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<OptimizationResultDto>> optimizePromptStream(
            @AuthenticationPrincipal CurrentUser currentUser,
            @Valid @RequestBody Mono<OptimizePromptRequest> request) {
        
        return request.flatMapMany(req -> {
            log.info("流式优化提示词, userId: {}", currentUser.getId());
            
            OptimizationStyle style = convertToOptimizationStyle(req.getStyle());
            
            return promptTemplateService.optimizePromptStream(
                    currentUser.getId(), 
                    req.getContent(), 
                    style, 
                    req.getPreserveRatio())
                    .map(result -> ServerSentEvent.<OptimizationResultDto>builder()
                            .data(OptimizationResultDto.fromEntity(result))
                            .build());
        });
    }
    
    /**
     * 将字符串转换为AIFeatureType枚举
     */
    private AIFeatureType convertToAIFeatureType(String featureType) {
        try {
            switch (featureType) {
                case "sceneToSummary":
                    return AIFeatureType.SCENE_TO_SUMMARY;
                case "summaryToScene":
                    return AIFeatureType.SUMMARY_TO_SCENE;
                default:
                    return AIFeatureType.valueOf(featureType);
            }
        } catch (Exception e) {
            log.error("无效的功能类型: {}", featureType, e);
            throw new IllegalArgumentException("无效的功能类型: " + featureType);
        }
    }
    
    /**
     * 将字符串转换为OptimizationStyle枚举
     */
    private OptimizationStyle convertToOptimizationStyle(String style) {
        try {
            switch (style) {
                case "professional":
                    return OptimizationStyle.PROFESSIONAL;
                case "creative":
                    return OptimizationStyle.CREATIVE;
                case "concise":
                    return OptimizationStyle.CONCISE;
                default:
                    return OptimizationStyle.valueOf(style);
            }
        } catch (Exception e) {
            log.error("无效的优化风格: {}", style, e);
            throw new IllegalArgumentException("无效的优化风格: " + style);
        }
    }
} 