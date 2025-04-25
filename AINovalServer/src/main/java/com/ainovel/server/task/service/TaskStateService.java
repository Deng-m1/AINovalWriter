package com.ainovel.server.task.service;

import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.model.TaskStatus;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;

/**
 * 任务状态服务接口，提供原子性操作以更新任务状态
 */
public interface TaskStateService {
    
    /**
     * 创建新任务
     * @param id 任务ID
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 参数对象
     * @param parentTaskId 父任务ID (可选)
     * @return 创建的任务对象
     */
    BackgroundTask createTask(String id, String userId, String taskType, Object parameters, String parentTaskId);
    
    /**
     * 创建新任务（无父任务）
     * @param id 任务ID
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 参数对象
     * @return 创建的任务对象
     */
    BackgroundTask createTask(String id, String userId, String taskType, Object parameters);
    
    /**
     * 尝试将任务设置为运行中状态（提供幂等性）
     * @param taskId 任务ID
     * @param executionNodeId 执行节点ID
     * @return 如果成功更新则返回true，如果任务已经在运行中或者不存在或者状态不是QUEUED或RETRYING则返回false
     */
    boolean trySetRunning(String taskId, String executionNodeId);
    
    /**
     * 记录任务进度
     * @param taskId 任务ID
     * @param progress 进度对象
     * @return 更新后的任务，如果任务不存在或状态不允许更新进度则返回空
     */
    Optional<BackgroundTask> recordProgress(String taskId, Object progress);
    
    /**
     * 记录任务完成
     * @param taskId 任务ID
     * @param result 结果对象
     * @return 更新后的任务，如果任务不存在或状态不允许更新为已完成则返回空
     */
    Optional<BackgroundTask> recordCompletion(String taskId, Object result);
    
    /**
     * 记录任务失败
     * @param taskId 任务ID
     * @param errorInfo 错误信息
     * @param isDeadLetter 是否标记为无法处理
     * @return 更新后的任务，如果任务不存在则返回空
     */
    Optional<BackgroundTask> recordFailure(String taskId, Map<String, Object> errorInfo, boolean isDeadLetter);
    
    /**
     * 记录任务重试信息
     * @param taskId 任务ID
     * @param errorInfo 错误信息
     * @param nextAttemptTimestamp 下次尝试时间
     * @return 更新后的任务，如果任务不存在则返回空
     */
    Optional<BackgroundTask> recordRetrying(String taskId, Map<String, Object> errorInfo, Instant nextAttemptTimestamp);
    
    /**
     * 更新子任务状态摘要（适用于批量任务）
     * @param parentTaskId 父任务ID
     * @param statusKey 状态键名（如"completed", "failed"等）
     * @param delta 增量值（通常为1）
     * @return 更新后的父任务，如果父任务不存在则返回空
     */
    Optional<BackgroundTask> updateSubTaskStatusSummary(String parentTaskId, String statusKey, int delta);
    
    /**
     * 根据ID查找任务
     * @param taskId 任务ID
     * @return 任务对象，如果不存在则返回空
     */
    Optional<BackgroundTask> findById(String taskId);
    
    /**
     * 根据ID和用户ID查找任务
     * @param taskId 任务ID
     * @param userId 用户ID
     * @return 任务对象，如果不存在则返回空
     */
    Optional<BackgroundTask> findByIdAndUserId(String taskId, String userId);
    
    /**
     * 取消任务
     * @param taskId 任务ID
     * @return 更新后的任务，如果任务不存在或已完成则返回空
     */
    Optional<BackgroundTask> cancelTask(String taskId);
} 