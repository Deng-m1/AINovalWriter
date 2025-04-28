package com.ainovel.server.task.listener;

import com.ainovel.server.common.util.ReflectionUtil;
import com.ainovel.server.repository.BackgroundTaskRepository;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyProgress;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyResult;
import com.ainovel.server.task.dto.nextsummaries.GenerateSingleSummaryResult;
import com.ainovel.server.task.event.internal.TaskCompletedEvent;
import com.ainovel.server.task.event.internal.TaskFailedEvent;
import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.model.TaskStatus;
import com.ainovel.server.task.service.TaskStateService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 自动续写小说章节摘要任务状态聚合器
 * 监听子任务完成和失败事件，更新父任务的状态和进度
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NextSummariesStateAggregator {

    private final TaskStateService taskStateService;
    private final BackgroundTaskRepository backgroundTaskRepository;
    // 缓存处理过的事件ID，避免重复处理
    private final ConcurrentHashMap<String, Boolean> processedEventIds = new ConcurrentHashMap<>();

    /**
     * 处理单个章节摘要生成任务完成事件
     */
    @EventListener
    @Async
    public void onSingleSummaryTaskCompleted(TaskCompletedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }

        if (!"GENERATE_SINGLE_SUMMARY".equals(event.getTaskType())) {
            return; // 只处理单个章节摘要生成任务
        }

        String taskId = event.getTaskId();
        log.debug("接收到单个章节摘要生成任务完成事件: {}", taskId);
        
        // 使用响应式方式处理
        taskStateService.getTask(taskId)
            .switchIfEmpty(Mono.defer(() -> {
                log.warn("找不到任务: {}", taskId);
                return Mono.empty();
            }))
            .filter(task -> task.getParentTaskId() != null && !task.getParentTaskId().isEmpty())
            .flatMap(task -> {
                String parentTaskId = task.getParentTaskId();
                log.debug("处理单个章节摘要生成子任务 {} 完成事件，父任务: {}", taskId, parentTaskId);
                
                // 获取子任务结果
                Object result = event.getResult();
                if (!(result instanceof GenerateSingleSummaryResult)) {
                    log.warn("任务结果类型错误，期望 GenerateSingleSummaryResult，实际: {}", 
                            result != null ? result.getClass().getName() : "null");
                    return Mono.empty();
                }
                
                GenerateSingleSummaryResult summaryResult = (GenerateSingleSummaryResult) result;
                
                return taskStateService.getTask(parentTaskId)
                    .switchIfEmpty(Mono.defer(() -> {
                        log.warn("找不到父任务: {}", parentTaskId);
                        return Mono.empty();
                    }))
                    .flatMap(parentTask -> updateParentTaskProgress(parentTask, summaryResult, true));
            })
            .subscribe(
                success -> {},
                error -> log.error("处理单个章节摘要生成任务完成事件失败", error)
            );
    }

    /**
     * 处理单个章节摘要生成任务失败事件
     */
    @EventListener
    @Async
    public void onSingleSummaryTaskFailed(TaskFailedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }

        if (!"GENERATE_SINGLE_SUMMARY".equals(event.getTaskType())) {
            return; // 只处理单个章节摘要生成任务
        }

        String taskId = event.getTaskId();
        log.debug("接收到单个章节摘要生成任务失败事件: {}", taskId);
        
        // 使用响应式方式处理
        taskStateService.getTask(taskId)
            .switchIfEmpty(Mono.defer(() -> {
                log.warn("找不到任务: {}", taskId);
                return Mono.empty();
            }))
            .filter(task -> task.getParentTaskId() != null && !task.getParentTaskId().isEmpty())
            .flatMap(task -> {
                String parentTaskId = task.getParentTaskId();
                log.debug("处理单个章节摘要生成子任务 {} 失败事件，父任务: {}", taskId, parentTaskId);
                
                // 获取子任务参数
                Object parameters = task.getParameters();
                
                // 从子任务获取当前章节索引
                final int chapterIndex;
                if (parameters != null) {
                    chapterIndex = (int) ReflectionUtil.getPropertyValue(parameters, "chapterIndex", 0);
                } else {
                    chapterIndex = 0;
                }
                
                // 创建一个空的结果，用于更新父任务进度
                GenerateSingleSummaryResult failedResult = GenerateSingleSummaryResult.builder()
                        .chapterIndex(chapterIndex)
                        .newChapterId(null)
                        .summary(null)
                        .chapterTitle(null)
                        .build();
                
                return taskStateService.getTask(parentTaskId)
                    .switchIfEmpty(Mono.defer(() -> {
                        log.warn("找不到父任务: {}", parentTaskId);
                        return Mono.empty();
                    }))
                    .flatMap(parentTask -> updateParentTaskProgress(parentTask, failedResult, false));
            })
            .subscribe(
                success -> {},
                error -> log.error("处理单个章节摘要生成任务失败事件失败", error)
            );
    }

    /**
     * 更新父任务进度
     * 
     * @param parentTask 父任务
     * @param summaryResult 子任务结果
     * @param success 是否成功
     * @return 完成信号
     */
    private Mono<Void> updateParentTaskProgress(BackgroundTask parentTask, GenerateSingleSummaryResult summaryResult, boolean success) {
        final String parentTaskId = parentTask.getId();
        
        // 获取现有的进度信息
        Object currentProgress = parentTask.getProgress();
        GenerateNextSummariesOnlyProgress progress;
        
        if (currentProgress instanceof GenerateNextSummariesOnlyProgress) {
            progress = (GenerateNextSummariesOnlyProgress) currentProgress;
        } else {
            // 如果进度对象不存在或类型不匹配，创建一个新的
            progress = new GenerateNextSummariesOnlyProgress();
            progress.setTotal(0);
            progress.setCompleted(0);
            progress.setFailed(0);
            progress.setCurrentIndex(0);
        }
        
        // 更新进度
        final GenerateNextSummariesOnlyProgress updatedProgress = new GenerateNextSummariesOnlyProgress();
        updatedProgress.setTotal(progress.getTotal());
        updatedProgress.setCompleted(success ? progress.getCompleted() + 1 : progress.getCompleted());
        updatedProgress.setFailed(success ? progress.getFailed() : progress.getFailed() + 1);
        
        // 获取最新章节索引
        updatedProgress.setCurrentIndex(summaryResult.getChapterIndex());
        
        // 更新父任务进度
        return taskStateService.recordProgress(parentTaskId, updatedProgress)
            .then(Mono.defer(() -> {
                // 判断任务是否已完成
                boolean completed = (updatedProgress.getCompleted() + updatedProgress.getFailed() >= updatedProgress.getTotal());
                if (completed) {
                    log.info("父任务所有子任务已处理完毕，开始更新最终状态，成功: {}，失败: {}，总数: {}", 
                            updatedProgress.getCompleted(), updatedProgress.getFailed(), updatedProgress.getTotal());
                    
                    // 更新任务最终状态
                    return updateTaskFinalState(parentTask, updatedProgress);
                }
                return Mono.empty();
            }));
    }

    /**
     * 更新任务最终状态
     */
    private Mono<Void> updateTaskFinalState(BackgroundTask parentTask, GenerateNextSummariesOnlyProgress progress) {
        final String taskId = parentTask.getId();
        
        // 创建结果对象
        final GenerateNextSummariesOnlyResult result = new GenerateNextSummariesOnlyResult();
        
        // 设置结果信息
        result.setSummariesGeneratedCount(progress.getCompleted());
        
        // 使用响应式方式查询子任务
        return Flux.from(backgroundTaskRepository.findByParentTaskId(taskId))
            .collectMultimap(
                task -> task.getStatus(), 
                task -> task
            )
            .flatMap(tasksMap -> {
                // 处理成功任务
                List<String> newChapterIds = new ArrayList<>();
                if (tasksMap.containsKey(TaskStatus.COMPLETED)) {
                    for (BackgroundTask task : tasksMap.get(TaskStatus.COMPLETED)) {
                        if (task.getResult() instanceof GenerateSingleSummaryResult) {
                            GenerateSingleSummaryResult subResult = (GenerateSingleSummaryResult) task.getResult();
                            if (subResult.getNewChapterId() != null) {
                                newChapterIds.add(subResult.getNewChapterId());
                            }
                        }
                    }
                }
                result.setNewChapterIds(newChapterIds);
                
                // 处理失败任务
                List<String> failedSteps = new ArrayList<>();
                if (tasksMap.containsKey(TaskStatus.FAILED)) {
                    for (BackgroundTask task : tasksMap.get(TaskStatus.FAILED)) {
                        failedSteps.add(String.valueOf(ReflectionUtil.getPropertyValue(
                            task.getParameters(), "chapterIndex", -1)));
                    }
                }
                
                // 确定最终状态
                final TaskStatus finalStatus;
                if (progress.getFailed() > 0) {
                    if (progress.getCompleted() > 0) {
                        // 部分成功，部分失败
                        result.setStatus("COMPLETED_WITH_ERRORS");
                        finalStatus = TaskStatus.COMPLETED_WITH_ERRORS;
                    } else {
                        // 全部失败
                        result.setStatus("FAILED");
                        finalStatus = TaskStatus.FAILED;
                    }
                    result.setFailedSteps(failedSteps);
                } else {
                    // 全部成功
                    result.setStatus("COMPLETED");
                    finalStatus = TaskStatus.COMPLETED;
                    result.setFailedSteps(new ArrayList<>());
                }
                
                // 使用响应式API更新任务状态
                return taskStateService.recordCompletion(taskId, result)
                    .then(taskStateService.getTask(taskId))
                    .flatMap(updatedTask -> {
                        if (updatedTask == null) {
                            log.warn("更新父任务 {} 最终状态失败", taskId);
                            return Mono.empty();
                        } else {
                            log.info("父任务 {} 已更新为最终状态: {}", taskId, finalStatus);
                            
                            // 手动更新任务状态
                            updatedTask.setStatus(finalStatus);
                            return Mono.from(backgroundTaskRepository.save(updatedTask));
                        }
                    })
                    .then();
            });
    }

    /**
     * 检查并标记事件为已处理
     */
    private boolean checkAndMarkEventProcessed(String eventId) {
        return processedEventIds.putIfAbsent(eventId, Boolean.TRUE) == null;
    }
} 