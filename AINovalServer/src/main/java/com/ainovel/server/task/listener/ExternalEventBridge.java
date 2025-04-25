package com.ainovel.server.task.listener;

import com.ainovel.server.task.event.internal.*;
import com.ainovel.server.task.model.TaskStatus;
import com.ainovel.server.task.producer.TaskEventPublisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;

/**
 * 外部事件桥接器，将内部应用事件转换为外部事件并发布
 */
@Component
public class ExternalEventBridge {

    private static final Logger logger = LoggerFactory.getLogger(ExternalEventBridge.class);
    
    private final TaskEventPublisher eventPublisher;
    
    @Autowired
    public ExternalEventBridge(TaskEventPublisher eventPublisher) {
        this.eventPublisher = eventPublisher;
    }
    
    /**
     * 处理任务提交事件
     */
    @EventListener
    @Async
    public void onTaskSubmitted(TaskSubmittedEvent event) {
        logger.debug("接收到任务提交事件: {}", event.getTaskId());
        
        boolean published = eventPublisher.publishExternalEvent(
                event.getTaskId(),
                event.getTaskType(),
                event.getUserId(),
                TaskStatus.QUEUED, 
                null,  // 无结果
                null,  // 无进度
                null,  // 无错误信息
                false, // 非死信
                event.getParentTaskId()
        );
        
        if (!published) {
            logger.warn("任务提交外部事件发布失败: {}", event.getTaskId());
        }
    }
    
    /**
     * 处理任务开始事件
     */
    @EventListener
    @Async
    public void onTaskStarted(TaskStartedEvent event) {
        logger.debug("接收到任务开始事件: {}", event.getTaskId());
        
        Map<String, Object> progressInfo = new HashMap<>();
        progressInfo.put("executionNodeId", event.getExecutionNodeId());
        
        boolean published = eventPublisher.publishExternalEvent(
                event.getTaskId(),
                event.getTaskType(),
                event.getUserId(),
                TaskStatus.RUNNING,
                null,  // 无结果
                progressInfo,  // 包含执行节点信息的进度
                null,  // 无错误信息
                false, // 非死信
                null   // 父任务ID在此处不可用
        );
        
        if (!published) {
            logger.warn("任务开始外部事件发布失败: {}", event.getTaskId());
        }
    }
    
    /**
     * 处理任务进度事件
     */
    @EventListener
    @Async
    public void onTaskProgress(TaskProgressEvent event) {
        logger.debug("接收到任务进度事件: {}", event.getTaskId());
        
        boolean published = eventPublisher.publishExternalEvent(
                event.getTaskId(),
                event.getTaskType(),
                event.getUserId(),
                TaskStatus.RUNNING, // 有进度的任务应该是RUNNING状态
                null,  // 无结果
                event.getProgress(),  // 进度信息
                null,  // 无错误信息
                false, // 非死信
                null   // 父任务ID在此处不可用
        );
        
        if (!published) {
            logger.warn("任务进度外部事件发布失败: {}", event.getTaskId());
        }
    }
    
    /**
     * 处理任务完成事件
     */
    @EventListener
    @Async
    public void onTaskCompleted(TaskCompletedEvent event) {
        logger.debug("接收到任务完成事件: {}", event.getTaskId());
        
        boolean published = eventPublisher.publishExternalEvent(
                event.getTaskId(),
                event.getTaskType(),
                event.getUserId(),
                TaskStatus.COMPLETED,
                event.getResult(),  // 任务结果
                null,  // 无进度信息
                null,  // 无错误信息
                false, // 非死信
                null   // 父任务ID在此处不可用
        );
        
        if (!published) {
            logger.warn("任务完成外部事件发布失败: {}", event.getTaskId());
        }
    }
    
    /**
     * 处理任务失败事件
     */
    @EventListener
    @Async
    public void onTaskFailed(TaskFailedEvent event) {
        logger.debug("接收到任务失败事件: {}", event.getTaskId());
        
        boolean published = eventPublisher.publishExternalEvent(
                event.getTaskId(),
                event.getTaskType(),
                event.getUserId(),
                TaskStatus.FAILED,
                null,  // 无结果
                null,  // 无进度信息
                event.getErrorInfo(),  // 错误信息
                event.isDeadLetter(),  // 是否死信
                null   // 父任务ID在此处不可用
        );
        
        if (!published) {
            logger.warn("任务失败外部事件发布失败: {}", event.getTaskId());
        }
    }
    
    /**
     * 处理任务重试事件
     */
    @EventListener
    @Async
    public void onTaskRetrying(TaskRetryingEvent event) {
        logger.debug("接收到任务重试事件: {}", event.getTaskId());
        
        Map<String, Object> progressInfo = new HashMap<>();
        progressInfo.put("retryCount", event.getRetryCount());
        progressInfo.put("maxRetries", event.getMaxRetries());
        progressInfo.put("nextAttemptTimestamp", event.getNextAttemptTimestamp().toString());
        
        boolean published = eventPublisher.publishExternalEvent(
                event.getTaskId(),
                event.getTaskType(),
                event.getUserId(),
                TaskStatus.RETRYING,
                null,  // 无结果
                progressInfo,  // 重试信息作为进度
                event.getErrorInfo(),  // 错误信息
                false, // 非死信
                null   // 父任务ID在此处不可用
        );
        
        if (!published) {
            logger.warn("任务重试外部事件发布失败: {}", event.getTaskId());
        }
    }
} 