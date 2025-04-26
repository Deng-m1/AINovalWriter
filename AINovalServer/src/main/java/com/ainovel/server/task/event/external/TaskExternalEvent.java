package com.ainovel.server.task.event.external;

import com.ainovel.server.task.model.TaskStatus;

import java.time.Instant;
import java.util.Map;

/**
 * 任务外部事件DTO，用于向外部发布任务状态变更
 */
public class TaskExternalEvent {
    private String eventId;
    private String taskId;
    private String taskType;
    private String userId;
    private TaskStatus status;
    private Instant timestamp;
    private Object progress;
    private Integer retryCount;
    private Object result;
    private Map<String, Object> errorInfo;
    private boolean isDeadLetter;
    private String parentTaskId;
    
    // 默认构造函数，用于序列化
    public TaskExternalEvent() {
    }
    
    // 带参数的构造函数
    public TaskExternalEvent(String eventId, String taskId, String taskType, String userId,
                            TaskStatus status, Instant timestamp) {
        this.eventId = eventId;
        this.taskId = taskId;
        this.taskType = taskType;
        this.userId = userId;
        this.status = status;
        this.timestamp = timestamp;
    }
    
    // Getters and Setters
    public String getEventId() {
        return eventId;
    }
    
    public void setEventId(String eventId) {
        this.eventId = eventId;
    }
    
    public String getTaskId() {
        return taskId;
    }
    
    public void setTaskId(String taskId) {
        this.taskId = taskId;
    }
    
    public String getTaskType() {
        return taskType;
    }
    
    public void setTaskType(String taskType) {
        this.taskType = taskType;
    }
    
    public String getUserId() {
        return userId;
    }
    
    public void setUserId(String userId) {
        this.userId = userId;
    }
    
    public TaskStatus getStatus() {
        return status;
    }
    
    public void setStatus(TaskStatus status) {
        this.status = status;
    }
    
    public Instant getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(Instant timestamp) {
        this.timestamp = timestamp;
    }
    
    public Object getProgress() {
        return progress;
    }
    
    public void setProgress(Object progress) {
        this.progress = progress;
    }
    
    public Integer getRetryCount() {
        return retryCount;
    }
    
    public void setRetryCount(Integer retryCount) {
        this.retryCount = retryCount;
    }
    
    public Object getResult() {
        return result;
    }
    
    public void setResult(Object result) {
        this.result = result;
    }
    
    public Map<String, Object> getErrorInfo() {
        return errorInfo;
    }
    
    public void setErrorInfo(Map<String, Object> errorInfo) {
        this.errorInfo = errorInfo;
    }
    
    public boolean isDeadLetter() {
        return isDeadLetter;
    }
    
    public void setDeadLetter(boolean deadLetter) {
        isDeadLetter = deadLetter;
    }
    
    public String getParentTaskId() {
        return parentTaskId;
    }
    
    public void setParentTaskId(String parentTaskId) {
        this.parentTaskId = parentTaskId;
    }
} 