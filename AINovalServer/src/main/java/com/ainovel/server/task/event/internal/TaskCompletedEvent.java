package com.ainovel.server.task.event.internal;

/**
 * 任务完成事件
 */
public class TaskCompletedEvent extends TaskApplicationEvent {
    private final Object result;
    
    public TaskCompletedEvent(Object source, String taskId, String taskType, String userId, Object result) {
        super(source, taskId, taskType, userId);
        this.result = result;
    }
    
    public Object getResult() {
        return result;
    }
} 