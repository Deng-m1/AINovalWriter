package com.ainovel.server.task.listener;

import com.ainovel.server.task.event.internal.*;
import com.ainovel.server.task.model.TaskStatus;
import com.ainovel.server.task.service.TaskStateService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/**
 * 状态聚合服务，负责监听内部事件并以响应式方式更新数据库中的任务状态
 */
@Slf4j
@Service
public class StateAggregatorService {

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
     * 处理任务提交事件 (响应式)
     * 注意：任务消息发送到MQ的逻辑由 TaskSubmissionListener 处理
     */
    @EventListener
    public Mono<Void> onTaskSubmitted(TaskSubmittedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("处理任务提交事件: {} (仅状态聚合，消息发送由TaskSubmissionListener处理)", event.getTaskId());
            
            // 可以在这里添加额外的状态聚合逻辑，例如更新子任务状态摘要
            // 但任务消息发送到MQ的职责已转移到 TaskSubmissionListener
            return Mono.empty();
        });
    }
    
    /**
     * 处理任务开始事件 (响应式)
     */
    @EventListener
    public Mono<Void> onTaskStarted(TaskStartedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("处理任务开始事件: {}", event.getTaskId());
            
            return taskStateService.trySetRunning(event.getTaskId(), event.getExecutionNodeId())
                .doOnNext(updated -> {
                    if (!updated) {
                        log.warn("无法更新任务{}为运行状态，可能已被另一个消费者处理", event.getTaskId());
                    }
                })
                .then(); // 转换为 Mono<Void>
        });
    }
    
    /**
     * 处理任务进度事件 (响应式)
     */
    @EventListener
    public Mono<Void> onTaskProgress(TaskProgressEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("处理任务进度事件: {}", event.getTaskId());
            
            return taskStateService.recordProgress(event.getTaskId(), event.getProgressData())
                .doOnError(e -> log.warn("无法更新任务{}的进度: {}", event.getTaskId(), e.getMessage()));
        });
    }
    
    /**
     * 处理任务完成事件 (响应式)
     */
    @EventListener
    public Mono<Void> onTaskCompleted(TaskCompletedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("处理任务完成事件: {}", event.getTaskId());
            
            return taskStateService.recordCompletion(event.getTaskId(), event.getResult())
                .then(taskStateService.getTask(event.getTaskId())) // 获取任务以检查父任务ID
                .flatMap(task -> {
                    if (task != null && task.getParentTaskId() != null) {
                        log.debug("更新父任务{}的子任务状态摘要", task.getParentTaskId());
                        return taskStateService.updateSubTaskStatusSummary(
                                task.getParentTaskId(), task.getId(), TaskStatus.RUNNING, TaskStatus.COMPLETED)
                            .doOnError(e -> log.warn("无法更新父任务{}的子任务状态摘要: {}", 
                                                    task.getParentTaskId(), e.getMessage()));
                    } else {
                        return Mono.empty();
                    }
                })
                .doOnError(e -> log.warn("无法将任务{}标记为已完成: {}", event.getTaskId(), e.getMessage()));
        });
    }
    
    /**
     * 处理任务失败事件 (响应式)
     */
    @EventListener
    public Mono<Void> onTaskFailed(TaskFailedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("处理任务失败事件: {}", event.getTaskId());
            TaskStatus newStatus = event.isDeadLetter() ? TaskStatus.DEAD_LETTER : TaskStatus.FAILED;

            return taskStateService.recordFailure(event.getTaskId(), event.getErrorInfo(), event.isDeadLetter())
                .then(taskStateService.getTask(event.getTaskId())) // 获取任务以检查父任务ID
                .flatMap(task -> {
                    if (task != null && task.getParentTaskId() != null) {
                        log.debug("更新父任务{}的子任务状态摘要", task.getParentTaskId());
                        // 假设失败前是RUNNING，实际可能需要从事件获取更准确的前置状态
                        return taskStateService.updateSubTaskStatusSummary(
                                task.getParentTaskId(), task.getId(), TaskStatus.RUNNING, newStatus)
                            .doOnError(e -> log.warn("无法更新父任务{}的子任务状态摘要: {}", 
                                                    task.getParentTaskId(), e.getMessage()));
                    } else {
                        return Mono.empty();
                    }
                })
                .doOnError(e -> log.warn("无法将任务{}标记为失败: {}", event.getTaskId(), e.getMessage()));
        });
    }
    
    /**
     * 处理任务重试事件 (响应式)
     */
    @EventListener
    public Mono<Void> onTaskRetrying(TaskRetryingEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("处理任务重试事件: {}", event.getTaskId());
            
            // 使用当前时间戳加上延迟毫秒数计算下次尝试时间
            long currentTime = System.currentTimeMillis();
            java.time.Instant nextAttemptTimestamp = java.time.Instant.ofEpochMilli(currentTime + event.getDelayMillis());
            
            return taskStateService.recordRetry(
                event.getTaskId(), event.getErrorInfo(), nextAttemptTimestamp)
                .doOnError(e -> log.warn("无法将任务{}标记为重试中: {}", event.getTaskId(), e.getMessage()));
        });
    }
    
    /**
     * 检查事件是否已处理并标记为已处理 (幂等性)
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
            // 简单清理策略：直接清空
            int size = processedEventIds.size();
            if (size > 0) {
                log.debug("清理已处理事件ID缓存，当前大小: {}", size);
                processedEventIds.clear();
            }
        } catch (Exception e) {
            log.error("清理已处理事件ID时发生错误", e);
        }
    }
} 