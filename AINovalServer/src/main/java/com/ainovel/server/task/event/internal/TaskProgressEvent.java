package com.ainovel.server.task.event.internal;

/**
 * 任务进度事件
 */
public class TaskProgressEvent extends TaskApplicationEvent {
    private final Object progress;
    
    public TaskProgressEvent(Object source, String taskId, String taskType, String userId, Object progress) {
        super(source, taskId, taskType, userId);
        this.progress = progress;
    }
    
    public Object getProgress() {
        return progress;
    }
} 