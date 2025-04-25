package com.ainovel.server.task.event.internal;

import java.util.Map;

/**
 * 任务失败事件
 */
public class TaskFailedEvent extends TaskApplicationEvent {
    private final Map<String, Object> errorInfo;
    private final boolean isDeadLetter;
    
    public TaskFailedEvent(Object source, String taskId, String taskType, String userId, Map<String, Object> errorInfo, boolean isDeadLetter) {
        super(source, taskId, taskType, userId);
        this.errorInfo = errorInfo;
        this.isDeadLetter = isDeadLetter;
    }
    
    public Map<String, Object> getErrorInfo() {
        return errorInfo;
    }
    
    public boolean isDeadLetter() {
        return isDeadLetter;
    }
} 