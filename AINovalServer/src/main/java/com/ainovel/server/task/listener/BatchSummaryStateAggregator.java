package com.ainovel.server.task.listener;

import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryProgress;
import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryResult;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryResult;
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
import reactor.core.publisher.Mono;

import java.util.AbstractMap;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 批量生成摘要任务状态聚合器
 * 监听子任务完成和失败事件，更新父任务的状态和进度
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BatchSummaryStateAggregator {

    private final TaskStateService taskStateService;
    // 缓存处理过的事件ID，避免重复处理
    private final ConcurrentHashMap<String, Boolean> processedEventIds = new ConcurrentHashMap<>();

    /**
     * 处理摘要生成任务完成事件
     */
    @EventListener
    @Async
    public void onSummaryTaskCompleted(TaskCompletedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }

        if (!"GENERATE_SUMMARY".equals(event.getTaskType())) {
            return; // 只处理摘要生成任务
        }

        String taskId = event.getTaskId();
        log.debug("接收到摘要生成子任务完成事件: {}", taskId);
        
        // 使用响应式方式处理
        taskStateService.getTask(taskId)
            .switchIfEmpty(Mono.<BackgroundTask>defer(() -> {
                log.warn("找不到任务: {}", taskId);
                return Mono.<BackgroundTask>empty();
            }))
            .filter(task -> task.getParentTaskId() != null && !task.getParentTaskId().isEmpty())
            .flatMap(task -> {
                String parentTaskId = task.getParentTaskId();
                log.debug("处理摘要生成子任务 {} 完成事件，父任务: {}", taskId, parentTaskId);
                
                return taskStateService.getTask(parentTaskId)
                    .switchIfEmpty(Mono.<BackgroundTask>defer(() -> {
                        log.warn("找不到父任务: {}", parentTaskId);
                        return Mono.<BackgroundTask>empty();
                    }))
                    .filter(parentTask -> "BATCH_GENERATE_SUMMARY".equals(parentTask.getTaskType()))
                    .flatMap(parentTask -> {
                        // 获取子任务结果
                        if (!(event.getResult() instanceof GenerateSummaryResult)) {
                            log.warn("子任务结果类型不匹配: {}", 
                                    event.getResult() != null ? event.getResult().getClass().getName() : "null");
                            return Mono.empty();
                        }
                        
                        GenerateSummaryResult result = (GenerateSummaryResult) event.getResult();
                        
                        // 更新父任务进度
                        return updateParentTaskProgress(parentTask, result, true, null);
                    });
            })
            .subscribe(
                success -> {},
                error -> log.error("处理摘要生成任务完成事件失败", error)
            );
    }

    /**
     * 处理摘要生成任务失败事件
     */
    @EventListener
    @Async
    public void onSummaryTaskFailed(TaskFailedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }

        if (!"GENERATE_SUMMARY".equals(event.getTaskType())) {
            return; // 只处理摘要生成任务
        }

        String taskId = event.getTaskId();
        log.debug("接收到摘要生成子任务失败事件: {}", taskId);
        
        // 使用响应式方式处理
        taskStateService.getTask(taskId)
            .switchIfEmpty(Mono.<BackgroundTask>defer(() -> {
                log.warn("找不到任务: {}", taskId);
                return Mono.<BackgroundTask>empty();
            }))
            .filter(task -> task.getParentTaskId() != null && !task.getParentTaskId().isEmpty())
            .flatMap(task -> {
                String parentTaskId = task.getParentTaskId();
                log.debug("处理摘要生成子任务 {} 失败事件，父任务: {}", taskId, parentTaskId);
                
                // 获取子任务的场景ID
                String sceneId = null;
                String errorMessage = null;
                
                if (event.getErrorInfo() != null) {
                    if (event.getErrorInfo().containsKey("message")) {
                        errorMessage = (String) event.getErrorInfo().get("message");
                    }
                    
                    // 从子任务参数中获取场景ID
                    Object params = task.getParameters();
                    if (params != null && params instanceof Map) {
                        Map<String, Object> paramMap = (Map<String, Object>) params;
                        if (paramMap.containsKey("sceneId")) {
                            sceneId = (String) paramMap.get("sceneId");
                        }
                    }
                }
                
                final String finalSceneId = sceneId;
                final String finalErrorMessage = errorMessage != null ? errorMessage : "未知错误";
                
                return taskStateService.getTask(parentTaskId)
                    .switchIfEmpty(Mono.<BackgroundTask>defer(() -> {
                        log.warn("找不到父任务: {}", parentTaskId);
                        return Mono.<BackgroundTask>empty();
                    }))
                    .filter(parentTask -> "BATCH_GENERATE_SUMMARY".equals(parentTask.getTaskType()))
                    .flatMap(parentTask -> {
                        // 更新父任务进度
                        Map.Entry<String, String> failedEntry = finalSceneId != null ? 
                                new AbstractMap.SimpleEntry<>(finalSceneId, finalErrorMessage) : null;
                        return updateParentTaskProgress(parentTask, null, false, failedEntry);
                    });
            })
            .subscribe(
                success -> {},
                error -> log.error("处理摘要生成任务失败事件失败", error)
            );
    }

    /**
     * 更新父任务进度
     * 
     * @param parentTask 父任务
     * @param result 子任务结果 (可能为null，如果是失败)
     * @param isSuccess 子任务是否成功
     * @param failedEntry 失败的场景ID和错误消息 (如果是失败)
     * @return 完成信号
     */
    private Mono<Void> updateParentTaskProgress(BackgroundTask parentTask, GenerateSummaryResult result, 
                                        boolean isSuccess, Map.Entry<String, String> failedEntry) {
        // 获取当前进度
        BatchGenerateSummaryProgress currentProgress = null;
        if (parentTask.getProgress() instanceof BatchGenerateSummaryProgress) {
            currentProgress = (BatchGenerateSummaryProgress) parentTask.getProgress();
        } else {
            // 默认初始进度
            currentProgress = BatchGenerateSummaryProgress.builder()
                    .totalScenes(0)
                    .processedCount(0)
                    .successCount(0)
                    .failedCount(0)
                    .conflictCount(0)
                    .skippedCount(0)
                    .build();
        }

        // 获取当前结果
        BatchGenerateSummaryResult currentResult = null;
        if (parentTask.getResult() instanceof BatchGenerateSummaryResult) {
            currentResult = (BatchGenerateSummaryResult) parentTask.getResult();
        } else {
            // 默认初始结果
            currentResult = BatchGenerateSummaryResult.builder()
                    .totalScenes(currentProgress.getTotalScenes())
                    .successCount(0)
                    .failedCount(0)
                    .conflictCount(0)
                    .skippedCount(currentProgress.getSkippedCount())
                    .failedSceneDetails(new HashMap<>())
                    .build();
        }

        // 创建状态统计的副本，以确保它们在lambda中是有效不变的
        final int totalScenes = currentProgress.getTotalScenes();
        final int skippedCount = currentProgress.getSkippedCount();
        final int processedCount = currentProgress.getProcessedCount() + 1;
        final int startingSuccessCount = currentProgress.getSuccessCount();
        final int startingFailedCount = currentProgress.getFailedCount();
        final int startingConflictCount = currentProgress.getConflictCount();
        
        // 创建结果计数的副本
        final int startingResultSuccessCount = currentResult.getSuccessCount();
        final int startingResultFailedCount = currentResult.getFailedCount();
        final int startingResultConflictCount = currentResult.getConflictCount();
        
        // 创建新的进度和结果对象
        BatchGenerateSummaryProgress.BatchGenerateSummaryProgressBuilder progressBuilder = BatchGenerateSummaryProgress.builder()
                .totalScenes(totalScenes)
                .processedCount(processedCount)
                .skippedCount(skippedCount);
        
        BatchGenerateSummaryResult.BatchGenerateSummaryResultBuilder resultBuilder = BatchGenerateSummaryResult.builder()
                .totalScenes(totalScenes)
                .skippedCount(skippedCount);
                
        // 复制失败细节映射
        Map<String, String> failedSceneDetails = new HashMap<>(
                currentResult.getFailedSceneDetails() != null ? 
                currentResult.getFailedSceneDetails() : new HashMap<>());
        
        // 根据任务状态更新计数器
        if (isSuccess) {
            // 子任务成功
            boolean hasConflict = result != null && result.getModelName() != null && 
                                result.getModelName().contains("conflict");
            if (hasConflict) {
                // 版本冲突 - 判断条件需要根据实际业务逻辑调整
                progressBuilder.successCount(startingSuccessCount)
                              .failedCount(startingFailedCount)
                              .conflictCount(startingConflictCount + 1);
                
                resultBuilder.successCount(startingResultSuccessCount)
                           .failedCount(startingResultFailedCount)
                           .conflictCount(startingResultConflictCount + 1);
            } else {
                // 正常成功
                progressBuilder.successCount(startingSuccessCount + 1)
                              .failedCount(startingFailedCount)
                              .conflictCount(startingConflictCount);
                
                resultBuilder.successCount(startingResultSuccessCount + 1)
                           .failedCount(startingResultFailedCount)
                           .conflictCount(startingResultConflictCount);
            }
        } else {
            // 子任务失败
            progressBuilder.successCount(startingSuccessCount)
                          .failedCount(startingFailedCount + 1)
                          .conflictCount(startingConflictCount);
            
            resultBuilder.successCount(startingResultSuccessCount)
                       .failedCount(startingResultFailedCount + 1)
                       .conflictCount(startingResultConflictCount);
            
            // 添加失败细节
            if (failedEntry != null) {
                failedSceneDetails.put(failedEntry.getKey(), failedEntry.getValue());
            }
        }
        
        // 设置失败详情
        resultBuilder.failedSceneDetails(failedSceneDetails);
        
        // 完成构建
        final BatchGenerateSummaryProgress newProgress = progressBuilder.build();
        final BatchGenerateSummaryResult newResult = resultBuilder.build();
        final String taskId = parentTask.getId();
        
        // 更新父任务进度
        return taskStateService.recordProgress(taskId, newProgress)
            .then(Mono.defer(() -> {
                // 检查是否所有子任务都已完成
                final boolean allProcessed = newProgress.getProcessedCount() + newProgress.getSkippedCount() >= newProgress.getTotalScenes();
                if (allProcessed) {
                    log.info("批量生成摘要任务 {} 的所有子任务已处理完成，总数: {}, 成功: {}, 失败: {}, 冲突: {}, 跳过: {}", 
                            taskId, 
                            newProgress.getTotalScenes(),
                            newProgress.getSuccessCount(),
                            newProgress.getFailedCount(),
                            newProgress.getConflictCount(),
                            newProgress.getSkippedCount());

                    // 确定父任务的最终状态
                    final TaskStatus finalStatus;
                    if (newProgress.getFailedCount() > 0 && newProgress.getSuccessCount() + newProgress.getConflictCount() == 0) {
                        // 所有子任务都失败
                        finalStatus = TaskStatus.FAILED;
                    } else if (newProgress.getFailedCount() > 0) {
                        // 部分成功部分失败
                        finalStatus = TaskStatus.COMPLETED_WITH_ERRORS;
                    } else {
                        finalStatus = TaskStatus.COMPLETED;
                    }

                    // 根据最终状态更新父任务
                    if (finalStatus == TaskStatus.COMPLETED || finalStatus == TaskStatus.COMPLETED_WITH_ERRORS) {
                        return taskStateService.recordCompletion(taskId, newResult);
                    } else {
                        Map<String, Object> errorInfo = Map.of(
                                "message", "所有子任务失败", 
                                "failedCount", newProgress.getFailedCount());
                        return taskStateService.recordFailure(taskId, errorInfo, true); // 标记为死信
                    }
                }
                return Mono.empty();
            }));
    }

    /**
     * 检查并标记事件为已处理
     * 
     * @param eventId 事件ID
     * @return 如果事件未处理过返回true，否则返回false
     */
    private boolean checkAndMarkEventProcessed(String eventId) {
        return processedEventIds.putIfAbsent(eventId, Boolean.TRUE) == null;
    }
} 