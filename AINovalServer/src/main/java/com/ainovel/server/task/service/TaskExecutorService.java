package com.ainovel.server.task.service;

import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.ExecutionResult;
import com.ainovel.server.task.TaskContext;

/**
 * 任务执行器服务接口，负责查找和调用任务执行器
 */
public interface TaskExecutorService {
    
    /**
     * 根据任务类型查找执行器
     * 
     * @param taskType 任务类型
     * @return 找到的执行器，如果没有找到则返回null
     */
    BackgroundTaskExecutable<?, ?> findExecutor(String taskType);
    
    /**
     * 执行任务
     * 
     * @param <P> 参数类型
     * @param <R> 结果类型
     * @param executable 任务执行器
     * @param context 任务上下文
     * @return 执行结果包装，包含结果或异常信息
     */
    <P, R> ExecutionResult<R> executeTask(BackgroundTaskExecutable<P, R> executable, TaskContext<P> context);
    
} 