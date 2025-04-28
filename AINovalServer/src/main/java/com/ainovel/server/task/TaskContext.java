package com.ainovel.server.task;

import reactor.core.publisher.Mono;

/**
 * 任务上下文接口，提供任务执行过程中所需的上下文信息和回调方法
 * @param <P> 任务参数类型
 */
public interface TaskContext<P> {
    
    /**
     * 获取任务ID
     * @return 任务ID
     */
    String getTaskId();
    
    /**
     * 获取任务类型
     * @return 任务类型
     */
    String getTaskType();
    
    /**
     * 获取用户ID
     * @return 用户ID
     */
    String getUserId();
    
    /**
     * 获取任务参数
     * @return 任务参数
     */
    P getParameters();
    
    /**
     * 获取执行节点ID
     * @return 执行节点ID
     */
    String getExecutionNodeId();
    
    /**
     * 获取父任务ID，如果有的话
     * @return 父任务ID，如果没有则为null
     */
    String getParentTaskId();
    
    /**
     * 更新任务进度
     * @param progressData 进度数据
     * @return 更新操作的完成信号
     */
    Mono<Void> updateProgress(Object progressData);
    
    /**
     * 记录信息日志
     * @param message 日志消息
     * @return 记录操作的完成信号
     */
    Mono<Void> logInfo(String message);
    
    /**
     * 记录错误日志
     * @param message 日志消息
     * @param error 错误对象（可选）
     * @return 记录操作的完成信号
     */
    Mono<Void> logError(String message, Throwable error);
    
    /**
     * 提交子任务
     * @param taskType 子任务类型
     * @param parameters 子任务参数
     * @return 子任务ID的Mono
     */
    Mono<String> submitSubTask(String taskType, Object parameters);
} 