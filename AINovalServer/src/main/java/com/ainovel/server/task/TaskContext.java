package com.ainovel.server.task;

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
     * 获取用户ID
     * @return 用户ID
     */
    String getUserId();
    
    /**
     * 获取任务类型
     * @return 任务类型
     */
    String getTaskType();
    
    /**
     * 获取父任务ID（如果存在）
     * @return 父任务ID，如果不是子任务则返回null
     */
    String getParentTaskId();
    
    /**
     * 获取参数对象
     * @return 参数对象
     */
    P getParameters();
    
    /**
     * 更新任务进度
     * @param progress 进度对象
     */
    void updateProgress(Object progress);
    
    /**
     * 记录信息日志
     * @param message 日志消息
     * @param args 格式化参数
     */
    void logInfo(String message, Object... args);
    
    /**
     * 记录错误日志
     * @param message 日志消息
     * @param args 格式化参数
     */
    void logError(String message, Object... args);
    
    /**
     * 记录错误日志（包含异常）
     * @param message 日志消息
     * @param throwable 异常
     * @param args 格式化参数
     */
    void logError(String message, Throwable throwable, Object... args);
    
    /**
     * 提交子任务
     * @param taskType 子任务类型
     * @param parameters 子任务参数
     * @return 子任务ID
     */
    String submitSubTask(String taskType, Object parameters);
} 