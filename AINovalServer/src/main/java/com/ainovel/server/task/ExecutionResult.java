package com.ainovel.server.task;

/**
 * 任务执行结果包装类，用于包装执行结果或异常
 */
public class ExecutionResult<R> {
    private final R result;
    private final Throwable throwable;
    private final boolean retryable;
    
    private ExecutionResult(R result, Throwable throwable, boolean retryable) {
        this.result = result;
        this.throwable = throwable;
        this.retryable = retryable;
    }
    
    /**
     * 创建成功结果
     * @param result 执行结果
     * @param <R> 结果类型
     * @return 执行结果包装
     */
    public static <R> ExecutionResult<R> success(R result) {
        return new ExecutionResult<>(result, null, false);
    }
    
    /**
     * 创建可重试的失败结果
     * @param throwable 导致失败的异常
     * @param <R> 结果类型
     * @return 执行结果包装
     */
    public static <R> ExecutionResult<R> retryableFailure(Throwable throwable) {
        return new ExecutionResult<>(null, throwable, true);
    }
    
    /**
     * 创建不可重试的失败结果
     * @param throwable 导致失败的异常
     * @param <R> 结果类型
     * @return 执行结果包装
     */
    public static <R> ExecutionResult<R> nonRetryableFailure(Throwable throwable) {
        return new ExecutionResult<>(null, throwable, false);
    }
    
    /**
     * 检查是否成功
     * @return 如果成功返回true，否则返回false
     */
    public boolean isSuccess() {
        return throwable == null;
    }
    
    /**
     * 检查是否失败
     * @return 如果失败返回true，否则返回false
     */
    public boolean isFailure() {
        return throwable != null;
    }
    
    /**
     * 检查是否可重试
     * @return 如果可重试返回true，否则返回false
     */
    public boolean isRetryable() {
        return throwable != null && retryable;
    }
    
    /**
     * 获取结果
     * @return 结果对象，如果失败则为null
     */
    public R getResult() {
        return result;
    }
    
    /**
     * 获取异常
     * @return 异常对象，如果成功则为null
     */
    public Throwable getThrowable() {
        return throwable;
    }
} 