package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.service.ai.AIModelProvider;
import com.ainovel.server.service.UserAIModelConfigService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryParameters;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryResult;
import com.ainovel.server.task.service.RateLimiterService;
import com.ainovel.server.web.dto.SummarizeSceneRequest;
import com.ainovel.server.web.dto.SummarizeSceneResponse;
import com.ainovel.server.domain.model.UserAIModelConfig;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Component;

import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Instant;

/**
 * 生成场景摘要任务执行器 (响应式)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GenerateSummaryTaskExecutable implements BackgroundTaskExecutable<GenerateSummaryParameters, GenerateSummaryResult> {

    private final SceneService sceneService;
    private final NovelAIService novelAIService;
    private final UserAIModelConfigService userAIModelConfigService;
    private final ReactiveMongoTemplate reactiveMongoTemplate;
    private final RateLimiterService rateLimiterService;

    @Override
    public Mono<GenerateSummaryResult> execute(TaskContext<GenerateSummaryParameters> context) {
        GenerateSummaryParameters parameters = context.getParameters();
        String sceneId = parameters.getSceneId();
        boolean useAIEnhancement = parameters.getUseAIEnhancement();
        String userId = context.getUserId();

        log.info("[任务:{}] 开始为场景 {} 生成摘要，用户ID: {}, 是否使用AI增强: {}", 
                context.getTaskId(), sceneId, userId, useAIEnhancement);

        return sceneService.findSceneById(sceneId)
            .switchIfEmpty(Mono.error(new IllegalStateException("场景不存在: " + sceneId)))
            .flatMap(scene -> {
                int actualVersion = scene.getVersion();
                String content = scene.getContent();

                if (content == null || content.trim().isEmpty()) {
                    log.error("[任务:{}] 场景 {} 内容为空，无法生成摘要", context.getTaskId(), sceneId);
                    return Mono.error(new IllegalArgumentException("场景内容为空，无法生成摘要"));
                }

                return getRateLimitKey(userId, useAIEnhancement)
                    .flatMap(rateLimitKey -> {
                        log.info("[任务:{}] 为AI服务调用申请限流许可: {}", context.getTaskId(), rateLimitKey);
                        
                        return rateLimiterService.acquirePermit(userId, rateLimitKey)
                            .flatMap(permitAcquired -> {
                                if (!permitAcquired) {
                                    log.error("[任务:{}] 获取{}的限流许可失败，任务将重试", context.getTaskId(), rateLimitKey);
                                    return Mono.error(new RuntimeException("获取AI服务限流许可失败，请稍后重试"));
                                }

                                SummarizeSceneRequest summarizeRequest = new SummarizeSceneRequest();
                                log.info("[任务:{}] 调用AI服务生成场景 {} 摘要", context.getTaskId(), sceneId);
                                
                                return novelAIService.summarizeScene(userId, sceneId, summarizeRequest)
                                    .switchIfEmpty(Mono.error(new RuntimeException("AI服务未返回有效摘要")))
                                    .flatMap(response -> {
                                        String generatedSummary = response.getSummary();
                                        if (generatedSummary == null || generatedSummary.trim().isEmpty()) {
                                            log.error("[任务:{}] 生成场景 {} 摘要失败: AI服务返回空摘要", context.getTaskId(), sceneId);
                                            return Mono.error(new RuntimeException("AI服务返回空摘要"));
                                        }
                                        log.info("[任务:{}] 场景 {} 摘要生成成功，长度: {}", context.getTaskId(), sceneId, generatedSummary.length());

                                        final String summary = generatedSummary;

                                        return updateSceneSummaryAtomic(sceneId, actualVersion, summary)
                                            .flatMap(updateSuccess -> {
                                                if (updateSuccess) {
                                                    return Mono.just(GenerateSummaryResult.builder()
                                                        .sceneId(sceneId)
                                                        .summary(summary)
                                                        .processingTimeMs(System.currentTimeMillis())
                                                        .completedAt(Instant.now())
                                                        .build());
                                                } else {
                                                    log.info("[任务:{}] 场景 {} 在生成摘要过程中被修改，将尝试基于最新版本更新", context.getTaskId(), sceneId);
                                                    return sceneService.findSceneById(sceneId)
                                                        .switchIfEmpty(Mono.error(new IllegalStateException("场景不存在: " + sceneId)))
                                                        .flatMap(latestScene -> 
                                                            updateSceneSummaryAtomic(sceneId, latestScene.getVersion(), summary)
                                                                .map(retrySuccess -> GenerateSummaryResult.builder()
                                                                    .sceneId(sceneId)
                                                                    .summary(summary)
                                                                    .processingTimeMs(System.currentTimeMillis())
                                                                    .completedAt(Instant.now())
                                                                    .build()
                                                                )
                                                        );
                                                }
                                            });
                                    })
                                    .doFinally(signalType -> {
                                        // 释放许可
                                        rateLimiterService.releasePermit(userId, rateLimitKey).subscribe();
                                    });
                            });
                    });
            });
    }

    private Mono<Boolean> updateSceneSummaryAtomic(String sceneId, int expectedVersion, String summary) {
        Query query = Query.query(Criteria.where("_id").is(sceneId)
                .and("version").is(expectedVersion));
        
        Update update = new Update()
                .set("summary", summary)
                .inc("version", 1);
        
        return reactiveMongoTemplate.updateFirst(query, update, Scene.class)
                .map(updateResult -> updateResult.getModifiedCount() > 0)
                .onErrorResume(OptimisticLockingFailureException.class, e -> {
                    log.warn("原子更新场景 {} 摘要时发生乐观锁冲突 (期望版本: {})", sceneId, expectedVersion);
                    return Mono.just(false);
                })
                .onErrorResume(e -> {
                    log.error("原子更新场景 {} 摘要时发生其他错误", sceneId, e);
                    return Mono.just(false);
                });
    }
    
    private Mono<String> getRateLimitKey(String userId, boolean useAIEnhancement) {
        if (useAIEnhancement) {
            return userAIModelConfigService.getFirstValidatedConfiguration(userId)
                .map(UserAIModelConfig::getModelName)
                .defaultIfEmpty("default_model")
                .map(modelName -> "ai_provider_" + modelName);
        } else {
            return Mono.just("ai_provider_default");
        }
    }

    @Override
    public String getTaskType() {
        return "GENERATE_SUMMARY";
    }
}