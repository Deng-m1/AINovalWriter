package com.ainovel.server.task.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * 后台任务实体类
 */
@Document(collection = "background_tasks")
public class BackgroundTask {
    @Id
    private String id;
    
    private String userId;
    
    private String taskType;
    
    private TaskStatus status;
    
    private Object parameters;
    
    private Object progress;
    
    private Object result;
    
    private Map<String, Object> errorInfo;
    
    private Map<String, Instant> timestamps = new HashMap<>();
    
    private int retryCount;
    
    private Instant lastAttemptTimestamp;
    
    private Instant nextAttemptTimestamp;
    
    private String executionNodeId;
    
    private String parentTaskId;
    
    private Map<String, Integer> subTaskStatusSummary = new HashMap<>();
    
    @Version
    private Long version;

    public BackgroundTask() {
    }

    public BackgroundTask(String id, String userId, String taskType, Object parameters) {
        this.id = id;
        this.userId = userId;
        this.taskType = taskType;
        this.parameters = parameters;
        this.status = TaskStatus.QUEUED;
        this.timestamps.put("created", Instant.now());
        this.retryCount = 0;
    }

    // Getters and Setters
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getTaskType() {
        return taskType;
    }

    public void setTaskType(String taskType) {
        this.taskType = taskType;
    }

    public TaskStatus getStatus() {
        return status;
    }

    public void setStatus(TaskStatus status) {
        this.status = status;
        // 更新状态变更时间戳
        this.timestamps.put(status.name().toLowerCase(), Instant.now());
    }

    public Object getParameters() {
        return parameters;
    }

    public void setParameters(Object parameters) {
        this.parameters = parameters;
    }

    public Object getProgress() {
        return progress;
    }

    public void setProgress(Object progress) {
        this.progress = progress;
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

    public Map<String, Instant> getTimestamps() {
        return timestamps;
    }

    public void setTimestamps(Map<String, Instant> timestamps) {
        this.timestamps = timestamps;
    }

    public int getRetryCount() {
        return retryCount;
    }

    public void setRetryCount(int retryCount) {
        this.retryCount = retryCount;
    }

    public void incrementRetryCount() {
        this.retryCount++;
    }

    public Instant getLastAttemptTimestamp() {
        return lastAttemptTimestamp;
    }

    public void setLastAttemptTimestamp(Instant lastAttemptTimestamp) {
        this.lastAttemptTimestamp = lastAttemptTimestamp;
    }

    public Instant getNextAttemptTimestamp() {
        return nextAttemptTimestamp;
    }

    public void setNextAttemptTimestamp(Instant nextAttemptTimestamp) {
        this.nextAttemptTimestamp = nextAttemptTimestamp;
    }

    public String getExecutionNodeId() {
        return executionNodeId;
    }

    public void setExecutionNodeId(String executionNodeId) {
        this.executionNodeId = executionNodeId;
    }

    public String getParentTaskId() {
        return parentTaskId;
    }

    public void setParentTaskId(String parentTaskId) {
        this.parentTaskId = parentTaskId;
    }

    public Map<String, Integer> getSubTaskStatusSummary() {
        return subTaskStatusSummary;
    }

    public void setSubTaskStatusSummary(Map<String, Integer> subTaskStatusSummary) {
        this.subTaskStatusSummary = subTaskStatusSummary;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion(Long version) {
        this.version = version;
    }
} 