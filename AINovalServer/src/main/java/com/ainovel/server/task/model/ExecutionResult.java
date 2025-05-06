package com.ainovel.server.task.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 任务执行结果模型
 * 包含任务执行的结果或异常信息
 * @param <R> 结果类型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ExecutionResult<R> {
    
    /**
     * 任务ID
     */
    private String taskId;
    
    /**
     * 任务类型
     */
    private String taskType;
    
    /**
     * 执行结果
     */
    private R result;
    
    /**
     * 是否成功
     */
    private boolean success;
    
    /**
     * 错误信息
     */
    private String errorMessage;
    
    /**
     * 错误类型
     */
    private ErrorType errorType;
    
    /**
     * 异常堆栈（开发环境使用）
     */
    private String stackTrace;
    
    /**
     * 执行耗时（毫秒）
     */
    private long executionTimeMs;
    
    /**
     * 创建成功的执行结果
     * @param taskId 任务ID
     * @param taskType 任务类型
     * @param result 结果对象
     * @param executionTimeMs 执行耗时（毫秒）
     * @return 执行结果对象
     */
    public static <R> ExecutionResult<R> success(
            String taskId, String taskType, R result, long executionTimeMs) {
        return ExecutionResult.<R>builder()
                .taskId(taskId)
                .taskType(taskType)
                .result(result)
                .success(true)
                .executionTimeMs(executionTimeMs)
                .build();
    }
    
    /**
     * 创建失败的执行结果
     * @param taskId 任务ID
     * @param taskType 任务类型
     * @param errorMessage 错误信息
     * @param errorType 错误类型
     * @param stackTrace 异常堆栈
     * @param executionTimeMs 执行耗时（毫秒）
     * @return 执行结果对象
     */
    public static <R> ExecutionResult<R> failure(
            String taskId, 
            String taskType, 
            String errorMessage, 
            ErrorType errorType,
            String stackTrace,
            long executionTimeMs) {
        return ExecutionResult.<R>builder()
                .taskId(taskId)
                .taskType(taskType)
                .success(false)
                .errorMessage(errorMessage)
                .errorType(errorType)
                .stackTrace(stackTrace)
                .executionTimeMs(executionTimeMs)
                .build();
    }
} 