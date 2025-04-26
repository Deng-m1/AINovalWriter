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

import java.util.Map;
import java.util.Optional;
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
        
        // 查找当前任务，获取父任务ID
        Optional<BackgroundTask> taskOpt = taskStateService.findById(taskId);
        if (!taskOpt.isPresent()) {
            log.warn("找不到任务: {}", taskId);
            return;
        }
        
        String parentTaskId = taskOpt.get().getParentTaskId();
        
        // 如果没有父任务ID，则不需要聚合
        if (parentTaskId == null || parentTaskId.isEmpty()) {
            return;
        }

        log.debug("处理摘要生成子任务 {} 完成事件，父任务: {}", taskId, parentTaskId);

        try {
            // 查找父任务
            Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
            if (!parentTaskOpt.isPresent()) {
                log.warn("找不到父任务: {}", parentTaskId);
                return;
            }

            BackgroundTask parentTask = parentTaskOpt.get();
            if (!"BATCH_GENERATE_SUMMARY".equals(parentTask.getTaskType())) {
                return; // 父任务类型不匹配
            }

            // 获取子任务结果
            GenerateSummaryResult result = null;
            if (event.getResult() instanceof GenerateSummaryResult) {
                result = (GenerateSummaryResult) event.getResult();
            } else {
                log.warn("子任务结果类型不匹配: {}", event.getResult() != null ? event.getResult().getClass().getName() : "null");
                return;
            }

            // 更新父任务进度
            updateParentTaskProgress(parentTask, result, true, null);
            
        } catch (Exception e) {
            log.error("处理摘要生成任务完成事件失败", e);
        }
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
        
        // 查找当前任务，获取父任务ID
        Optional<BackgroundTask> taskOpt = taskStateService.findById(taskId);
        if (!taskOpt.isPresent()) {
            log.warn("找不到任务: {}", taskId);
            return;
        }
        
        String parentTaskId = taskOpt.get().getParentTaskId();
        
        // 如果没有父任务ID，则不需要聚合
        if (parentTaskId == null || parentTaskId.isEmpty()) {
            return;
        }

        log.debug("处理摘要生成子任务 {} 失败事件，父任务: {}", taskId, parentTaskId);

        try {
            // 查找父任务
            Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
            if (!parentTaskOpt.isPresent()) {
                log.warn("找不到父任务: {}", parentTaskId);
                return;
            }

            BackgroundTask parentTask = parentTaskOpt.get();
            if (!"BATCH_GENERATE_SUMMARY".equals(parentTask.getTaskType())) {
                return; // 父任务类型不匹配
            }

            // 获取子任务的场景ID
            String sceneId = null;
            String errorMessage = null;
            if (event.getErrorInfo() != null) {
                errorMessage = (String) event.getErrorInfo().get("message");
                
                // 从子任务参数中获取场景ID
                BackgroundTask subTask = taskOpt.get();
                if (subTask.getParameters() != null && subTask.getParameters() instanceof Map) {
                    Map<String, Object> params = (Map<String, Object>) subTask.getParameters();
                    if (params.containsKey("sceneId")) {
                        sceneId = (String) params.get("sceneId");
                    }
                }
            }

            // 更新父任务进度
            updateParentTaskProgress(parentTask, null, false, sceneId != null ? 
                    Map.entry(sceneId, errorMessage != null ? errorMessage : "未知错误") : null);
            
        } catch (Exception e) {
            log.error("处理摘要生成任务失败事件失败", e);
        }
    }

    /**
     * 更新父任务进度
     * 
     * @param parentTask 父任务
     * @param result 子任务结果 (可能为null，如果是失败)
     * @param isSuccess 子任务是否成功
     * @param failedEntry 失败的场景ID和错误消息 (如果是失败)
     */
    private void updateParentTaskProgress(BackgroundTask parentTask, GenerateSummaryResult result, 
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
                    .build();
        }

        // 更新进度计数
        int newProcessedCount = currentProgress.getProcessedCount() + 1;
        int newSuccessCount = currentProgress.getSuccessCount();
        int newFailedCount = currentProgress.getFailedCount();
        int newConflictCount = currentProgress.getConflictCount();

        // 更新结果计数
        int newResultSuccessCount = currentResult.getSuccessCount();
        int newResultFailedCount = currentResult.getFailedCount();
        int newResultConflictCount = currentResult.getConflictCount();
        Map<String, String> failedSceneDetails = currentResult.getFailedSceneDetails();

        if (isSuccess) {
            // 子任务成功
            if (result != null && result.isConflict()) {
                // 版本冲突
                newConflictCount++;
                newResultConflictCount++;
            } else {
                // 正常成功
                newSuccessCount++;
                newResultSuccessCount++;
            }
        } else {
            // 子任务失败
            newFailedCount++;
            newResultFailedCount++;
            
            // 添加失败细节
            if (failedEntry != null) {
                failedSceneDetails.put(failedEntry.getKey(), failedEntry.getValue());
            }
        }

        // 创建新的进度对象
        BatchGenerateSummaryProgress newProgress = BatchGenerateSummaryProgress.builder()
                .totalScenes(currentProgress.getTotalScenes())
                .processedCount(newProcessedCount)
                .successCount(newSuccessCount)
                .failedCount(newFailedCount)
                .conflictCount(newConflictCount)
                .skippedCount(currentProgress.getSkippedCount())
                .build();

        // 创建新的结果对象
        BatchGenerateSummaryResult newResult = BatchGenerateSummaryResult.builder()
                .totalScenes(currentResult.getTotalScenes())
                .successCount(newResultSuccessCount)
                .failedCount(newResultFailedCount)
                .conflictCount(newResultConflictCount)
                .skippedCount(currentResult.getSkippedCount())
                .failedSceneDetails(failedSceneDetails)
                .build();

        // 更新父任务进度
        Optional<BackgroundTask> updatedTask = taskStateService.recordProgress(parentTask.getId(), newProgress);
        if (!updatedTask.isPresent()) {
            log.warn("无法更新父任务进度: {}", parentTask.getId());
        }

        // 检查是否所有子任务都已完成
        boolean allProcessed = newProgress.getProcessedCount() + newProgress.getSkippedCount() >= newProgress.getTotalScenes();
        if (allProcessed) {
            log.info("批量生成摘要任务 {} 的所有子任务已处理完成，总数: {}, 成功: {}, 失败: {}, 冲突: {}, 跳过: {}", 
                    parentTask.getId(), 
                    newProgress.getTotalScenes(),
                    newSuccessCount,
                    newFailedCount,
                    newConflictCount,
                    newProgress.getSkippedCount());

            // 确定父任务的最终状态
            TaskStatus finalStatus = TaskStatus.COMPLETED;
            if (newFailedCount > 0 && newSuccessCount + newConflictCount == 0) {
                // 所有子任务都失败
                finalStatus = TaskStatus.FAILED;
            } else if (newFailedCount > 0) {
                // 部分成功部分失败
                finalStatus = TaskStatus.COMPLETED_WITH_ERRORS;
            }

            // 根据最终状态更新父任务
            Optional<BackgroundTask> completedTask = null;
            if (finalStatus == TaskStatus.COMPLETED || finalStatus == TaskStatus.COMPLETED_WITH_ERRORS) {
                completedTask = taskStateService.recordCompletion(parentTask.getId(), newResult);
            } else {
                completedTask = taskStateService.recordFailure(
                        parentTask.getId(), 
                        Map.of("message", "所有子任务失败", "failedCount", newFailedCount),
                        true); // 标记为死信
            }

            if (!completedTask.isPresent()) {
                log.warn("无法更新父任务状态为 {}: {}", finalStatus, parentTask.getId());
            }
        }
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