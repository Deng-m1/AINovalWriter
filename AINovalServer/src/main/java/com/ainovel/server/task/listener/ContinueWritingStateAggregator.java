package com.ainovel.server.task.listener;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Chapter;
import com.ainovel.server.repository.BackgroundTaskRepository;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentProgress;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentParameters;
import com.ainovel.server.task.dto.continuecontent.GenerateChapterContentParameters;
import com.ainovel.server.task.dto.continuecontent.GenerateChapterContentResult;
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
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 继续写作任务状态聚合器
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ContinueWritingStateAggregator {
    
    private final TaskStateService taskStateService;
    private final TaskSubmissionService taskSubmissionService;
    private final BackgroundTaskRepository backgroundTaskRepository;
    private final NovelService novelService;
    
    // 用于确保事件幂等性处理的缓存
    private final ConcurrentHashMap<String, Boolean> processedEventIds = new ConcurrentHashMap<>();
    
    /**
     * 处理下一章大纲任务完成事件
     */
    @EventListener
    @Async
    public void onNextSummariesTaskCompleted(TaskCompletedEvent event) {
        // 检查事件幂等性
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }
        
        String taskId = event.getTaskId();
        
        // 查找当前任务，获取父任务ID 和 任务类型
        taskStateService.getTask(taskId)
            .flatMap(task -> {
                if (task == null) {
                    log.warn("找不到任务: {}", taskId);
                    return Mono.empty();
                }
                
                // *** 新增：检查任务类型 ***
                if (!"GENERATE_NEXT_SUMMARIES".equals(task.getTaskType())) {
                    log.trace("任务类型不匹配，ContinueWritingStateAggregator 跳过处理: {}, 类型: {}", taskId, task.getTaskType());
                    return Mono.empty();
                }
                
                String parentTaskId = task.getParentTaskId();
                if (parentTaskId == null) {
                    log.info("任务不是子任务，无需聚合状态: {}", taskId);
                    return Mono.empty();
                }
                
                // 获取父任务
                return taskStateService.getTask(parentTaskId);
            })
            .flatMap(parentTask -> {
                if (parentTask == null) {
                    log.warn("找不到父任务", taskId);
                    return Mono.empty();
                }
                
                // 获取结果（这里使用Map处理以避免直接依赖类型）
                Object resultObj = event.getResult();
                Map<String, Object> summariesResult;
                
                if (resultObj instanceof Map) {
                    summariesResult = (Map<String, Object>) resultObj;
                } else {
                    log.warn("结果类型不匹配: {}", resultObj != null ? resultObj.getClass().getName() : "null");
                    return Mono.empty();
                }
                
                // 获取大纲列表
                List<Map<String, Object>> outlines = (List<Map<String, Object>>) summariesResult.get("outlines");
                
                if (outlines == null || outlines.isEmpty()) {
                    log.warn("无效的大纲生成结果，未生成大纲项");
                    return Mono.empty();
                }
                
                // 获取父任务参数
                Object params = parentTask.getParameters();
                if (!(params instanceof ContinueWritingContentParameters)) {
                    log.warn("父任务参数类型不匹配: {}", params != null ? params.getClass().getName() : "null");
                    return Mono.empty();
                }
                
                ContinueWritingContentParameters continueParams = (ContinueWritingContentParameters) params;
                
                // 获取小说
                return novelService.findNovelById(continueParams.getNovelId())
                    .flatMap(novel -> {
                        if (novel == null) {
                            log.warn("找不到小说: {}", continueParams.getNovelId());
                            return Mono.empty();
                        }
                        
                        // 更新进度
                        ContinueWritingContentProgress progress = new ContinueWritingContentProgress();
                        
                        // 设置大纲部分的进度
                        progress.setOutlinesGenerated(true);
                        progress.setOutlines(outlines);
                        progress.setTotalChapters(outlines.size());
                        progress.setCompletedChapters(0);
                        progress.setFailedChapters(0);
                        
                        // 向父任务设置进度
                        return taskStateService.recordProgress(parentTask.getId(), progress)
                            .then(submitChapterContentGenerationTasks(parentTask, outlines));
                    });
            })
            .subscribe(
                null,
                error -> log.error("处理大纲生成任务完成事件时发生错误", error)
            );
    }
    
    /**
     * 提交章节内容生成任务
     */
    private Mono<Void> submitChapterContentGenerationTasks(BackgroundTask parentTask, List<Map<String, Object>> outlines) {
        String novelId = ((ContinueWritingContentParameters) parentTask.getParameters()).getNovelId();
        String parentTaskId = parentTask.getId();
        
        // 为每个大纲提交一个内容生成任务
        List<Mono<String>> tasks = new ArrayList<>();
        
        for (Map<String, Object> outline : outlines) {
            GenerateChapterContentParameters contentParams = new GenerateChapterContentParameters();
            contentParams.setNovelId(novelId);
            contentParams.setChapterTitle((String) outline.get("title"));
            contentParams.setChapterSummary((String) outline.get("summary"));
            contentParams.setChapterId((String) outline.get("id"));
            
            // 提交内容生成任务
            Mono<String> task = taskSubmissionService.submitTask(
                    parentTask.getUserId(),
                    "GENERATE_CHAPTER_CONTENT",
                    contentParams,
                    parentTaskId
            ).doOnSuccess(contentTaskId -> 
                log.info("已提交章节内容生成任务: {}，父任务: {}", contentTaskId, parentTaskId)
            );
            
            tasks.add(task);
        }
        
        return Mono.when(tasks);
    }
    
    /**
     * 处理章节内容生成任务完成事件
     */
    @EventListener
    @Async
    public void onChapterContentTaskCompleted(TaskCompletedEvent event) {
        // 检查事件幂等性
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }
        
        String taskId = event.getTaskId();
        
        // 查找当前任务，获取父任务ID
        taskStateService.getTask(taskId)
            .flatMap(task -> {
                if (task == null) {
                    log.warn("找不到任务: {}", taskId);
                    return Mono.empty();
                }
                
                String parentTaskId = task.getParentTaskId();
                if (parentTaskId == null) {
                    log.info("任务不是子任务，无需聚合状态: {}", taskId);
                    return Mono.empty();
                }
                
                // 获取父任务
                return taskStateService.getTask(parentTaskId);
            })
            .flatMap(parentTask -> {
                if (parentTask == null) {
                    log.warn("找不到父任务", "");
                    return Mono.empty();
                }
                
                // 获取结果（这里使用Map处理以避免直接依赖类型）
                Object resultObj = event.getResult();
                Map<String, Object> contentResult;
                
                if (resultObj instanceof GenerateChapterContentResult) {
                    GenerateChapterContentResult typedResult = (GenerateChapterContentResult) resultObj;
                    contentResult = convertToMap(typedResult);
                } else if (resultObj instanceof Map) {
                    contentResult = (Map<String, Object>) resultObj;
                } else {
                    log.warn("结果类型不匹配: {}", resultObj != null ? resultObj.getClass().getName() : "null");
                    return Mono.empty();
                }
                
                // 更新父任务进度
                return updateContentProgress(parentTask, contentResult, true);
            })
            .subscribe(
                null,
                error -> log.error("处理章节内容生成任务完成事件时发生错误", error)
            );
    }
    
    /**
     * 将结果对象转换为Map
     */
    private Map<String, Object> convertToMap(GenerateChapterContentResult result) {
        Map<String, Object> map = new HashMap<>();
        map.put("outlineId", result.getChapterId());
        map.put("title", result.getChapter() != null ? result.getChapter().getTitle() : "");
        map.put("content", result.getChapter() != null ? result.getChapter().getDescription() : "");
        map.put("summary", result.getChapter() != null ? result.getChapter().getDescription() : "");
        map.put("order", result.getChapterIndex());
        return map;
    }
    
    /**
     * 处理章节内容生成任务失败事件
     */
    @EventListener
    @Async
    public void onChapterContentTaskFailed(TaskFailedEvent event) {
        // 检查事件幂等性
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            log.debug("事件已处理，跳过: {}", event.getEventId());
            return;
        }
        
        String taskId = event.getTaskId();
        
        // 查找当前任务，获取父任务ID
        taskStateService.getTask(taskId)
            .flatMap(task -> {
                if (task == null) {
                    log.warn("找不到任务: {}", taskId);
                    return Mono.empty();
                }
                
                String parentTaskId = task.getParentTaskId();
                if (parentTaskId == null) {
                    log.info("任务不是子任务，无需聚合状态: {}", taskId);
                    return Mono.empty();
                }
                
                // 获取父任务
                return taskStateService.getTask(parentTaskId);
            })
            .flatMap(parentTask -> {
                if (parentTask == null) {
                    log.warn("找不到父任务", "");
                    return Mono.empty();
                }
                
                BackgroundTask currentTask = null;
                try {
                    // 获取当前任务
                    currentTask = taskStateService.getTask(taskId).block();
                } catch(Exception e) {
                    log.warn("获取当前任务出错: {}", e.getMessage());
                }
                
                // 获取任务参数
                Object params = currentTask != null ? currentTask.getParameters() : null;
                if (!(params instanceof GenerateChapterContentParameters)) {
                    log.warn("任务参数类型不匹配: {}", params != null ? params.getClass().getName() : "null");
                    return Mono.empty();
                }
                
                GenerateChapterContentParameters contentParams = (GenerateChapterContentParameters) params;
                
                // 创建一个包含错误信息的结果
                Map<String, Object> failedResult = new HashMap<>();
                failedResult.put("outlineId", contentParams.getChapterId());
                failedResult.put("title", contentParams.getChapterTitle());
                
                // 创建带错误信息的内容
                String errorMessage = "内容生成失败: " + 
                        (event.getErrorInfo() != null ? event.getErrorInfo().toString() : "未知错误");
                failedResult.put("content", errorMessage);
                
                // 更新父任务进度
                return updateContentProgress(parentTask, failedResult, false);
            })
            .subscribe(
                null,
                error -> log.error("处理章节内容生成任务失败事件时发生错误", error)
            );
    }
    
    /**
     * 更新内容生成进度
     */
    private Mono<Void> updateContentProgress(BackgroundTask parentTask, Map<String, Object> contentResult, boolean success) {
        // 获取当前进度
        Object progressObj = parentTask.getProgress();
        if (!(progressObj instanceof ContinueWritingContentProgress)) {
            // 如果没有进度或类型不匹配，初始化一个新的
            progressObj = new ContinueWritingContentProgress();
            ((ContinueWritingContentProgress) progressObj).setOutlinesGenerated(true);
        }
        
        ContinueWritingContentProgress progress = (ContinueWritingContentProgress) progressObj;
        
        // 初始化章节结果列表
        if (progress.getChapterResults() == null) {
            progress.setChapterResults(new ArrayList<>());
        }
        
        // 更新完成/失败计数
        if (success) {
            progress.setCompletedChapters(progress.getCompletedChapters() + 1);
        } else {
            progress.setFailedChapters(progress.getFailedChapters() + 1);
        }
        
        // 添加章节结果
        progress.getChapterResults().add(contentResult);
        
        // 是否已完成所有章节内容生成
        boolean allCompleted = (progress.getCompletedChapters() + progress.getFailedChapters()) >= progress.getTotalChapters();
        
        // 更新进度
        return taskStateService.recordProgress(parentTask.getId(), progress)
            .then(allCompleted ? updateTaskFinalState(parentTask, progress) : Mono.empty());
    }
    
    /**
     * 更新任务最终状态
     */
    private Mono<Void> updateTaskFinalState(BackgroundTask parentTask, ContinueWritingContentProgress progress) {
        String taskId = parentTask.getId();
        TaskStatus finalStatus;
        
        // 根据成功/失败数确定最终状态
        if (progress.getFailedChapters() == 0) {
            finalStatus = TaskStatus.COMPLETED;
        } else if (progress.getCompletedChapters() == 0) {
            finalStatus = TaskStatus.FAILED;
        } else {
            finalStatus = TaskStatus.COMPLETED_WITH_ERRORS;
        }
        
        // 获取生成的章节列表
        List<Chapter> generatedChapters = new ArrayList<>();
        
        return backgroundTaskRepository.findByParentTaskId(taskId)
            .filter(subTask -> subTask.getTaskType().equals("GENERATE_CHAPTER_CONTENT") && 
                   subTask.getStatus() == TaskStatus.COMPLETED)
            .map(subTask -> {
                Object result = subTask.getResult();
                Map<String, Object> contentResult;
                
                if (result instanceof GenerateChapterContentResult) {
                    contentResult = convertToMap((GenerateChapterContentResult) result);
                } else if (result instanceof Map) {
                    contentResult = (Map<String, Object>) result;
                } else {
                    return null;
                }
                
                // 创建新章节
                Chapter chapter = new Chapter();
                chapter.setId((String) contentResult.get("outlineId"));
                chapter.setTitle((String) contentResult.get("title"));
                chapter.setDescription((String) contentResult.get("summary"));
                
                // 设置序号，如果存在
                if (contentResult.containsKey("order") && contentResult.get("order") instanceof Integer) {
                    chapter.setOrder((Integer) contentResult.get("order"));
                } else {
                    chapter.setOrder(0); // 默认值
                }
                
                return chapter;
            })
            .filter(Objects::nonNull)
            .collectList()
            .flatMap(chapters -> {
                // 排序章节
                Collections.sort(chapters, (c1, c2) -> Integer.compare(c1.getOrder(), c2.getOrder()));
                
                // 准备最终结果
                Map<String, Object> resultMap = new HashMap<>();
                
                // 设置大纲
                resultMap.put("outlines", progress.getOutlines());
                
                // 从父任务参数获取小说ID
                Object params = parentTask.getParameters();
                if (params instanceof ContinueWritingContentParameters) {
                    String novelId = ((ContinueWritingContentParameters) params).getNovelId();
                    resultMap.put("novelId", novelId);
                    
                    // 获取上下文
                    String lastChapterId = null;
                    try {
                        // 尝试使用反射获取endChapterId
                        java.lang.reflect.Method method = params.getClass().getMethod("getEndChapterId");
                        lastChapterId = (String) method.invoke(params);
                    } catch (Exception e) {
                        log.warn("无法获取endChapterId: {}", e.getMessage());
                    }
                    
                    final String finalLastChapterId = lastChapterId;
                    if (finalLastChapterId != null) {
                        return novelService.findNovelById(novelId)
                            .map(novel -> {
                                if (novel != null) {
                                    String context = getChapterContext(novel, finalLastChapterId);
                                    resultMap.put("context", context);
                                }
                                return resultMap;
                            });
                    }
                }
                
                return Mono.just(resultMap);
            })
            .flatMap(resultMap -> {
                // 调用记录完成方法
                return taskStateService.recordCompletion(taskId, resultMap)
                        .then(taskStateService.getTask(taskId));
            })
            .then();
    }
    
    /**
     * 获取章节上下文
     */
    private String getChapterContext(Novel novel, String chapterId) {
        if (novel == null || chapterId == null) {
            return "";
        }
        
        StringBuilder context = new StringBuilder();
        context.append("小说标题: ").append(novel.getTitle()).append("\n\n");
        
        if (novel.getDescription() != null) {
            context.append("小说描述: ").append(novel.getDescription()).append("\n\n");
        }
        
        // 查找目标章节
        Chapter targetChapter = findChapterById(novel, chapterId);
        if (targetChapter == null) {
            return context.toString();
        }
        
        // 添加章节信息
        context.append("最近的章节: ").append(targetChapter.getTitle());
        if (targetChapter.getDescription() != null) {
            context.append(" - ").append(targetChapter.getDescription());
        }
        context.append("\n");
        
        return context.toString();
    }
    
    /**
     * 在小说结构中查找章节
     */
    private Chapter findChapterById(Novel novel, String chapterId) {
        if (novel == null || novel.getStructure() == null || novel.getStructure().getActs() == null) {
            return null;
        }
        
        return novel.getStructure().getActs().stream()
            .flatMap(act -> act.getChapters().stream())
            .filter(chapter -> chapterId.equals(chapter.getId()))
            .findFirst()
            .orElse(null);
    }
    
    /**
     * 检查并标记事件处理状态，确保幂等性
     */
    private boolean checkAndMarkEventProcessed(String eventId) {
        return processedEventIds.putIfAbsent(eventId, Boolean.TRUE) == null;
    }
} 