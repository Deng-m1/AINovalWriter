package com.ainovel.server.task.model;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Version;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 后台任务实体类，表示一个异步执行的后台任务
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "background_tasks")
public class BackgroundTask {
    
    @Id
    private String id;
    
    /**
     * 任务所属用户ID
     */
    private String userId;
    
    /**
     * 任务类型标识符
     */
    private String taskType;
    
    /**
     * 任务当前状态
     */
    private TaskStatus status;
    
    /**
     * 任务参数（序列化后的对象）
     */
    private Object parameters;
    
    /**
     * 任务进度信息
     */
    private Object progress;
    
    /**
     * 任务结果（序列化后的对象）
     */
    private Object result;
    
    /**
     * 错误信息（如果失败）
     */
    private Map<String, Object> errorInfo;
    
    /**
     * 时间戳信息
     */
    @Builder.Default
    private TaskTimestamps timestamps = new TaskTimestamps();
    
    /**
     * 重试次数
     */
    @Builder.Default
    private int retryCount = 0;
    
    /**
     * 最后一次尝试的时间戳
     */
    private Instant lastAttemptTimestamp;
    
    /**
     * 下一次尝试的计划时间戳
     */
    private Instant nextAttemptTimestamp;
    
    /**
     * 执行任务的节点标识符
     */
    private String executionNodeId;
    
    /**
     * 父任务ID（如果是子任务）
     */
    private String parentTaskId;
    
    /**
     * 子任务状态摘要（针对有子任务的父任务）
     */
    private Map<String, Integer> subTaskStatusSummary;
    
    /**
     * 版本号，用于乐观锁
     */
    @Version
    private Long version;
    
    /**
     * 任务相关的所有时间戳
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TaskTimestamps {
        
        /**
         * 任务创建时间
         */
        private Instant createdAt;
        
        /**
         * 任务开始执行时间
         */
        private Instant startedAt;
        
        /**
         * 任务完成时间
         */
        private Instant completedAt;
        
        /**
         * 任务最近更新时间
         */
        private Instant updatedAt;
    }
    
    /**
     * 添加子任务状态计数
     * @param status 状态
     * @param increment 增量
     */
    public void incrementSubTaskStatusCount(TaskStatus status, int increment) {
        if (subTaskStatusSummary == null) {
            subTaskStatusSummary = new HashMap<>();
        }
        
        String statusKey = status.name();
        int currentCount = subTaskStatusSummary.getOrDefault(statusKey, 0);
        subTaskStatusSummary.put(statusKey, currentCount + increment);
    }
    
    /**
     * 获取特定状态的子任务数量
     * @param status 状态
     * @return 该状态的子任务数量
     */
    public int getSubTaskStatusCount(TaskStatus status) {
        if (subTaskStatusSummary == null) {
            return 0;
        }
        return subTaskStatusSummary.getOrDefault(status.name(), 0);
    }
    
    /**
     * 获取所有子任务总数
     * @return 所有状态的子任务总和
     */
    public int getTotalSubTasksCount() {
        if (subTaskStatusSummary == null) {
            return 0;
        }
        return subTaskStatusSummary.values().stream().mapToInt(Integer::intValue).sum();
    }
} 