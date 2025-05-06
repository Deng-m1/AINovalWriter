package com.ainovel.server.task.service;

import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.model.ExecutionResult;

import reactor.core.publisher.Mono;


import reactor.core.publisher.Mono;

/**
 * 任务执行器服务接口
 * 负责查找和执行对应类型的后台任务
 */
public interface TaskExecutorService {
    
    /**
     * 查找指定类型的任务执行器
     * 
     * @param taskType 任务类型标识
     * @return 任务执行器的Mono，如果找不到则返回空Mono
     */
    <P, R> Mono<BackgroundTaskExecutable<P, R>> findExecutor(String taskType);
    
    /**
     * 执行任务
     * 
     * @param executable 任务执行器
     * @param context 任务上下文
     * @return 执行结果的Mono，包含成功结果或分类后的异常
     */
    <P, R> Mono<com.ainovel.server.task.ExecutionResult<R>> executeTask(
        BackgroundTaskExecutable<P, R> executable, 
        TaskContext<P> context);
    
    /**
     * 取消任务
     * 
     * @param taskId 任务ID
     * @return 表示取消操作完成的Mono
     */
    Mono<Void> cancelTask(String taskId);
    
    /**
     * 获取任务的估计执行时间
     * 
     * @param taskType 任务类型
     * @param context 任务上下文
     * @return 估计执行时间（秒）的Mono
     */
    <P> Mono<Integer> getEstimatedExecutionTime(String taskType, TaskContext<P> context);
} 