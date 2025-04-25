package com.ainovel.server.task.event.internal;

/**
 * 任务提交事件
 */
public class TaskSubmittedEvent extends TaskApplicationEvent {
    private final Object parameters;
    private final String parentTaskId;
    
    public TaskSubmittedEvent(Object source, String taskId, String taskType, String userId, Object parameters, String parentTaskId) {
        super(source, taskId, taskType, userId);
        this.parameters = parameters;
        this.parentTaskId = parentTaskId;
    }
    
    public TaskSubmittedEvent(Object source, String taskId, String taskType, String userId, Object parameters) {
        this(source, taskId, taskType, userId, parameters, null);
    }
    
    public Object getParameters() {
        return parameters;
    }
    
    public String getParentTaskId() {
        return parentTaskId;
    }
} 