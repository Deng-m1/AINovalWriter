package com.ainovel.server.task.executor;

import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.GenerateSummaryParameters;
import com.ainovel.server.task.dto.GenerateSummaryResult;
import com.ainovel.server.task.service.RateLimiterService;
import com.ainovel.server.web.dto.SummarizeSceneRequest;
import com.ainovel.server.web.dto.SummarizeSceneResponse;

import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * 场景摘要生成任务执行器
 * 负责调用AI服务为场景生成摘要
 */
@Slf4j
@Component
public class GenerateSummaryTaskExecutor implements BackgroundTaskExecutable<GenerateSummaryParameters, GenerateSummaryResult> {

    private final NovelAIService novelAIService;
    private final SceneService sceneService;
    private final RateLimiterService rateLimiterService;
    
    // 存储正在运行的任务状态，用于支持取消
    private final ConcurrentHashMap<String, AtomicBoolean> runningTasks = new ConcurrentHashMap<>();
    
    @Autowired
    public GenerateSummaryTaskExecutor(
        NovelAIService novelAIService,
        SceneService sceneService,
        RateLimiterService rateLimiterService) {
        this.novelAIService = novelAIService;
        this.sceneService = sceneService;
        this.rateLimiterService = rateLimiterService;
    }
    
    @Override
    public String getTaskType() {
        return "GenerateSummaryTask";
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
    public int getEstimatedExecutionTimeSeconds(TaskContext<GenerateSummaryParameters> context) {
        return 30; // 摘要生成通常较快，预估30秒
    }
    
    @Override
    public Mono<GenerateSummaryResult> execute(TaskContext<GenerateSummaryParameters> context) {
        String taskId = context.getTaskId();
        String userId = context.getUserId();
        GenerateSummaryParameters params = context.getParameters();
        
        // 创建并注册取消标记
        AtomicBoolean cancellationFlag = new AtomicBoolean(false);
        runningTasks.put(taskId, cancellationFlag);
        
        Instant startTime = Instant.now();
        
        log.info("开始执行场景摘要生成任务: {}, 用户: {}, 场景ID: {}", 
                taskId, userId, params.getSceneId());
        
        return Mono.<GenerateSummaryParameters>defer(() -> {
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
                        .then(rateLimiterService.waitForPermit(userId, "aiGeneration", Duration.ofMinutes(5)))
                        .thenReturn(p);
                }
            }))
        // 检查输入参数
        .flatMap(p -> {
            if (p.getSceneId() == null || p.getSceneId().isEmpty()) {
                return Mono.error(new IllegalArgumentException("场景ID不能为空"));
            }
            
            // 更新进度 - 参数验证完成
            Map<String, Object> validatedProgress = new HashMap<>();
            validatedProgress.put("status", "参数验证完成");
            validatedProgress.put("progress", 20);
            return context.updateProgress(validatedProgress)
                .thenReturn(p);
        })
        // 获取场景内容
        .flatMap(p -> sceneService.getSceneById(p.getSceneId())
            .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到指定场景: " + p.getSceneId())))
            .doOnNext(scene -> log.info("获取到场景信息: {}, 内容长度: {}", 
                    scene.getId(), scene.getContent() != null ? scene.getContent().length() : 0))
            .flatMap(scene -> {
                // 检查取消标记
                if (cancellationFlag.get()) {
                    return Mono.error(new InterruptedException("任务已被取消"));
                }
                
                if (scene.getContent() == null || scene.getContent().trim().isEmpty()) {
                    return Mono.error(new IllegalArgumentException("场景内容为空，无法生成摘要"));
                }
                
                // 更新进度 - 准备生成
                Map<String, Object> prepareProgress = new HashMap<>();
                prepareProgress.put("status", "准备生成场景摘要");
                prepareProgress.put("progress", 40);
                return context.updateProgress(prepareProgress)
                    .thenReturn(scene);
            }))
        // 调用AI服务生成摘要
        .flatMap(scene -> {
            // 更新进度 - 生成中
            Map<String, Object> generatingProgress = new HashMap<>();
            generatingProgress.put("status", "AI正在生成场景摘要");
            generatingProgress.put("progress", 60);
            
            return context.updateProgress(generatingProgress)
                .then(novelAIService.summarizeScene(
                    userId, 
                    scene.getId(),
                    createSummarizeSceneRequest(scene.getContent(), params)
                ))
                .flatMap(response -> {
                    // 检查取消标记
                    if (cancellationFlag.get()) {
                        return Mono.error(new InterruptedException("任务已被取消"));
                    }
                    
                    // 更新进度 - 生成完成
                    Map<String, Object> generatedProgress = new HashMap<>();
                    generatedProgress.put("status", "场景摘要生成完成");
                    generatedProgress.put("progress", 80);
                    
                    String summary = response.getSummary();
                    
                    return context.updateProgress(generatedProgress)
                        .thenReturn(Mono.zip(
                            Mono.just(scene),
                            Mono.just(summary)
                        ));
                })
                .flatMap(tupleMonoResult -> tupleMonoResult);
        })
        // 保存摘要到场景
        .flatMap(tuple -> {
            var scene = tuple.getT1();
            var summary = tuple.getT2();
            
            // 更新进度 - 保存中
            Map<String, Object> savingProgress = new HashMap<>();
            savingProgress.put("status", "保存场景摘要");
            savingProgress.put("progress", 90);
            
            return context.updateProgress(savingProgress)
                .then(sceneService.updateSceneSummary(scene.getId(), summary, userId))
                .doOnNext(savedScene -> log.info("场景摘要已保存: {}", savedScene.getId()))
                .doOnError(e -> log.error("保存场景摘要失败: {}", scene.getId(), e))
                .thenReturn(summary);
        })
        // 构建结果
        .flatMap(summary -> {
            // 更新进度 - 完成
            Map<String, Object> completeProgress = new HashMap<>();
            completeProgress.put("status", "任务完成");
            completeProgress.put("progress", 100);
            
            Instant endTime = Instant.now();
            long executionTimeMs = Duration.between(startTime, endTime).toMillis();
            
            GenerateSummaryResult result = new GenerateSummaryResult();
            result.setSceneId(params.getSceneId());
            result.setSummary(summary);
            result.setWordCount(countWords(summary));
            result.setGenerationTimeMs(executionTimeMs);
            
            return context.updateProgress(completeProgress)
                .thenReturn(result);
        })
        // 最终清理工作
        .doFinally(signalType -> {
            log.info("场景摘要生成任务结束: {}, 信号: {}", taskId, signalType);
            runningTasks.remove(taskId);
        })
        // 记录错误并确保错误被正确传播
        .onErrorResume(e -> {
            log.error("场景摘要生成任务失败: {}", taskId, e);
            
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
     * 创建场景摘要请求
     */
    private SummarizeSceneRequest createSummarizeSceneRequest(
            String content, GenerateSummaryParameters params) {
        SummarizeSceneRequest request = new SummarizeSceneRequest();
        request.setContent(content);
        request.setMaxLength(params.getMaxLength());
        request.setTone(params.getTone());
        request.setFocusOn(params.getFocusOn());
        return request;
    }
    
    /**
     * 计算字数
     */
    private int countWords(String text) {
        if (text == null || text.isEmpty()) {
            return 0;
        }
        // 简单的字数统计方法（中文每个字算一个词，英文按空格分词）
        String[] words = text.replaceAll("[，。！？：；\"\"\n\r]", " ").split("\\s+");
        int chineseWordCount = 0;
        for (char c : text.toCharArray()) {
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