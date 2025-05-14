package com.ainovel.server.task.event.internal;

import java.util.Map;

/**
 * 任务重试事件
 */
public class TaskRetryingEvent extends TaskApplicationEvent {
    
    private final int retryCount;
    private final int maxRetryAttempts;
    private final long delayMillis;
    private final Map<String, Object> errorInfo;
    
    /**
     * 创建任务重试事件
     * 
     * @param source 事件源
     * @param taskId 任务ID
     * @param taskType 任务类型
     * @param userId 用户ID
     * @param retryCount 重试次数
     * @param maxRetryAttempts 最大重试次数
     * @param delayMillis 延迟时间（毫秒）
     * @param errorInfo 错误信息
     */
    public TaskRetryingEvent(Object source, String taskId, String taskType, String userId, 
                            int retryCount, int maxRetryAttempts, long delayMillis, Map<String, Object> errorInfo) {
        super(source, taskId, taskType, userId);
        this.retryCount = retryCount;
        this.maxRetryAttempts = maxRetryAttempts;
        this.delayMillis = delayMillis;
        this.errorInfo = errorInfo;
    }
    
    /**
     * 获取重试次数
     * 
     * @return 重试次数
     */
    public int getRetryCount() {
        return retryCount;
    }
    
    /**
     * 获取最大重试次数
     * 
     * @return 最大重试次数
     */
    public int getMaxRetryAttempts() {
        return maxRetryAttempts;
    }
    
    /**
     * 获取延迟时间（毫秒）
     * 
     * @return 延迟时间
     */
    public long getDelayMillis() {
        return delayMillis;
    }
    
    /**
     * 获取错误信息
     * 
     * @return 错误信息
     */
    public Map<String, Object> getErrorInfo() {
        return errorInfo;
    }
} 