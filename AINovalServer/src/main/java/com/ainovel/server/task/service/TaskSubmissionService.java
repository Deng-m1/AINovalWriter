package com.ainovel.server.task.service;

import java.util.UUID;

/**
 * 任务提交服务接口
 */
public interface TaskSubmissionService {
    
    /**
     * 提交任务
     * 
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @param parentTaskId 父任务ID (可选)
     * @return 创建的任务ID
     */
    String submitTask(String userId, String taskType, Object parameters, String parentTaskId);
    
    /**
     * 提交任务（无父任务）
     * 
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @return 创建的任务ID
     */
    default String submitTask(String userId, String taskType, Object parameters) {
        return submitTask(userId, taskType, parameters, null);
    }
    
    /**
     * 提交任务，使用自动生成的任务ID
     * 
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @param parentTaskId 父任务ID (可选)
     * @return 创建的任务ID
     */
    default String submitTaskWithGeneratedId(String userId, String taskType, Object parameters, String parentTaskId) {
        String taskId = UUID.randomUUID().toString();
        return submitTask(userId, taskType, parameters, parentTaskId);
    }
    
    /**
     * 提交任务，使用自动生成的任务ID（无父任务）
     * 
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @return 创建的任务ID
     */
    default String submitTaskWithGeneratedId(String userId, String taskType, Object parameters) {
        return submitTaskWithGeneratedId(userId, taskType, parameters, null);
    }
    
    /**
     * 获取任务状态
     * 
     * @param taskId 任务ID
     * @return 任务状态的JSON表示
     */
    Object getTaskStatus(String taskId);
    
    /**
     * 获取任务状态，包含验证用户权限
     * 
     * @param taskId 任务ID
     * @param userId 用户ID
     * @return 任务状态的JSON表示
     */
    Object getTaskStatus(String taskId, String userId);
    
    /**
     * 取消任务
     * 
     * @param taskId 任务ID
     * @return 是否成功取消
     */
    boolean cancelTask(String taskId);
    
    /**
     * 取消任务，包含验证用户权限
     * 
     * @param taskId 任务ID
     * @param userId 用户ID
     * @return 是否成功取消
     */
    boolean cancelTask(String taskId, String userId);
} 