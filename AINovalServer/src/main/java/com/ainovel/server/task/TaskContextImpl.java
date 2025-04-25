package com.ainovel.server.task;

import com.ainovel.server.task.event.internal.TaskProgressEvent;
import com.ainovel.server.task.producer.TaskMessageProducer;
import com.ainovel.server.task.service.TaskStateService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * 任务上下文实现类
 * @param <P> 任务参数类型
 */
public class TaskContextImpl<P> implements TaskContext<P> {
    
    private static final Logger logger = LoggerFactory.getLogger(TaskContextImpl.class);
    
    private final String taskId;
    private final String userId;
    private final String taskType;
    private final String parentTaskId;
    private final P parameters;
    private final String executionNodeId;
    private final ApplicationEventPublisher eventPublisher;
    private final TaskStateService taskStateService;
    private final TaskMessageProducer taskMessageProducer;
    
    /**
     * 构造函数
     */
    public TaskContextImpl(String taskId, String userId, String taskType, String parentTaskId, 
                          P parameters, String executionNodeId,
                          ApplicationEventPublisher eventPublisher,
                          TaskStateService taskStateService,
                          TaskMessageProducer taskMessageProducer) {
        this.taskId = Objects.requireNonNull(taskId, "任务ID不能为空");
        this.userId = Objects.requireNonNull(userId, "用户ID不能为空");
        this.taskType = Objects.requireNonNull(taskType, "任务类型不能为空");
        this.parentTaskId = parentTaskId;
        this.parameters = Objects.requireNonNull(parameters, "参数不能为空");
        this.executionNodeId = executionNodeId;
        this.eventPublisher = Objects.requireNonNull(eventPublisher, "事件发布器不能为空");
        this.taskStateService = Objects.requireNonNull(taskStateService, "任务状态服务不能为空");
        this.taskMessageProducer = Objects.requireNonNull(taskMessageProducer, "任务消息生产者不能为空");
    }
    
    @Override
    public String getTaskId() {
        return taskId;
    }
    
    @Override
    public String getUserId() {
        return userId;
    }
    
    @Override
    public String getTaskType() {
        return taskType;
    }
    
    @Override
    public String getParentTaskId() {
        return parentTaskId;
    }
    
    @Override
    public P getParameters() {
        return parameters;
    }
    
    @Override
    public void updateProgress(Object progress) {
        if (progress == null) {
            return;
        }
        
        try {
            // 更新数据库中的进度
            taskStateService.recordProgress(taskId, progress);
            
            // 发布进度事件
            TaskProgressEvent event = new TaskProgressEvent(
                    this, taskId, taskType, userId, progress);
            eventPublisher.publishEvent(event);
            
            // 记录日志
            logger.debug("任务进度已更新: {}", taskId);
        } catch (Exception e) {
            logger.error("更新任务进度失败: {} - {}", taskId, e.getMessage(), e);
        }
    }
    
    @Override
    public void logInfo(String message, Object... args) {
        logger.info("[Task:{}] " + message, appendToArgs(taskId, args));
    }
    
    @Override
    public void logError(String message, Object... args) {
        logger.error("[Task:{}] " + message, appendToArgs(taskId, args));
    }
    
    @Override
    public void logError(String message, Throwable throwable, Object... args) {
        logger.error("[Task:{}] " + message, appendToArgs(taskId, args), throwable);
    }
    
    @Override
    public String submitSubTask(String subTaskType, Object subTaskParameters) {
        Objects.requireNonNull(subTaskType, "子任务类型不能为空");
        Objects.requireNonNull(subTaskParameters, "子任务参数不能为空");
        
        String subTaskId = UUID.randomUUID().toString();
        
        try {
            // 创建子任务记录
            taskStateService.createTask(subTaskId, userId, subTaskType, subTaskParameters, taskId);
            
            // 发送子任务消息到RabbitMQ
            boolean sent = taskMessageProducer.sendTask(subTaskId, userId, subTaskType, subTaskParameters);
            
            if (!sent) {
                // 如果发送失败，记录错误日志
                Map<String, Object> errorInfo = new HashMap<>();
                errorInfo.put("message", "子任务消息发送失败");
                errorInfo.put("timestamp", Instant.now().toString());
                taskStateService.recordFailure(subTaskId, errorInfo, true);
                
                logger.error("子任务消息发送失败: {}", subTaskId);
                return null;
            }
            
            // 更新父任务的子任务状态摘要
            taskStateService.updateSubTaskStatusSummary(taskId, "total", 1);
            
            logger.info("已提交子任务: {} -> {}", taskId, subTaskId);
            return subTaskId;
        } catch (Exception e) {
            logger.error("提交子任务失败: {} -> {} - {}", taskId, subTaskType, e.getMessage(), e);
            return null;
        }
    }
    
    /**
     * 将任务ID添加到日志参数数组开头
     */
    private Object[] appendToArgs(String firstArg, Object[] args) {
        Object[] newArgs = new Object[args.length + 1];
        newArgs[0] = firstArg;
        System.arraycopy(args, 0, newArgs, 1, args.length);
        return newArgs;
    }
} 