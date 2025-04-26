package com.ainovel.server.task.event.internal;

import java.time.Instant;
import java.util.Map;

/**
 * 任务重试事件
 */
public class TaskRetryingEvent extends TaskApplicationEvent {
    private final Map<String, Object> errorInfo;
    private final int retryCount;
    private final int maxRetries;
    private final Instant nextAttemptTimestamp;
    
    public TaskRetryingEvent(Object source, String taskId, String taskType, String userId, 
                             Map<String, Object> errorInfo, int retryCount, int maxRetries, 
                             Instant nextAttemptTimestamp) {
        super(source, taskId, taskType, userId);
        this.errorInfo = errorInfo;
        this.retryCount = retryCount;
        this.maxRetries = maxRetries;
        this.nextAttemptTimestamp = nextAttemptTimestamp;
    }
    
    public Map<String, Object> getErrorInfo() {
        return errorInfo;
    }
    
    public int getRetryCount() {
        return retryCount;
    }
    
    public int getMaxRetries() {
        return maxRetries;
    }
    
    public Instant getNextAttemptTimestamp() {
        return nextAttemptTimestamp;
    }
} 