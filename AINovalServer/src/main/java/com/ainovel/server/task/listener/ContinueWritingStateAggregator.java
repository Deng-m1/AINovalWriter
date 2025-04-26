package com.ainovel.server.task.listener;

import com.ainovel.server.common.util.ReflectionUtil;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Chapter;
import com.ainovel.server.repository.BackgroundTaskRepository;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentParameters;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentProgress;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentResult;
import com.ainovel.server.task.dto.continuecontent.GenerateChapterContentParameters;
import com.ainovel.server.task.dto.continuecontent.GenerateChapterContentResult;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyResult;
import com.ainovel.server.task.dto.nextsummaries.GenerateSingleSummaryResult;
import com.ainovel.server.task.event.internal.TaskCompletedEvent;
import com.ainovel.server.task.event.internal.TaskFailedEvent;
import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.model.TaskStatus;
import com.ainovel.server.task.service.TaskStateService;
import com.ainovel.server.task.service.TaskSubmissionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 自动续写小说章节内容任务状态聚合器
 * 监听子任务完成和失败事件，更新父任务的状态和进度
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ContinueWritingStateAggregator {

    private final TaskStateService taskStateService;
    private final TaskSubmissionService taskSubmissionService;
    private final BackgroundTaskRepository backgroundTaskRepository;
    private final NovelService novelService;
    
    // 缓存处理过的事件ID，避免重复处理
    private final ConcurrentHashMap<String, Boolean> processedEventIds = new ConcurrentHashMap<>();
    
    /**
     * 处理章节摘要生成任务完成事件
     */
    @EventListener
    @Async
    public void onNextSummariesTaskCompleted(TaskCompletedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }

        if (!"GENERATE_NEXT_SUMMARIES_ONLY".equals(event.getTaskType())) {
            return; // 只处理章节摘要生成任务
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
        
        // 获取父任务
        Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
        if (!parentTaskOpt.isPresent()) {
            log.warn("找不到父任务: {}", parentTaskId);
            return;
        }
        
        BackgroundTask parentTask = parentTaskOpt.get();
        
        // 确认父任务是自动续写任务
        if (!"CONTINUE_WRITING_CONTENT".equals(parentTask.getTaskType())) {
            return;
        }

        log.info("摘要生成任务完成，开始处理内容生成: {}", taskId);

        // 获取任务结果
        Object result = event.getResult();
        if (!(result instanceof GenerateNextSummariesOnlyResult)) {
            log.warn("任务结果类型错误: {}", result != null ? result.getClass().getName() : "null");
            return;
        }

        GenerateNextSummariesOnlyResult summariesResult = (GenerateNextSummariesOnlyResult) result;
        
        // 获取父任务参数
        ContinueWritingContentParameters parentParams = (ContinueWritingContentParameters) parentTask.getParameters();
        
        // 获取父任务进度对象
        ContinueWritingContentProgress progress = new ContinueWritingContentProgress();
        if (parentTask.getProgress() instanceof ContinueWritingContentProgress) {
            progress = (ContinueWritingContentProgress) parentTask.getProgress();
        } else {
            // 创建新的进度对象
            progress.setTotalChapters(parentParams.getNumberOfChapters());
            progress.setSummariesCompleted(0);
            progress.setContentsCompleted(0);
            progress.setFailed(0);
            progress.setCurrentIndex(0);
            progress.setPercentComplete(0);
        }
        
        // 是否需要用户评审摘要
        boolean requiresReview = parentParams.isRequiresReview();
        
        if (requiresReview) {
            // 设置状态为等待评审
            progress.setStage("WAITING_FOR_REVIEW");
            progress.setSummariesCompleted(summariesResult.getSummariesGeneratedCount());
            progress.setPercentComplete(50); // 摘要生成阶段结束，等待评审
            
            // 更新父任务进度
            taskStateService.recordProgress(parentTaskId, progress);
            
            log.info("摘要生成完成，等待用户评审: {}", parentTaskId);
            
        } else {
            // 不需要评审，直接开始生成内容
            progress.setStage("GENERATING_CONTENT");
            progress.setSummariesCompleted(summariesResult.getSummariesGeneratedCount());
            progress.setPercentComplete(50); // 摘要生成阶段结束，开始内容生成
            
            // 更新父任务进度
            taskStateService.recordProgress(parentTaskId, progress);
            
            // 获取新生成的章节ID列表
            List<String> newChapterIds = summariesResult.getNewChapterIds();
            
            // 获取小说
            String novelId = parentParams.getNovelId();
            Novel novel = novelService.findNovelById(novelId).block();
            
            if (novel == null) {
                log.error("找不到小说: {}", novelId);
                return;
            }
            
            // 为每个新生成的章节ID提交内容生成任务
            for (int i = 0; i < newChapterIds.size(); i++) {
                String chapterId = newChapterIds.get(i);
                
                // 查找章节
                Chapter chapter = findChapterById(novel, chapterId);
                
                if (chapter == null) {
                    log.warn("找不到章节: {}", chapterId);
                    continue;
                }
                
                // 创建内容生成任务参数
                GenerateChapterContentParameters contentParams = GenerateChapterContentParameters.builder()
                        .novelId(novelId)
                        .chapterId(chapterId)
                        .chapterIndex(i)
                        .chapterOrder(chapter.getOrder())
                        .chapterTitle(chapter.getTitle())
                        .chapterSummary(chapter.getDescription())
                        .aiConfigId(parentParams.getAiConfigIdContent())
                        .context(getChapterContext(novel, chapterId))
                        .writingStyle(parentParams.getWritingStyle())
                        .build();
                
                // 提交内容生成任务
                String contentTaskId = taskSubmissionService.submitTask(
                        parentTask.getUserId(),
                        "GENERATE_CHAPTER_CONTENT",
                        contentParams,
                        parentTaskId
                );
                
                log.info("已提交章节内容生成任务: {}，父任务: {}", contentTaskId, parentTaskId);
            }
        }
    }
    
    /**
     * 处理章节内容生成任务完成事件
     */
    @EventListener
    @Async
    public void onChapterContentTaskCompleted(TaskCompletedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }

        if (!"GENERATE_CHAPTER_CONTENT".equals(event.getTaskType())) {
            return; // 只处理章节内容生成任务
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
        
        // 获取父任务
        Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
        if (!parentTaskOpt.isPresent()) {
            log.warn("找不到父任务: {}", parentTaskId);
            return;
        }
        
        BackgroundTask parentTask = parentTaskOpt.get();
        
        // 确认父任务是自动续写任务
        if (!"CONTINUE_WRITING_CONTENT".equals(parentTask.getTaskType())) {
            return;
        }

        log.info("章节内容生成任务完成: {}", taskId);

        // 获取任务结果
        Object result = event.getResult();
        if (!(result instanceof GenerateChapterContentResult)) {
            log.warn("任务结果类型错误: {}", result != null ? result.getClass().getName() : "null");
            return;
        }

        GenerateChapterContentResult contentResult = (GenerateChapterContentResult) result;
        
        updateContentProgress(parentTask, contentResult, true);
    }
    
    /**
     * 处理章节内容生成任务失败事件
     */
    @EventListener
    @Async
    public void onChapterContentTaskFailed(TaskFailedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }

        if (!"GENERATE_CHAPTER_CONTENT".equals(event.getTaskType())) {
            return; // 只处理章节内容生成任务
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
        
        // 获取父任务
        Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
        if (!parentTaskOpt.isPresent()) {
            log.warn("找不到父任务: {}", parentTaskId);
            return;
        }
        
        BackgroundTask parentTask = parentTaskOpt.get();
        
        // 确认父任务是自动续写任务
        if (!"CONTINUE_WRITING_CONTENT".equals(parentTask.getTaskType())) {
            return;
        }

        log.info("章节内容生成任务失败: {}", taskId);

        // 获取任务参数
        Object parameters = taskOpt.get().getParameters();
        if (!(parameters instanceof GenerateChapterContentParameters)) {
            log.warn("任务参数类型错误: {}", parameters != null ? parameters.getClass().getName() : "null");
            return;
        }

        GenerateChapterContentParameters contentParams = (GenerateChapterContentParameters) parameters;
        
        // 从错误信息中提取消息
        String errorMessage = "任务失败";
        Map<String, Object> errorInfo = event.getErrorInfo();
        if (errorInfo != null && errorInfo.containsKey("message")) {
            errorMessage = errorInfo.get("message").toString();
        }
        
        // 创建一个失败的结果对象
        GenerateChapterContentResult failedResult = GenerateChapterContentResult.builder()
                .novelId(contentParams.getNovelId())
                .chapterId(contentParams.getChapterId())
                .chapterIndex(contentParams.getChapterIndex())
                .success(false)
                .errorMessage(errorMessage)
                .build();
        
        updateContentProgress(parentTask, failedResult, false);
    }
    
    /**
     * 更新内容生成进度
     */
    private void updateContentProgress(BackgroundTask parentTask, GenerateChapterContentResult contentResult, boolean success) {
        String parentTaskId = parentTask.getId();
        
        // 获取现有的进度信息
        ContinueWritingContentProgress progress;
        if (parentTask.getProgress() instanceof ContinueWritingContentProgress) {
            progress = (ContinueWritingContentProgress) parentTask.getProgress();
        } else {
            progress = new ContinueWritingContentProgress();
            progress.setStage("GENERATING_CONTENT");
            progress.setTotalChapters(0);
            progress.setSummariesCompleted(0);
            progress.setContentsCompleted(0);
            progress.setFailed(0);
            progress.setCurrentIndex(0);
            progress.setPercentComplete(50);
        }
        
        // 更新进度
        if (success) {
            progress.setContentsCompleted(progress.getContentsCompleted() + 1);
        } else {
            progress.setFailed(progress.getFailed() + 1);
        }
        
        // 计算完成百分比
        int totalChapters = progress.getTotalChapters();
        int completed = progress.getContentsCompleted();
        int failed = progress.getFailed();
        int percentComplete = 50 + (int)((completed + failed) * 50.0 / totalChapters);
        progress.setPercentComplete(Math.min(percentComplete, 100));
        
        // 获取最新章节索引
        int currentIndex = contentResult.getChapterIndex();
        progress.setCurrentIndex(currentIndex);
        
        // 更新父任务进度
        taskStateService.recordProgress(parentTaskId, progress);
        
        // 判断任务是否已完成
        boolean allCompleted = (completed + failed >= totalChapters);
        if (allCompleted) {
            log.info("所有章节内容生成任务已完成，更新最终状态，成功: {}，失败: {}，总数: {}", 
                    completed, failed, totalChapters);
            
            updateTaskFinalState(parentTask, progress);
        }
    }
    
    /**
     * 更新任务最终状态
     */
    private void updateTaskFinalState(BackgroundTask parentTask, ContinueWritingContentProgress progress) {
        String taskId = parentTask.getId();
        
        // 创建结果对象
        ContinueWritingContentResult result = new ContinueWritingContentResult();
        
        // 设置基本信息
        result.setCompletedChapters(progress.getContentsCompleted());
        result.setTotalChapters(progress.getTotalChapters());
        
        // 获取生成的章节列表
        List<Chapter> generatedChapters = new ArrayList<>();
        List<BackgroundTask> subTasks = backgroundTaskRepository.findByParentTaskId(taskId);
        
        for (BackgroundTask subTask : subTasks) {
            if (subTask.getTaskType().equals("GENERATE_CHAPTER_CONTENT") && 
                subTask.getStatus() == TaskStatus.COMPLETED && 
                subTask.getResult() instanceof GenerateChapterContentResult) {
                
                GenerateChapterContentResult chapterResult = (GenerateChapterContentResult) subTask.getResult();
                if (chapterResult.isSuccess() && chapterResult.getChapter() != null) {
                    generatedChapters.add(chapterResult.getChapter());
                }
            }
        }
        
        result.setGeneratedChapters(generatedChapters);
        
        // 设置任务状态
        if (progress.getFailed() > 0) {
            if (progress.getContentsCompleted() > 0) {
                result.setStatus("COMPLETED_WITH_ERRORS");
                result.setSuccess(true);
                result.setErrorMessage("部分章节生成失败");
            } else {
                result.setStatus("FAILED");
                result.setSuccess(false);
                result.setErrorMessage("所有章节生成失败");
            }
        } else {
            result.setStatus("COMPLETED");
            result.setSuccess(true);
        }
        
        // 更新任务状态为已完成
        TaskStatus finalStatus = progress.getFailed() > 0 ? 
                (progress.getContentsCompleted() > 0 ? TaskStatus.COMPLETED_WITH_ERRORS : TaskStatus.FAILED) : 
                TaskStatus.COMPLETED;
        
        // 调用记录完成方法
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
     * 获取章节上下文
     */
    private String getChapterContext(Novel novel, String chapterId) {
        StringBuilder context = new StringBuilder();
        
        // 获取所有章节
        List<Chapter> allChapters = new ArrayList<>();
        for (Novel.Act act : novel.getStructure().getActs()) {
            allChapters.addAll(act.getChapters());
        }
        
        // 按顺序排序
        allChapters.sort((a, b) -> Integer.compare(a.getOrder(), b.getOrder()));
        
        // 找到当前章节的索引
        int currentIndex = -1;
        for (int i = 0; i < allChapters.size(); i++) {
            if (allChapters.get(i).getId().equals(chapterId)) {
                currentIndex = i;
                break;
            }
        }
        
        if (currentIndex < 0) {
            // 找不到章节，返回空上下文
            return "";
        }
        
        // 获取前两章的内容（如果有）
        int startIndex = Math.max(0, currentIndex - 2);
        for (int i = startIndex; i < currentIndex; i++) {
            Chapter prevChapter = allChapters.get(i);
            context.append("第").append(prevChapter.getOrder()).append("章：")
                  .append(prevChapter.getTitle()).append("\n")
                  .append(prevChapter.getDescription()).append("\n\n");
        }
        
        return context.toString();
    }
    
    /**
     * 按ID查找章节
     */
    private Chapter findChapterById(Novel novel, String chapterId) {
        for (Novel.Act act : novel.getStructure().getActs()) {
            for (Chapter chapter : act.getChapters()) {
                if (chapter.getId().equals(chapterId)) {
                    return chapter;
                }
            }
        }
        return null;
    }
    
    /**
     * 检查并标记事件为已处理
     */
    private boolean checkAndMarkEventProcessed(String eventId) {
        return processedEventIds.putIfAbsent(eventId, Boolean.TRUE) == null;
    }
} 