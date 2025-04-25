package com.ainovel.server.task.service.impl;

import com.ainovel.server.repository.BackgroundTaskRepository;
import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.model.TaskStatus;
import com.ainovel.server.task.service.TaskStateService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;

/**
 * 任务状态服务实现
 */
@Service
public class TaskStateServiceImpl implements TaskStateService {
    private static final Logger logger = LoggerFactory.getLogger(TaskStateServiceImpl.class);
    private static final int MAX_RETRY_ATTEMPTS = 3;
    
    private final BackgroundTaskRepository taskRepository;
    private final ObjectMapper objectMapper;
    private final String hostIdentifier;
    
    // 用于跟踪本地节点正在处理的任务，主要用于优雅关闭
    private final ConcurrentHashMap<String, Boolean> localProcessingTasks = new ConcurrentHashMap<>();
    
    @Autowired
    public TaskStateServiceImpl(BackgroundTaskRepository taskRepository, ObjectMapper objectMapper) {
        this.taskRepository = taskRepository;
        this.objectMapper = objectMapper;
        
        // 获取主机标识，用于区分不同的处理节点
        String hostId = "unknown";
        try {
            hostId = InetAddress.getLocalHost().getHostName() + "-" + System.currentTimeMillis();
        } catch (UnknownHostException e) {
            logger.warn("无法获取主机名", e);
        }
        this.hostIdentifier = hostId;
    }
    
    @Override
    public BackgroundTask createTask(String id, String userId, String taskType, Object parameters, String parentTaskId) {
        BackgroundTask task = new BackgroundTask(id, userId, taskType, parameters);
        task.setParentTaskId(parentTaskId);
        return taskRepository.save(task);
    }
    
    @Override
    public BackgroundTask createTask(String id, String userId, String taskType, Object parameters) {
        return createTask(id, userId, taskType, parameters, null);
    }
    
    @Override
    public boolean trySetRunning(String taskId, String executionNodeId) {
        Optional<BackgroundTask> taskOpt = taskRepository.findById(taskId);
        if (taskOpt.isEmpty()) {
            logger.warn("尝试设置不存在的任务为运行状态: {}", taskId);
            return false;
        }
        
        BackgroundTask task = taskOpt.get();
        
        // 只有当任务处于队列中或重试中状态时才允许设置为运行状态
        if (task.getStatus() != TaskStatus.QUEUED && task.getStatus() != TaskStatus.RETRYING) {
            logger.info("任务 {} 当前状态为 {}，不能设置为运行状态", taskId, task.getStatus());
            return false;
        }
        
        // 使用乐观锁更新任务状态
        return updateWithOptimisticLock(taskId, existingTask -> {
            if (existingTask.getStatus() != TaskStatus.QUEUED && existingTask.getStatus() != TaskStatus.RETRYING) {
                return null; // 如果状态已经改变，则不更新
            }
            
            existingTask.setStatus(TaskStatus.RUNNING);
            existingTask.setExecutionNodeId(executionNodeId != null ? executionNodeId : hostIdentifier);
            existingTask.setLastAttemptTimestamp(Instant.now());
            
            // 记录本地处理的任务
            localProcessingTasks.put(taskId, Boolean.TRUE);
            
            return existingTask;
        }).isPresent();
    }
    
    @Override
    public Optional<BackgroundTask> recordProgress(String taskId, Object progress) {
        return updateWithOptimisticLock(taskId, existingTask -> {
            if (existingTask.getStatus() != TaskStatus.RUNNING) {
                logger.warn("任务 {} 的状态为 {}，不能更新进度", taskId, existingTask.getStatus());
                return null; // 如果任务不在运行中，则不更新进度
            }
            
            existingTask.setProgress(progress);
            return existingTask;
        });
    }
    
    @Override
    public Optional<BackgroundTask> recordCompletion(String taskId, Object result) {
        Optional<BackgroundTask> updatedTask = updateWithOptimisticLock(taskId, existingTask -> {
            if (existingTask.getStatus() != TaskStatus.RUNNING) {
                logger.warn("任务 {} 的状态为 {}，不能标记为完成", taskId, existingTask.getStatus());
                return null; // 如果任务不在运行中，则不更新
            }
            
            existingTask.setStatus(TaskStatus.COMPLETED);
            existingTask.setResult(result);
            return existingTask;
        });
        
        // 任务完成后从本地处理映射中移除
        localProcessingTasks.remove(taskId);
        
        return updatedTask;
    }
    
    @Override
    public Optional<BackgroundTask> recordFailure(String taskId, Map<String, Object> errorInfo, boolean isDeadLetter) {
        Optional<BackgroundTask> updatedTask = updateWithOptimisticLock(taskId, existingTask -> {
            TaskStatus newStatus = isDeadLetter ? TaskStatus.DEAD_LETTER : TaskStatus.FAILED;
            existingTask.setStatus(newStatus);
            existingTask.setErrorInfo(errorInfo);
            return existingTask;
        });
        
        // 任务失败后从本地处理映射中移除
        localProcessingTasks.remove(taskId);
        
        return updatedTask;
    }
    
    @Override
    public Optional<BackgroundTask> recordRetrying(String taskId, Map<String, Object> errorInfo, Instant nextAttemptTimestamp) {
        return updateWithOptimisticLock(taskId, existingTask -> {
            existingTask.setStatus(TaskStatus.RETRYING);
            existingTask.setErrorInfo(errorInfo);
            existingTask.setNextAttemptTimestamp(nextAttemptTimestamp);
            existingTask.incrementRetryCount();
            return existingTask;
        });
    }
    
