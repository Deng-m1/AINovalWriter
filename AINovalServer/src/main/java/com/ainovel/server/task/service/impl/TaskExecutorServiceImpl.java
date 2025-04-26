package com.ainovel.server.task.service.impl;

import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.ExecutionResult;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.service.TaskExecutorService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeoutException;

/**
 * 任务执行器服务实现类
 */
@Service
public class TaskExecutorServiceImpl implements TaskExecutorService {

    private static final Logger logger = LoggerFactory.getLogger(TaskExecutorServiceImpl.class);
    
    private final Map<String, BackgroundTaskExecutable<?, ?>> executors = new HashMap<>();
    
    /**
     * 构造函数，注入所有BackgroundTaskExecutable实现
     * 
     * @param executables 任务执行器列表
     */
    @Autowired
    public TaskExecutorServiceImpl(List<BackgroundTaskExecutable<?, ?>> executables) {
        for (BackgroundTaskExecutable<?, ?> executable : executables) {
            String taskType = executable.getTaskType();
            executors.put(taskType, executable);
            logger.info("已注册任务执行器: {}", taskType);
        }
    }
    
    @Override
    public BackgroundTaskExecutable<?, ?> findExecutor(String taskType) {
        BackgroundTaskExecutable<?, ?> executor = executors.get(taskType);
        if (executor == null) {
            logger.warn("找不到任务类型'{}'的执行器", taskType);
        }
        return executor;
    }
    
    @Override
    @SuppressWarnings("unchecked")
    public <P, R> ExecutionResult<R> executeTask(BackgroundTaskExecutable<P, R> executable, TaskContext<P> context) {
        if (executable == null) {
            logger.error("无法执行null执行器");
            return ExecutionResult.nonRetryableFailure(new IllegalArgumentException("执行器不能为null"));
        }
        
        if (context == null) {
            logger.error("无法执行任务，context为null");
            return ExecutionResult.nonRetryableFailure(new IllegalArgumentException("上下文不能为null"));
        }
        
        logger.info("开始执行任务: [{}]", context.getTaskId());
        
        try {
            // 从上下文中获取参数
            P parameters = context.getParameters();
            R result = executable.execute(parameters, context);
            logger.info("任务执行成功: [{}]", context.getTaskId());
            return ExecutionResult.success(result);
        } catch (Exception e) {
            logger.error("任务执行失败: [{}]: {}", context.getTaskId(), e.getMessage(), e);
            
            // 异常分类
            if (isRetryableException(e)) {
                logger.info("异常被归类为可重试: [{}]", context.getTaskId());
                return ExecutionResult.retryableFailure(e);
            } else {
                logger.info("异常被归类为不可重试: [{}]", context.getTaskId());
                return ExecutionResult.nonRetryableFailure(e);
            }
        }
    }
    
    /**
     * 判断异常是否可重试
     * 
     * @param e 异常
     * @return 如果异常可以重试则返回true，否则返回false
     */
    private boolean isRetryableException(Exception e) {
        // 网络超时、连接错误、资源暂时不可用等可以重试
        if (e instanceof TimeoutException ||
                e instanceof java.net.SocketTimeoutException ||
                e instanceof java.net.ConnectException ||
                e instanceof java.io.IOException ||
                e instanceof java.util.concurrent.TimeoutException) {
            return true;
        }
        
        // 服务不可用、拒绝连接、负载过高等也可以重试
        if (e.getMessage() != null &&
                (e.getMessage().contains("service unavailable") ||
                 e.getMessage().contains("connection refused") ||
                 e.getMessage().contains("too many requests") ||
                 e.getMessage().contains("server busy") ||
                 e.getMessage().contains("retry") ||
                 e.getMessage().contains("timeout"))) {
            return true;
        }
        
        // 数据库乐观锁冲突等并发问题可以重试
        if (e instanceof org.springframework.dao.OptimisticLockingFailureException) {
            return true;
        }
        
        // 其他情况通常不可重试
        return false;
    }
} 