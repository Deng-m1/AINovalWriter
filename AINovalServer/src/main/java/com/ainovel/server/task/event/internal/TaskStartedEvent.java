package com.ainovel.server.task.event.internal;

/**
 * 任务开始事件
 */
public class TaskStartedEvent extends TaskApplicationEvent {
    private final String executionNodeId;
    
    public TaskStartedEvent(Object source, String taskId, String taskType, String userId, String executionNodeId) {
        super(source, taskId, taskType, userId);
        this.executionNodeId = executionNodeId;
    }
    
    public String getExecutionNodeId() {
        return executionNodeId;
    }
} 