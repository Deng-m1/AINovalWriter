package com.ainovel.server.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.security.CurrentUser;
import com.ainovel.server.service.UserPromptService;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.UpdatePromptRequest;
import com.ainovel.server.web.dto.UserPromptTemplateDto;

import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户提示词控制器 提供用户提示词模板管理的API接口
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/api/users/me/prompts")
public class UserPromptController extends ReactiveBaseController {

    private final UserPromptService userPromptService;

    @Autowired
    public UserPromptController(UserPromptService userPromptService) {
        this.userPromptService = userPromptService;
    }

    /**
     * 获取当前用户的所有自定义提示词
     *
     * @param currentUser 当前用户
     * @return 自定义提示词列表
     */
    @GetMapping
    public Flux<UserPromptTemplateDto> getUserCustomPrompts(@AuthenticationPrincipal CurrentUser currentUser) {
        log.info("获取用户自定义提示词, userId: {}", currentUser.getId());

        return userPromptService.getUserCustomPrompts(currentUser.getId())
                .map(UserPromptTemplateDto::fromEntity);
    }

    /**
     * 获取当前用户指定功能的提示词（如果自定义则返回自定义，否则返回默认）
     *
     * @param currentUser 当前用户
     * @param featureType 功能类型
     * @return 提示词模板
     */
    @GetMapping("/{featureType}")
    public Mono<UserPromptTemplateDto> getPromptTemplate(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String featureType) {
        log.info("获取用户提示词模板, userId: {}, featureType: {}", currentUser.getId(), featureType);

        // 将字符串转换为枚举类型
        AIFeatureType type;
        try {
            // 客户端传入的是枚举的后缀名，需要转换为UPPER_CASE格式
            switch (featureType) {
                case "sceneToSummary":
                    type = AIFeatureType.SCENE_TO_SUMMARY;
                    break;
                case "summaryToScene":
                    type = AIFeatureType.SUMMARY_TO_SCENE;
                    break;
                default:
                    // 如果是已经大写的格式
                    type = AIFeatureType.valueOf(featureType);
            }
        } catch (Exception e) {
            log.error("无效的功能类型: {}", featureType, e);
            return Mono.error(new IllegalArgumentException("无效的功能类型: " + featureType));
        }

        return userPromptService.getPromptTemplate(currentUser.getId(), type)
                .map(promptText -> new UserPromptTemplateDto(type, promptText));
    }

    /**
     * 创建或更新当前用户指定功能的自定义提示词
     *
     * @param currentUser 当前用户
     * @param featureType 功能类型
     * @param request 更新请求
     * @return 更新后的提示词模板
     */
    @PutMapping("/{featureType}")
    public Mono<UserPromptTemplateDto> saveOrUpdatePrompt(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String featureType,
            @Valid @RequestBody Mono<UpdatePromptRequest> request) {

        return request.flatMap(req -> {
            log.info("保存或更新用户提示词, userId: {}, featureType: {}", currentUser.getId(), featureType);

            // 将字符串转换为枚举类型
            AIFeatureType type;
            try {
                // 客户端传入的是枚举的后缀名，需要转换为UPPER_CASE格式
                switch (featureType) {
                    case "sceneToSummary":
                        type = AIFeatureType.SCENE_TO_SUMMARY;
                        break;
                    case "summaryToScene":
                        type = AIFeatureType.SUMMARY_TO_SCENE;
                        break;
                    default:
                        // 如果是已经大写的格式
                        type = AIFeatureType.valueOf(featureType);
                }
            } catch (Exception e) {
                log.error("无效的功能类型: {}", featureType, e);
                return Mono.error(new IllegalArgumentException("无效的功能类型: " + featureType));
            }

            return userPromptService.saveOrUpdateUserPrompt(
                    currentUser.getId(), type, req.getPromptText())
                    .map(UserPromptTemplateDto::fromEntity);
        });
    }

    /**
     * 删除当前用户指定功能的自定义提示词（恢复为默认）
     *
     * @param currentUser 当前用户
     * @param featureType 功能类型
     * @return 无内容响应
     */
    @DeleteMapping("/{featureType}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deletePrompt(
            @AuthenticationPrincipal CurrentUser currentUser,
            @PathVariable String featureType) {
        log.info("删除用户提示词, userId: {}, featureType: {}", currentUser.getId(), featureType);

        // 将字符串转换为枚举类型
        AIFeatureType type;
        try {
            // 客户端传入的是枚举的后缀名，需要转换为UPPER_CASE格式
            switch (featureType) {
                case "sceneToSummary":
                    type = AIFeatureType.SCENE_TO_SUMMARY;
                    break;
                case "summaryToScene":
                    type = AIFeatureType.SUMMARY_TO_SCENE;
                    break;
                default:
                    // 如果是已经大写的格式
                    type = AIFeatureType.valueOf(featureType);
            }
        } catch (Exception e) {
            log.error("无效的功能类型: {}", featureType, e);
            return Mono.error(new IllegalArgumentException("无效的功能类型: " + featureType));
        }

        return userPromptService.deleteUserPrompt(currentUser.getId(), type);
    }
}
