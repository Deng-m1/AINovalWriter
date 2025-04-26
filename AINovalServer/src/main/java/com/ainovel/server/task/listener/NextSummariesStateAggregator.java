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

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.HashMap;
import java.util.Map;

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

        log.debug("处理单个章节摘要生成子任务 {} 完成事件，父任务: {}", taskId, parentTaskId);

        // 获取子任务结果
        Object result = event.getResult();
        if (!(result instanceof GenerateSingleSummaryResult)) {
            log.warn("任务结果类型错误，期望 GenerateSingleSummaryResult，实际: {}", 
                    result != null ? result.getClass().getName() : "null");
            return;
        }

        GenerateSingleSummaryResult summaryResult = (GenerateSingleSummaryResult) result;
        
        // 获取父任务
        Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
        if (!parentTaskOpt.isPresent()) {
            log.warn("找不到父任务: {}", parentTaskId);
            return;
        }
        
        BackgroundTask parentTask = parentTaskOpt.get();
        
        // 更新父任务进度
        updateParentTaskProgress(parentTask, summaryResult, true);
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

        log.debug("处理单个章节摘要生成子任务 {} 失败事件，父任务: {}", taskId, parentTaskId);
        
        // 获取子任务参数
        Object parameters = taskOpt.get().getParameters();
        
        // 从子任务获取当前章节索引
        int chapterIndex = 0;
        if (parameters != null) {
            chapterIndex = (int) ReflectionUtil.getPropertyValue(parameters, "chapterIndex", 0);
        }
        
        // 获取父任务
        Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
        if (!parentTaskOpt.isPresent()) {
            log.warn("找不到父任务: {}", parentTaskId);
            return;
        }
        
        BackgroundTask parentTask = parentTaskOpt.get();
        
        // 创建一个空的结果，用于更新父任务进度
        GenerateSingleSummaryResult failedResult = GenerateSingleSummaryResult.builder()
                .chapterIndex(chapterIndex)
                .newChapterId(null)
                .summary(null)
                .chapterTitle(null)
                .build();
        
        // 更新父任务进度
        updateParentTaskProgress(parentTask, failedResult, false);
    }

    /**
     * 更新父任务进度
     * 
     * @param parentTask 父任务
     * @param summaryResult 子任务结果
     * @param success 是否成功
     */
    private void updateParentTaskProgress(BackgroundTask parentTask, GenerateSingleSummaryResult summaryResult, boolean success) {
        String parentTaskId = parentTask.getId();
        
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
        if (success) {
            progress.setCompleted(progress.getCompleted() + 1);
        } else {
            progress.setFailed(progress.getFailed() + 1);
        }
        
        // 获取最新章节索引
        int currentIndex = summaryResult.getChapterIndex();
        progress.setCurrentIndex(currentIndex);
        
        // 更新父任务进度
        Optional<BackgroundTask> updatedTask = taskStateService.recordProgress(parentTaskId, progress);
        if (!updatedTask.isPresent()) {
            log.warn("更新父任务进度失败: {}", parentTaskId);
            return;
        }
        
        // 判断任务是否已完成
        boolean completed = (progress.getCompleted() + progress.getFailed() >= progress.getTotal());
        if (completed) {
            log.info("父任务所有子任务已处理完毕，开始更新最终状态，成功: {}，失败: {}，总数: {}", 
                    progress.getCompleted(), progress.getFailed(), progress.getTotal());
            
            // 更新任务最终状态
            updateTaskFinalState(parentTask, progress);
        }
    }

    /**
     * 更新任务最终状态
     */
    private void updateTaskFinalState(BackgroundTask parentTask, GenerateNextSummariesOnlyProgress progress) {
        String taskId = parentTask.getId();
        
        // 创建结果对象
        GenerateNextSummariesOnlyResult result = new GenerateNextSummariesOnlyResult();
        
        // 设置结果信息
        result.setSummariesGeneratedCount(progress.getCompleted());
        
        // 获取新创建的章节ID列表
        List<String> newChapterIds = new ArrayList<>();
        if (parentTask.getSubTaskStatusSummary() != null) {
            List<BackgroundTask> subTasks = backgroundTaskRepository.findByParentTaskId(taskId);
            for (BackgroundTask subTask : subTasks) {
                if (subTask.getStatus() == TaskStatus.COMPLETED && subTask.getResult() instanceof GenerateSingleSummaryResult) {
                    GenerateSingleSummaryResult subResult = (GenerateSingleSummaryResult) subTask.getResult();
                    if (subResult.getNewChapterId() != null) {
                        newChapterIds.add(subResult.getNewChapterId());
                    }
                }
            }
        }
        result.setNewChapterIds(newChapterIds);
        
        // 判断最终状态
        List<String> failedSteps = new ArrayList<>();
        if (progress.getFailed() > 0) {
            if (progress.getCompleted() > 0) {
                // 部分成功，部分失败
                result.setStatus("COMPLETED_WITH_ERRORS");
            } else {
                // 全部失败
                result.setStatus("FAILED");
            }
            
            // 记录失败的步骤
            List<BackgroundTask> subTasks = backgroundTaskRepository.findByParentTaskId(taskId);
            for (BackgroundTask subTask : subTasks) {
                if (subTask.getStatus() == TaskStatus.FAILED) {
                    failedSteps.add(String.valueOf(ReflectionUtil.getPropertyValue(
                            subTask.getParameters(), "chapterIndex", -1)));
                }
            }
        } else {
            // 全部成功
            result.setStatus("COMPLETED");
        }
        result.setFailedSteps(failedSteps);
        
        // 更新任务状态为已完成
        TaskStatus finalStatus = progress.getFailed() > 0 ? 
                (progress.getCompleted() > 0 ? TaskStatus.COMPLETED_WITH_ERRORS : TaskStatus.FAILED) : 
                TaskStatus.COMPLETED;
        
        // 使用正确的方法签名调用recordCompletion
        Optional<BackgroundTask> updated = taskStateService.recordCompletion(taskId, result);
        if (!updated.isPresent()) {
            log.warn("更新父任务 {} 最终状态失败", taskId);
        } else {
            log.info("父任务 {} 已更新为最终状态: {}", taskId, finalStatus);
            
            // 手动更新任务状态
            updated.get().setStatus(finalStatus);
            backgroundTaskRepository.save(updated.get());
        }
    }

    /**
     * 检查并标记事件为已处理
     */
    private boolean checkAndMarkEventProcessed(String eventId) {
        return processedEventIds.putIfAbsent(eventId, Boolean.TRUE) == null;
    }
} 