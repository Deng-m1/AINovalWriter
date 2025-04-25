package com.ainovel.server.task.listener;

import com.ainovel.server.task.event.internal.*;
import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.model.TaskStatus;
import com.ainovel.server.task.service.TaskStateService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/**
 * 状态聚合服务，负责监听内部事件并更新数据库中的任务状态
 */
@Service
public class StateAggregatorService {

    private static final Logger logger = LoggerFactory.getLogger(StateAggregatorService.class);
    private static final long EVENT_ID_CACHE_TTL_SECONDS = 900; // 15分钟
    
    private final TaskStateService taskStateService;
    private final ConcurrentHashMap<String, Boolean> processedEventIds = new ConcurrentHashMap<>();
    private final ScheduledExecutorService cleanupExecutor;
    
    @Autowired
    public StateAggregatorService(TaskStateService taskStateService) {
        this.taskStateService = taskStateService;
        
        // 创建定时清理已处理事件ID的执行器
        this.cleanupExecutor = new ScheduledThreadPoolExecutor(1);
        this.cleanupExecutor.scheduleWithFixedDelay(this::cleanupProcessedEventIds, 
                EVENT_ID_CACHE_TTL_SECONDS, EVENT_ID_CACHE_TTL_SECONDS, TimeUnit.SECONDS);
    }
    
    /**
     * 处理任务提交事件
     * 注意：该事件通常在数据库记录创建之后发送，因此通常不需要处理
     */
    @EventListener
    @Async
    public void onTaskSubmitted(TaskSubmittedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            logger.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
            return;
        }
        
        logger.debug("处理任务提交事件: {}", event.getTaskId());
        // 通常任务已经在提交阶段创建，这里无需额外操作
    }
    
    /**
     * 处理任务开始事件
     */
    @EventListener
    @Async
    public void onTaskStarted(TaskStartedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            logger.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
            return;
        }
        
        logger.debug("处理任务开始事件: {}", event.getTaskId());
        
        // 任务开始在消费者中已经调用了trySetRunning，因此这里只是保险操作
        boolean updated = taskStateService.trySetRunning(event.getTaskId(), event.getExecutionNodeId());
        if (!updated) {
            logger.warn("无法更新任务{}为运行状态，可能已经被另一个消费者处理", event.getTaskId());
        }
    }
    
    /**
     * 处理任务进度事件
     */
    @EventListener
    @Async
    public void onTaskProgress(TaskProgressEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            logger.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
            return;
        }
        
        logger.debug("处理任务进度事件: {}", event.getTaskId());
        
        Optional<BackgroundTask> updated = taskStateService.recordProgress(event.getTaskId(), event.getProgress());
        if (!updated.isPresent()) {
            logger.warn("无法更新任务{}的进度，任务可能不存在或状态不允许更新", event.getTaskId());
        }
    }
    
    /**
     * 处理任务完成事件
     */
    @EventListener
    @Async
    public void onTaskCompleted(TaskCompletedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            logger.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
            return;
        }
        
        logger.debug("处理任务完成事件: {}", event.getTaskId());
        
        Optional<BackgroundTask> taskOpt = taskStateService.recordCompletion(event.getTaskId(), event.getResult());
        if (!taskOpt.isPresent()) {
            logger.warn("无法将任务{}标记为已完成，任务可能不存在或状态不允许更新", event.getTaskId());
            return;
        }
        
        // 处理子任务完成对父任务的影响
        BackgroundTask task = taskOpt.get();
        if (task.getParentTaskId() != null) {
            logger.debug("更新父任务{}的子任务状态摘要", task.getParentTaskId());
            Optional<BackgroundTask> parentOpt = taskStateService.updateSubTaskStatusSummary(
                    task.getParentTaskId(), "completed", 1);
            
            if (!parentOpt.isPresent()) {
                logger.warn("无法更新父任务{}的子任务状态摘要", task.getParentTaskId());
            }
        }
    }
    
    /**
     * 处理任务失败事件
     */
    @EventListener
    @Async
    public void onTaskFailed(TaskFailedEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            logger.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
            return;
        }
        
        logger.debug("处理任务失败事件: {}", event.getTaskId());
        
        Optional<BackgroundTask> taskOpt = taskStateService.recordFailure(
                event.getTaskId(), event.getErrorInfo(), event.isDeadLetter());
        
        if (!taskOpt.isPresent()) {
            logger.warn("无法将任务{}标记为失败，任务可能不存在或状态不允许更新", event.getTaskId());
            return;
        }
        
        // 处理子任务失败对父任务的影响
        BackgroundTask task = taskOpt.get();
        if (task.getParentTaskId() != null) {
            logger.debug("更新父任务{}的子任务状态摘要", task.getParentTaskId());
            Optional<BackgroundTask> parentOpt = taskStateService.updateSubTaskStatusSummary(
                    task.getParentTaskId(), "failed", 1);
            
            if (!parentOpt.isPresent()) {
                logger.warn("无法更新父任务{}的子任务状态摘要", task.getParentTaskId());
            }
        }
    }
    
    /**
     * 处理任务重试事件
     */
    @EventListener
    @Async
    public void onTaskRetrying(TaskRetryingEvent event) {
        if (!checkAndMarkEventProcessed(event.getEventId())) {
            logger.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
            return;
        }
        
        logger.debug("处理任务重试事件: {}", event.getTaskId());
        
        Optional<BackgroundTask> updated = taskStateService.recordRetrying(
                event.getTaskId(), event.getErrorInfo(), event.getNextAttemptTimestamp());
        
        if (!updated.isPresent()) {
            logger.warn("无法将任务{}标记为重试中，任务可能不存在或状态不允许更新", event.getTaskId());
        }
    }
    
    /**
     * 检查事件是否已处理并标记为已处理
     * 
     * @param eventId 事件ID
     * @return 如果事件未处理过返回true，否则返回false
     */
    private boolean checkAndMarkEventProcessed(String eventId) {
        return processedEventIds.putIfAbsent(eventId, Boolean.TRUE) == null;
    }
    
    /**
     * 清理长时间未使用的已处理事件ID
     */
    private void cleanupProcessedEventIds() {
        try {
            // 在实际实现中，应该基于事件时间戳进行清理
            // 这里简单起见，每次定时任务执行时都清空缓存
            int size = processedEventIds.size();
            if (size > 0) {
                logger.debug("清理已处理事件ID缓存，当前大小: {}", size);
                processedEventIds.clear();
            }
        } catch (Exception e) {
            logger.error("清理已处理事件ID时发生错误", e);
        }
    }
} 