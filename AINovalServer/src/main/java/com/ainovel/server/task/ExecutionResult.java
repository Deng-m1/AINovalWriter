package com.ainovel.server.task;

import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.Getter;

/**
 * 任务执行结果封装类，包含结果数据和异常信息
 * @param <R> 结果类型
 */
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Data
public class ExecutionResult<R> {
    
    /**
     * 执行结果数据（仅在成功时有值）
     */
    private final R result;
    
    /**
     * 异常信息（仅在失败时有值）
     */
    private final Throwable error;
    
    /**
     * 执行结果状态
     */
    private final ExecutionStatus status;
    
    /**
     * 创建成功的执行结果
     * @param <R> 结果类型
     * @param result 执行结果数据
     * @return 成功执行结果
     */
    public static <R> ExecutionResult<R> success(R result) {
        return new ExecutionResult<>(result, null, ExecutionStatus.SUCCESS);
    }
    
    /**
     * 创建可重试失败的执行结果
     * @param <R> 结果类型
     * @param error 异常信息
     * @return 可重试失败执行结果
     */
    public static <R> ExecutionResult<R> retryableFailure(Throwable error) {
        return new ExecutionResult<>(null, error, ExecutionStatus.RETRYABLE_FAILURE);
    }
    
    /**
     * 创建不可重试失败的执行结果
     * @param <R> 结果类型
     * @param error 异常信息
     * @return 不可重试失败执行结果
     */
    public static <R> ExecutionResult<R> nonRetryableFailure(Throwable error) {
        return new ExecutionResult<>(null, error, ExecutionStatus.NON_RETRYABLE_FAILURE);
    }
    
    /**
     * 创建已取消的执行结果
     * @param <R> 结果类型
     * @return 已取消执行结果
     */
    public static <R> ExecutionResult<R> cancelled() {
        return new ExecutionResult<>(null, null, ExecutionStatus.CANCELLED);
    }
    
    /**
     * 判断是否执行成功
     * @return 是否成功
     */
    public boolean isSuccess() {
        return status == ExecutionStatus.SUCCESS;
    }
    
    /**
     * 判断是否为可重试失败
     * @return 是否可重试
     */
    public boolean isRetryable() {
        return status == ExecutionStatus.RETRYABLE_FAILURE;
    }
    
    /**
     * 判断是否为不可重试失败
     * @return 是否不可重试
     */
    public boolean isNonRetryable() {
        return status == ExecutionStatus.NON_RETRYABLE_FAILURE;
    }
    
    /**
     * 判断是否已取消
     * @return 是否已取消
     */
    public boolean isCancelled() {
        return status == ExecutionStatus.CANCELLED;
    }
    
    /**
     * 执行结果状态枚举
     */
    public enum ExecutionStatus {
        /**
         * 执行成功
         */
        SUCCESS,
        
        /**
         * 可重试的失败
         */
        RETRYABLE_FAILURE,
        
        /**
         * 不可重试的失败
         */
        NON_RETRYABLE_FAILURE,
        
        /**
         * 已取消
         */
        CANCELLED
    }
} 