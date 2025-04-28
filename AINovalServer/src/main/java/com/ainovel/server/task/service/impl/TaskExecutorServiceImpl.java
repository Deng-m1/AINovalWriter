package com.ainovel.server.task.service.impl;

import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.TaskContextImpl;
import com.ainovel.server.task.service.TaskExecutorService;
import com.ainovel.server.task.service.TaskStateService;
import com.ainovel.server.task.model.ExecutionResult;
import com.ainovel.server.task.model.ErrorType;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeoutException;
import java.util.stream.Collectors;

/**
 * 任务执行器服务响应式实现类
 */
@Service
public class TaskExecutorServiceImpl implements TaskExecutorService {

    private static final Logger logger = LoggerFactory.getLogger(TaskExecutorServiceImpl.class);
    
    private final Map<String, BackgroundTaskExecutable<?, ?>> executors = new HashMap<>();
    private final TaskStateService taskStateService;
    
    /**
     * 构造函数，注入所有BackgroundTaskExecutable实现
     * 
     * @param executables 任务执行器列表
     * @param taskStateService 任务状态服务
     */
    @Autowired
    public TaskExecutorServiceImpl(List<BackgroundTaskExecutable<?, ?>> executables, TaskStateService taskStateService) {
        this.taskStateService = taskStateService;
        for (BackgroundTaskExecutable<?, ?> executable : executables) {
            String taskType = executable.getTaskType();
            executors.put(taskType, executable);
            logger.info("已注册任务执行器: {}", taskType);
        }
    }
    
    @Override
    @SuppressWarnings("unchecked")
    public <P, R> Mono<BackgroundTaskExecutable<P, R>> findExecutor(String taskType) {
        BackgroundTaskExecutable<?, ?> executor = executors.get(taskType);
        if (executor == null) {
            logger.warn("找不到任务类型'{}'的执行器", taskType);
            return Mono.empty();
        }
        // 使用不安全的转换，由调用者确保类型安全
        BackgroundTaskExecutable<P, R> typedExecutor = (BackgroundTaskExecutable<P, R>) executor;
        return Mono.just(typedExecutor);
    }
    
    @Override
    public <P, R> Mono<ExecutionResult<R>> executeTask(BackgroundTaskExecutable<P, R> executable, TaskContext<P> context) {
        logger.debug("开始执行任务类型: {}, 任务ID: {}", executable.getTaskType(), context.getTaskId());
        
        long startTime = System.currentTimeMillis();
        
        return executable.execute(context)
            .map(result -> {
                long executionTime = System.currentTimeMillis() - startTime;
                logger.debug("任务执行成功: {}, 任务ID: {}, 耗时: {}ms", executable.getTaskType(), context.getTaskId(), executionTime);
                return ExecutionResult.success(
                    context.getTaskId(),
                    executable.getTaskType(),
                    result,
                    executionTime);
            })
            .onErrorResume(e -> {
                long executionTime = System.currentTimeMillis() - startTime;
                logger.error("任务执行失败: {}, 任务ID: {}, 错误: {}", executable.getTaskType(), context.getTaskId(), e.getMessage());
                
                // 获取堆栈信息
                String stackTrace = null;
                if (e.getStackTrace() != null && e.getStackTrace().length > 0) {
                    StringBuilder sb = new StringBuilder();
                    for (int i = 0; i < Math.min(10, e.getStackTrace().length); i++) {
                        sb.append(e.getStackTrace()[i]).append("\n");
                    }
                    stackTrace = sb.toString();
                }
                
                // 异常分类和错误类型
                ErrorType errorType;
                if (isRetryableException(e)) {
                    if (e instanceof TimeoutException) {
                        errorType = ErrorType.TIMEOUT;
                    } else {
                        errorType = ErrorType.REMOTE_SERVICE_ERROR;
                    }
                } else {
                    errorType = ErrorType.INTERNAL_ERROR;
                }
                
                return Mono.just(ExecutionResult.failure(
                    context.getTaskId(),
                    executable.getTaskType(),
                    e.getMessage(),
                    errorType,
                    stackTrace,
                    executionTime)
                );
            });
    }
    
    @Override
    public Mono<Void> cancelTask(String taskId) {
        return taskStateService.getTask(taskId)
            .flatMap(task -> {
                String taskType = task.getTaskType();
                return findExecutor(taskType)
                    .flatMap(executable -> {
                        if (!executable.isCancellable()) {
                            logger.info("任务类型{}不支持取消", taskType);
                            return Mono.empty();
                        }
                        
                        // 创建一个最小上下文
                        TaskContext<?> context = TaskContextImpl.builder()
                            .taskId(taskId)
                            .taskType(taskType)
                            .userId(task.getUserId())
                            .parameters(task.getParameters())
                            .build();
                        
                        return executable.cancel(context)
                            .then(taskStateService.recordCancellation(taskId));
                    })
                    .switchIfEmpty(Mono.error(new IllegalStateException("无法找到或无法取消任务执行器: " + taskType)));
            })
            .switchIfEmpty(Mono.error(new IllegalStateException("无法找到任务: " + taskId)));
    }
    
    @Override
    public <P> Mono<Integer> getEstimatedExecutionTime(String taskType, TaskContext<P> context) {
        return this.<P, Object>findExecutor(taskType)
            .map(executable -> executable.getEstimatedExecutionTimeSeconds(context))
            .defaultIfEmpty(60); // 默认1分钟
    }
    
    /**
     * 判断异常是否可重试
     * 
     * @param throwable 异常
     * @return 如果可重试返回true，否则返回false
     */
    private boolean isRetryableException(Throwable throwable) {
        // 超时、网络相关、临时服务不可用等异常通常可以重试
        return throwable instanceof TimeoutException
            || throwable.getMessage() != null && (
                throwable.getMessage().contains("timeout") ||
                throwable.getMessage().contains("connection") ||
                throwable.getMessage().contains("temporary") ||
                throwable.getMessage().contains("overload") ||
                throwable.getMessage().contains("limit") ||
                throwable.getMessage().contains("throttl") ||
                throwable.getMessage().contains("retry")
            );
    }
    
    /**
     * 获取已注册的任务类型列表
     * 
     * @return 任务类型列表
     */
    public List<String> getRegisteredTaskTypes() {
        return executors.keySet().stream().collect(Collectors.toList());
    }
} 