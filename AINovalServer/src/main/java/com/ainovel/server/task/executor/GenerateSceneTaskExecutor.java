package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.GenerateSceneParameters;
import com.ainovel.server.task.dto.GenerateSceneResult;
import com.ainovel.server.task.service.RateLimiterService;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryRequest;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryResponse;

import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * 场景生成任务执行器
 * 负责调用AI服务生成场景内容并保存
 */
@Slf4j
@Component
public class GenerateSceneTaskExecutor implements BackgroundTaskExecutable<GenerateSceneParameters, GenerateSceneResult> {

    private final NovelAIService novelAIService;
    private final SceneService sceneService;
    private final RateLimiterService rateLimiterService;
    
    // 存储正在运行的任务状态，用于支持取消
    private final ConcurrentHashMap<String, AtomicBoolean> runningTasks = new ConcurrentHashMap<>();
    
    @Autowired
    public GenerateSceneTaskExecutor(
        NovelAIService novelAIService,
        SceneService sceneService,
        RateLimiterService rateLimiterService) {
        this.novelAIService = novelAIService;
        this.sceneService = sceneService;
        this.rateLimiterService = rateLimiterService;
    }
    
    @Override
    public String getTaskType() {
        return "GenerateSceneTask";
    }
    
    @Override
    public boolean isCancellable() {
        return true;
    }
    
    @Override
    public Mono<Void> cancel(TaskContext<?> context) {
        return Mono.fromRunnable(() -> {
            String taskId = context.getTaskId();
            AtomicBoolean cancellationFlag = runningTasks.get(taskId);
            
            if (cancellationFlag != null) {
                log.info("任务取消标记已设置: {}", taskId);
                cancellationFlag.set(true);
            } else {
                log.warn("找不到任务或任务已完成，无法取消: {}", taskId);
            }
        }).then();
    }
    
    @Override
    public int getEstimatedExecutionTimeSeconds(TaskContext<GenerateSceneParameters> context) {
        // 根据输入内容的复杂度估算执行时间
        GenerateSceneParameters params = context.getParameters();
        int summaryLength = params.getSummary() != null ? params.getSummary().length() : 0;
        
        if (summaryLength < 100) {
            return 30; // 短摘要估计30秒
        } else if (summaryLength < 500) {
            return 60; // 中等摘要估计60秒
        } else {
            return 120; // 长摘要估计120秒
        }
    }
    
