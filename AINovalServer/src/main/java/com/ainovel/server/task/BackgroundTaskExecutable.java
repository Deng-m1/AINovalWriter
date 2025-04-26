package com.ainovel.server.task;

/**
 * 后台任务执行器接口
 * @param <P> 任务参数类型
 * @param <R> 任务结果类型
 */
public interface BackgroundTaskExecutable<P, R> {
    
    /**
     * 执行任务
     * @param parameters 任务参数
     * @param context 任务上下文，用于更新进度、记录日志等
     * @return 任务结果
     * @throws Exception 执行过程中的异常
     */
    R execute(P parameters, TaskContext<P> context) throws Exception;
    
    /**
     * 获取任务类型标识符
     * @return 任务类型字符串
     */
    String getTaskType();
    
    /**
     * 获取参数类型的Class
     * @return 参数类型的Class对象
     */
    Class<P> getParameterType();
    
    /**
     * 获取结果类型的Class
     * @return 结果类型的Class对象
     */
    Class<R> getResultType();
    
    /**
     * 是否允许在失败时重试（默认允许）
     * @param throwable 导致失败的异常
     * @return 如果允许重试返回true，否则返回false
     */
    default boolean isRetryable(Throwable throwable) {
        return true;
    }
    
    /**
     * 获取任务最大重试次数（默认3次）
     * @return 最大重试次数
     */
    default int getMaxRetries() {
        return 3;
    }
} 