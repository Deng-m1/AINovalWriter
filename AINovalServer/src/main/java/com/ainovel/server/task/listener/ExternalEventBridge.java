package com.ainovel.server.task.listener;

import com.ainovel.server.task.event.internal.*;
import com.ainovel.server.task.producer.TaskEventPublisher;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 外部事件桥接器，负责监听内部事件并调用外部事件发布器
 */
@Slf4j
@Component
public class ExternalEventBridge {

    private final TaskEventPublisher externalEventPublisher;
    private final ObjectMapper objectMapper;
    private final ConcurrentHashMap<String, Boolean> processedEventIds = new ConcurrentHashMap<>();

    @Autowired
    public ExternalEventBridge(
            TaskEventPublisher externalEventPublisher,
            ObjectMapper objectMapper) {
        this.externalEventPublisher = externalEventPublisher;
        this.objectMapper = objectMapper;
    }

    /**
     * 监听任务提交事件
     *
     * @param event 任务提交事件
     * @return 包含操作完成信号的Mono
     */
    @EventListener
    public Mono<Void> handleTaskSubmitted(TaskSubmittedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("桥接任务提交事件: taskId={}", event.getTaskId());

            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", event.getTaskId());
            eventData.put("taskType", event.getTaskType());
            eventData.put("userId", event.getUserId());

            return externalEventPublisher.publishExternalEvent("TASK_SUBMITTED", eventData)
                    .subscribeOn(Schedulers.boundedElastic())
                    .onErrorResume(e -> {
                        log.error("发布外部任务提交事件失败: taskId={}, error={}", 
                                  event.getTaskId(), e.getMessage(), e);
                        return Mono.empty();
                    });
        });
    }

    /**
     * 监听任务开始事件
     *
     * @param event 任务开始事件
     */
    @EventListener
    public Mono<Void> handleTaskStarted(TaskStartedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("桥接任务开始事件: taskId={}", event.getTaskId());

            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", event.getTaskId());
            eventData.put("taskType", event.getTaskType());
            eventData.put("userId", event.getUserId());
            eventData.put("executionNodeId", event.getExecutionNodeId());

            return externalEventPublisher.publishExternalEvent("TASK_STARTED", eventData)
                    .subscribeOn(Schedulers.boundedElastic())
                    .onErrorResume(e -> {
                        log.error("发布外部任务开始事件失败: taskId={}, error={}", 
                                  event.getTaskId(), e.getMessage(), e);
                        return Mono.empty();
                    });
        });
    }

    /**
     * 监听任务进度事件
     *
     * @param event 任务进度事件
     */
    @EventListener
    public Mono<Void> handleTaskProgress(TaskProgressEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("桥接任务进度事件: taskId={}", event.getTaskId());

            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", event.getTaskId());
            eventData.put("taskType", event.getTaskType());
            eventData.put("userId", event.getUserId());
            eventData.put("progressData", event.getProgressData());

            return externalEventPublisher.publishExternalEvent("TASK_PROGRESS", eventData)
                    .subscribeOn(Schedulers.boundedElastic())
                    .onErrorResume(e -> {
                        log.error("发布外部任务进度事件失败: taskId={}, error={}", 
                                  event.getTaskId(), e.getMessage(), e);
                        return Mono.empty();
                    });
        });
    }

    /**
     * 监听任务完成事件
     *
     * @param event 任务完成事件
     */
    @EventListener
    public Mono<Void> handleTaskCompleted(TaskCompletedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("桥接任务完成事件: taskId={}", event.getTaskId());

            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", event.getTaskId());
            eventData.put("taskType", event.getTaskType());
            eventData.put("userId", event.getUserId());
            eventData.put("result", event.getResult());

            return externalEventPublisher.publishExternalEvent("TASK_COMPLETED", eventData)
                    .subscribeOn(Schedulers.boundedElastic())
                    .onErrorResume(e -> {
                        log.error("发布外部任务完成事件失败: taskId={}, error={}", 
                                  event.getTaskId(), e.getMessage(), e);
                        return Mono.empty();
                    });
        });
    }

    /**
     * 监听任务失败事件
     *
     * @param event 任务失败事件
     */
    @EventListener
    public Mono<Void> handleTaskFailed(TaskFailedEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("桥接任务失败事件: taskId={}, isDeadLetter={}", event.getTaskId(), event.isDeadLetter());

            Map<String, Object> eventData = new HashMap<>(event.getErrorInfo());
            eventData.put("taskId", event.getTaskId());
            eventData.put("taskType", event.getTaskType());
            eventData.put("userId", event.getUserId());
            eventData.put("isDeadLetter", event.isDeadLetter());

            return externalEventPublisher.publishExternalEvent("TASK_FAILED", eventData)
                    .subscribeOn(Schedulers.boundedElastic())
                    .onErrorResume(e -> {
                        log.error("发布外部任务失败事件失败: taskId={}, error={}", 
                                  event.getTaskId(), e.getMessage(), e);
                        return Mono.empty();
                    });
        });
    }

    /**
     * 监听任务取消事件
     *
     * @param event 任务取消事件
     */
    @EventListener
    public Mono<Void> handleTaskCancelled(TaskCancelledEvent event) {
        return Mono.defer(() -> {
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.debug("桥接任务取消事件: taskId={}", event.getTaskId());

            Map<String, Object> eventData = new HashMap<>();
            eventData.put("taskId", event.getTaskId());
            eventData.put("taskType", event.getTaskType());
            eventData.put("userId", event.getUserId());

            return externalEventPublisher.publishExternalEvent("TASK_CANCELLED", eventData)
                    .subscribeOn(Schedulers.boundedElastic())
                    .onErrorResume(e -> {
                        log.error("发布外部任务取消事件失败: taskId={}, error={}", 
                                  event.getTaskId(), e.getMessage(), e);
                        return Mono.empty();
                    });
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
} 