    @Override
    public Mono<GenerateSceneResult> execute(TaskContext<GenerateSceneParameters> context) {
        String taskId = context.getTaskId();
        String userId = context.getUserId();
        GenerateSceneParameters params = context.getParameters();
        
        // 创建并注册取消标记
        AtomicBoolean cancellationFlag = new AtomicBoolean(false);
        runningTasks.put(taskId, cancellationFlag);
        
        log.info("开始执行场景生成任务: {}, 用户: {}, 场景ID: {}", 
                taskId, userId, params.getSceneId());
        
        return Mono.<GenerateSceneParameters>defer(() -> {
            // 进度更新 - 初始化
            Map<String, Object> initialProgress = new HashMap<>();
            initialProgress.put("status", "初始化中");
            initialProgress.put("progress", 0);
            return context.updateProgress(initialProgress)
                .then(Mono.just(params));
        })
        // 限流检查
        .flatMap(p -> rateLimiterService.acquirePermit(userId, "aiGeneration")
            .doOnNext(acquired -> {
                if (!acquired) {
                    log.warn("用户 {} 限流，需要等待", userId);
                }
            })
            .flatMap(acquired -> {
                if (acquired) {
                    return Mono.just(p);
                } else {
                    // 更新进度 - 排队中
                    Map<String, Object> queueProgress = new HashMap<>();
                    queueProgress.put("status", "在队列中等待");
                    queueProgress.put("progress", 0);
                    return context.updateProgress(queueProgress)
                        .then(rateLimiterService.waitForPermit(userId, "aiGeneration", Duration.ofMinutes(30)))
                        .thenReturn(p);
                }
            }))
        // 检查输入参数
        .flatMap(p -> {
            if (p.getSceneId() == null || p.getSceneId().isEmpty()) {
                return Mono.error(new IllegalArgumentException("场景ID不能为空"));
            }
            if (p.getNovelId() == null || p.getNovelId().isEmpty()) {
                return Mono.error(new IllegalArgumentException("小说ID不能为空"));
            }
            if (p.getSummary() == null || p.getSummary().isEmpty()) {
                return Mono.error(new IllegalArgumentException("场景摘要不能为空"));
            }
            
            // 更新进度 - 参数验证完成
            Map<String, Object> validatedProgress = new HashMap<>();
            validatedProgress.put("status", "参数验证完成");
            validatedProgress.put("progress", 10);
            return context.updateProgress(validatedProgress)
                .thenReturn(p);
        })
        // 获取现有场景信息
        .flatMap(p -> sceneService.getSceneById(p.getSceneId())
            .doOnNext(scene -> log.info("获取到现有场景信息: {}", scene.getId()))
            .flatMap(scene -> {
                // 检查取消标记
                if (cancellationFlag.get()) {
                    return Mono.error(new InterruptedException("任务已被取消"));
                }
                
                // 更新进度 - 准备生成
                Map<String, Object> prepareProgress = new HashMap<>();
                prepareProgress.put("status", "准备生成场景内容");
                prepareProgress.put("progress", 20);
                return context.updateProgress(prepareProgress)
                    .thenReturn(scene);
            }))
        // 调用AI服务生成场景内容
        .flatMap(scene -> {
            // 更新进度 - 生成中
            Map<String, Object> generatingProgress = new HashMap<>();
            generatingProgress.put("status", "AI正在生成场景内容");
            generatingProgress.put("progress", 30);
            
            return context.updateProgress(generatingProgress)
                .then(novelAIService.generateSceneFromSummary(
                    userId, 
                    params.getNovelId(),
                    createGenerateSceneRequest(params)
                ))
                .flatMap(response -> {
                    // 检查取消标记
                    if (cancellationFlag.get()) {
                        return Mono.error(new InterruptedException("任务已被取消"));
                    }
                    
                    // 更新进度 - 生成完成
                    Map<String, Object> generatedProgress = new HashMap<>();
                    generatedProgress.put("status", "场景内容生成完成");
                    generatedProgress.put("progress", 70);
                    
                    String generatedContent = response.getContent();
                    
                    return context.updateProgress(generatedProgress)
                        .thenReturn(Scene.builder()
                                .id(scene.getId())
                                .content(generatedContent)
                                .summary(params.getSummary())
                                .build()
                        );
                });
        })
        // 保存生成的内容到场景
        .flatMap(sceneToUpdate -> {
            // 更新进度 - 保存中
            Map<String, Object> savingProgress = new HashMap<>();
            savingProgress.put("status", "保存场景内容");
            savingProgress.put("progress", 80);
            
            return context.updateProgress(savingProgress)
                .then(sceneService.updateSceneContent(sceneToUpdate.getId(), sceneToUpdate.getContent(), userId))
                .doOnNext(savedScene -> log.info("场景内容已保存: {}", savedScene.getId()))
                .doOnError(e -> log.error("保存场景内容失败: {}", sceneToUpdate.getId(), e));
        })
        // 构建结果
        .flatMap(savedScene -> {
            // 更新进度 - 完成
            Map<String, Object> completeProgress = new HashMap<>();
            completeProgress.put("status", "任务完成");
            completeProgress.put("progress", 100);
            
            GenerateSceneResult result = new GenerateSceneResult();
            result.setSceneId(savedScene.getId());
            result.setNovelId(params.getNovelId());
            result.setContent(savedScene.getContent());
            result.setWordCount(countWords(savedScene.getContent()));
            
            return context.updateProgress(completeProgress)
                .thenReturn(result);
        })
        // 最终清理工作
        .doFinally(signalType -> {
            log.info("场景生成任务结束: {}, 信号: {}", taskId, signalType);
            runningTasks.remove(taskId);
        })
        // 记录错误并确保错误被正确传播
        .onErrorResume(e -> {
            log.error("场景生成任务失败: {}", taskId, e);
            
            // 更新进度 - 错误
            Map<String, Object> errorProgress = new HashMap<>();
            errorProgress.put("status", "任务失败");
            errorProgress.put("error", e.getMessage());
            errorProgress.put("progress", -1);
            
            return context.updateProgress(errorProgress)
                .then(Mono.error(e));
        })
        // 使用有界弹性调度器避免阻塞WebFlux线程
        .subscribeOn(Schedulers.boundedElastic());
    }
    
    /**
     * 创建场景生成请求
     */
    private GenerateSceneFromSummaryRequest createGenerateSceneRequest(GenerateSceneParameters params) {
        GenerateSceneFromSummaryRequest request = new GenerateSceneFromSummaryRequest();
        request.setSummary(params.getSummary());
        request.setSceneId(params.getSceneId());
        request.setStyle(params.getStyle());
        request.setLength(params.getLength());
        request.setTone(params.getTone());
        request.setAdditionalInstructions(params.getAdditionalInstructions());
        return request;
    }
    
    /**
     * 计算字数
     */
    private int countWords(String content) {
        if (content == null || content.isEmpty()) {
            return 0;
        }
        // 简单的字数统计方法（中文每个字算一个词，英文按空格分词）
        String[] words = content.replaceAll("[，。！？：；\"\"\n\r]", " ").split("\\s+");
        int chineseWordCount = 0;
        for (char c : content.toCharArray()) {
            if (isChinese(c)) {
                chineseWordCount++;
            }
        }
        int englishWordCount = 0;
        for (String word : words) {
            if (!word.isEmpty() && !containsChinese(word)) {
                englishWordCount++;
            }
        }
        return chineseWordCount + englishWordCount;
    }
    
    private boolean isChinese(char c) {
        return c >= 0x4E00 && c <= 0x9FA5;
    }
    
    private boolean containsChinese(String str) {
        for (char c : str.toCharArray()) {
            if (isChinese(c)) {
                return true;
            }
        }
        return false;
    }
} 