    @Override
    public Optional<BackgroundTask> updateSubTaskStatusSummary(String parentTaskId, String statusKey, int delta) {
        return updateWithOptimisticLock(parentTaskId, existingTask -> {
            Map<String, Integer> summary = existingTask.getSubTaskStatusSummary();
            if (summary == null) {
                summary = new HashMap<>();
                existingTask.setSubTaskStatusSummary(summary);
            }
            
            int currentCount = summary.getOrDefault(statusKey, 0);
            summary.put(statusKey, currentCount + delta);
            
            // 检查是否所有子任务都已完成或失败，可能需要更新父任务状态
            // 这里需要知道子任务总数，可能从参数或进度中获取
            // 简化的实现：如果有失败但不是全部，则设为COMPLETED_WITH_ERRORS
            if ("completed".equals(statusKey) || "failed".equals(statusKey)) {
                int totalSubTasks = summary.values().stream().mapToInt(Integer::intValue).sum();
                int failedTasks = summary.getOrDefault("failed", 0);
                
                // 假设任务类型或父任务参数中存储了子任务总数
                Object progress = existingTask.getProgress();
                int expectedTotal = -1;
                if (progress instanceof Map) {
                    try {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> progressMap = (Map<String, Object>) progress;
                        if (progressMap.containsKey("totalSubTasks")) {
                            expectedTotal = ((Number) progressMap.get("totalSubTasks")).intValue();
                        }
                    } catch (Exception e) {
                        logger.warn("无法从进度中提取子任务总数", e);
                    }
                }
                
                // 如果已知预期总数并且所有子任务已完成
                if (expectedTotal > 0 && totalSubTasks >= expectedTotal) {
                    if (failedTasks == 0) {
                        existingTask.setStatus(TaskStatus.COMPLETED);
                    } else if (failedTasks < expectedTotal) {
                        existingTask.setStatus(TaskStatus.COMPLETED_WITH_ERRORS);
                    } else {
                        existingTask.setStatus(TaskStatus.FAILED);
                    }
                }
            }
            
            return existingTask;
        });
    }
    
    @Override
    public Optional<BackgroundTask> findById(String taskId) {
        return taskRepository.findById(taskId);
    }
    
    @Override
    public Optional<BackgroundTask> findByIdAndUserId(String taskId, String userId) {
        Optional<BackgroundTask> taskOpt = taskRepository.findById(taskId);
        return taskOpt.filter(task -> task.getUserId().equals(userId));
    }
    
    @Override
    public Optional<BackgroundTask> cancelTask(String taskId) {
        return updateWithOptimisticLock(taskId, existingTask -> {
            // 如果任务已完成或已失败或已是死信，则不能取消
            if (existingTask.getStatus() == TaskStatus.COMPLETED ||
                existingTask.getStatus() == TaskStatus.FAILED ||
                existingTask.getStatus() == TaskStatus.DEAD_LETTER) {
                
                logger.info("任务 {} 当前状态为 {}，不能取消", taskId, existingTask.getStatus());
                return null;
            }
            
            existingTask.setStatus(TaskStatus.CANCELLED);
            return existingTask;
        });
    }
    
    /**
     * 带有乐观锁的更新操作，在冲突时自动重试
     * @param taskId 任务ID
     * @param updateFunction 更新函数，接收当前任务并返回更新后的任务或null（如果不应更新）
     * @return 更新后的任务，如果不应更新或更新失败则返回空
     */
    private Optional<BackgroundTask> updateWithOptimisticLock(String taskId, Function<BackgroundTask, BackgroundTask> updateFunction) {
        int attempts = 0;
        while (attempts < MAX_RETRY_ATTEMPTS) {
            try {
                Optional<BackgroundTask> taskOpt = taskRepository.findById(taskId);
                if (taskOpt.isEmpty()) {
                    logger.warn("任务不存在: {}", taskId);
                    return Optional.empty();
                }
                
                BackgroundTask existingTask = taskOpt.get();
                BackgroundTask updatedTask = updateFunction.apply(existingTask);
                
                if (updatedTask == null) {
                    // 更新函数指示不应更新
                    return Optional.empty();
                }
                
                return Optional.of(taskRepository.save(updatedTask));
            } catch (OptimisticLockingFailureException e) {
                attempts++;
                if (attempts >= MAX_RETRY_ATTEMPTS) {
                    logger.error("更新任务 {} 失败，乐观锁冲突，已达到最大重试次数", taskId, e);
                    throw e;
                }
                logger.warn("更新任务 {} 时发生乐观锁冲突，尝试重试 ({}/{})", taskId, attempts, MAX_RETRY_ATTEMPTS);
                
                // 短暂延迟后重试
                try {
                    Thread.sleep(50 * attempts);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new RuntimeException("乐观锁重试被中断", ie);
                }
            }
        }
        
        // 这里不应该到达，因为超过重试次数时会抛出异常
        return Optional.empty();
    }
    
    /**
     * 获取本地节点正在处理的任务IDs
     * @return 任务ID集合
     */
    public Map<String, Boolean> getLocalProcessingTasks() {
        return new HashMap<>(localProcessingTasks);
    }
} 