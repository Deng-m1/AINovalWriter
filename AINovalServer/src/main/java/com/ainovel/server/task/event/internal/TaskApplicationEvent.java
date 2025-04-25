package com.ainovel.server.task.event.internal;

import org.springframework.context.ApplicationEvent;

import java.util.UUID;

/**
 * 任务事件基类
 */
public abstract class TaskApplicationEvent extends ApplicationEvent {
    private final String eventId;
    private final String taskId;
    private final String taskType;
    private final String userId;
    
    public TaskApplicationEvent(Object source, String taskId, String taskType, String userId) {
        super(source);
        this.eventId = UUID.randomUUID().toString();
        this.taskId = taskId;
        this.taskType = taskType;
        this.userId = userId;
    }
    
    public String getEventId() {
        return eventId;
    }
    
    public String getTaskId() {
        return taskId;
    }
    
    public String getTaskType() {
        return taskType;
    }
    
    public String getUserId() {
        return userId;
    }
} 