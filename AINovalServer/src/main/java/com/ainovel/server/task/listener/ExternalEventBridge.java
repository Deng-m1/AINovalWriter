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

/**
 * 外部事件桥接器，负责监听内部事件并调用外部事件发布器
 */
@Slf4j
@Component
public class ExternalEventBridge {

    private final TaskEventPublisher externalEventPublisher;
    private final ObjectMapper objectMapper;

    @Autowired
    public ExternalEventBridge(
            TaskEventPublisher externalEventPublisher,
            ObjectMapper objectMapper) {
        this.externalEventPublisher = externalEventPublisher;
        this.objectMapper = objectMapper;
    }

    /**
     * 监听任务开始事件
     *
     * @param event 任务开始事件
     */
    @EventListener
    public void handleTaskStarted(TaskStartedEvent event) {
        log.debug("桥接任务开始事件: taskId={}", event.getTaskId());

        Map<String, Object> eventData = new HashMap<>();
        eventData.put("taskId", event.getTaskId());
        eventData.put("taskType", event.getTaskType());
        eventData.put("userId", event.getUserId());
        eventData.put("executionNodeId", event.getExecutionNodeId());

        externalEventPublisher.publishExternalEvent("TASK_STARTED", eventData)
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
    }

    /**
     * 监听任务进度事件
     *
     * @param event 任务进度事件
     */
    @EventListener
    public void handleTaskProgress(TaskProgressEvent event) {
        log.debug("桥接任务进度事件: taskId={}", event.getTaskId());

        Map<String, Object> eventData = new HashMap<>();
        eventData.put("taskId", event.getTaskId());
        eventData.put("taskType", event.getTaskType());
        eventData.put("userId", event.getUserId());
        eventData.put("progressData", event.getProgressData());

        externalEventPublisher.publishExternalEvent("TASK_PROGRESS", eventData)
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
    }

    /**
     * 监听任务完成事件
     *
     * @param event 任务完成事件
     */
    @EventListener
    public void handleTaskCompleted(TaskCompletedEvent event) {
        log.debug("桥接任务完成事件: taskId={}", event.getTaskId());

        Map<String, Object> eventData = new HashMap<>();
        eventData.put("taskId", event.getTaskId());
        eventData.put("taskType", event.getTaskType());
        eventData.put("userId", event.getUserId());
        eventData.put("result", event.getResult());

        externalEventPublisher.publishExternalEvent("TASK_COMPLETED", eventData)
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
    }

    /**
     * 监听任务失败事件
     *
     * @param event 任务失败事件
     */
    @EventListener
    public void handleTaskFailed(TaskFailedEvent event) {
        log.debug("桥接任务失败事件: taskId={}, isDeadLetter={}", event.getTaskId(), event.isDeadLetter());

        Map<String, Object> eventData = new HashMap<>(event.getErrorInfo());
        eventData.put("taskId", event.getTaskId());
        eventData.put("taskType", event.getTaskType());
        eventData.put("userId", event.getUserId());
        eventData.put("isDeadLetter", event.isDeadLetter());

        externalEventPublisher.publishExternalEvent("TASK_FAILED", eventData)
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
    }

    /**
     * 监听任务取消事件
     *
     * @param event 任务取消事件
     */
    @EventListener
    public void handleTaskCancelled(TaskCancelledEvent event) {
        log.debug("桥接任务取消事件: taskId={}", event.getTaskId());

        Map<String, Object> eventData = new HashMap<>();
        eventData.put("taskId", event.getTaskId());
        eventData.put("taskType", event.getTaskType());
        eventData.put("userId", event.getUserId());

        externalEventPublisher.publishExternalEvent("TASK_CANCELLED", eventData)
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
    }
} 