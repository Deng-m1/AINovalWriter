package com.ainovel.server.task.consumer;

import com.ainovel.server.config.RabbitMQConfig;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.ExecutionResult;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.TaskContextImpl;
import com.ainovel.server.task.event.internal.*;
import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.producer.TaskMessageProducer;
import com.ainovel.server.task.service.TaskExecutorService;
import com.ainovel.server.task.service.TaskStateService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rabbitmq.client.Channel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 任务消费者，负责处理RabbitMQ中的任务消息
 */
@Component
public class TaskConsumer {

    private static final Logger logger = LoggerFactory.getLogger(TaskConsumer.class);
    private static final int MAX_RETRY_ATTEMPTS = 3;
    
    private final TaskExecutorService taskExecutorService;
    private final TaskStateService taskStateService;
    private final ApplicationEventPublisher eventPublisher;
    private final ObjectMapper objectMapper;
    private final TaskMessageProducer taskMessageProducer;
    private final String hostIdentifier;
    
    @Value("${task.retry.initial-delay-ms:15000}")
    private long initialRetryDelayMs = 15000;
    
    @Value("${task.retry.delay-multiplier:2}")
    private int retryDelayMultiplier = 2;
    
    @Autowired
    public TaskConsumer(TaskExecutorService taskExecutorService,
                       TaskStateService taskStateService,
                       ApplicationEventPublisher eventPublisher,
                       ObjectMapper objectMapper,
                       TaskMessageProducer taskMessageProducer) {
        this.taskExecutorService = taskExecutorService;
        this.taskStateService = taskStateService;
        this.eventPublisher = eventPublisher;
        this.objectMapper = objectMapper;
        this.taskMessageProducer = taskMessageProducer;
        
        // 获取主机标识符，用于标识任务执行节点
        String tempHostId;
        try {
            tempHostId = InetAddress.getLocalHost().getHostName() + "-" + UUID.randomUUID().toString().substring(0, 8);
        } catch (UnknownHostException e) {
            tempHostId = "unknown-" + UUID.randomUUID().toString().substring(0, 8);
            logger.warn("无法获取主机名，使用随机ID: {}", tempHostId, e);
        }
        this.hostIdentifier = tempHostId;
        logger.info("任务消费者已初始化，主机标识符: {}", hostIdentifier);
    }
    
    /**
     * 处理任务消息
     * 
     * @param message 消息对象
     * @param channel RabbitMQ通道
     * @throws IOException 如果消息处理过程中发生IO错误
     */
    @RabbitListener(queues = RabbitMQConfig.TASKS_QUEUE)
    public void handleTaskMessage(Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        String taskId = null;
        
        try {
            // 获取消息属性
            MessageProperties properties = message.getMessageProperties();
            taskId = properties.getHeader("x-task-id");
            String userId = properties.getHeader("x-user-id");
            String taskType = properties.getHeader("x-task-type");
            int retryCount = properties.getHeader("x-retry-count") != null ? 
                    (int) properties.getHeader("x-retry-count") : 0;
            
            logger.info("收到任务消息: {} [类型: {}, 用户: {}, 重试次数: {}]", 
                    taskId, taskType, userId, retryCount);
            
            // 幂等性检查：尝试将任务状态设置为RUNNING
            boolean canProcess = taskStateService.trySetRunning(taskId, hostIdentifier);
            if (!canProcess) {
                logger.info("任务 {} 已被其他消费者处理或状态不允许处理，跳过", taskId);
                
                // 确认消息已处理，避免重复消费
                channel.basicAck(deliveryTag, false);
                return;
            }
            
            // 发布任务开始事件
            publishTaskStartedEvent(taskId, taskType, userId);
            
            // 反序列化消息体为参数对象
            Object parameters = deserializeMessageBody(message, taskType);
            
            // 查找任务执行器
            BackgroundTaskExecutable<?, ?> executor = taskExecutorService.findExecutor(taskType);
            if (executor == null) {
                handleExecutorNotFound(taskId, taskType, deliveryTag, channel);
                return;
            }
            
            // 获取任务数据，包括parentTaskId
            Optional<BackgroundTask> taskOpt = taskStateService.findById(taskId);
            String parentTaskId = taskOpt.map(BackgroundTask::getParentTaskId).orElse(null);
            
            // 创建任务上下文
            TaskContext<?> context = createTaskContext(taskId, userId, taskType, parentTaskId, parameters);
            
            // 执行任务
            ExecutionResult<?> result = executeTask(executor, context);
            
            // 处理执行结果
            if (result.isSuccess()) {
                handleTaskSuccess(taskId, taskType, userId, result.getResult(), deliveryTag, channel);
            } else {
                handleTaskFailure(taskId, taskType, userId, result.getThrowable(), 
                        result.isRetryable(), retryCount, deliveryTag, channel);
            }
            
        } catch (Exception e) {
            logger.error("处理任务消息时发生错误: {}", taskId, e);
            
            // 在消费者异常情况下，通常应该拒绝消息并让其进入死信队列
            // 否则如果简单地重新入队，可能会导致无限循环处理
            try {
                Map<String, Object> errorInfo = createErrorInfo(e);
                
                // 记录任务失败，标记为死信
                if (taskId != null) {
                    taskStateService.recordFailure(taskId, errorInfo, true);
                    
                    // 尝试发布失败事件
                    try {
                        publishTaskFailedEvent(taskId, "Unknown", "Unknown", errorInfo, true);
                    } catch (Exception eventEx) {
                        logger.error("发布任务失败事件时发生错误: {}", taskId, eventEx);
                    }
                }
                
                // 拒绝消息，不重新入队（进入死信队列）
                channel.basicNack(deliveryTag, false, false);
            } catch (Exception ex) {
                logger.error("处理消息异常时出错，将关闭通道: {}", taskId, ex);
                // 在严重错误情况下，关闭通道可能是最安全的做法
                // 这会触发RabbitMQ重新投递消息
                try {
                    channel.close();
                } catch (Exception closeEx) {
                    logger.error("关闭通道时出错", closeEx);
                }
            }
        }
    }
    
    /**
     * 执行任务
     */
    @SuppressWarnings("unchecked")
    private <P> ExecutionResult<?> executeTask(BackgroundTaskExecutable<?, ?> executor, TaskContext<P> context) {
        try {
            // 类型擦除和强制转换是必要的，因为我们在运行时不知道确切类型
            BackgroundTaskExecutable<P, ?> typedExecutor = (BackgroundTaskExecutable<P, ?>) executor;
            return taskExecutorService.executeTask(typedExecutor, context);
        } catch (ClassCastException e) {
            logger.error("任务参数类型不匹配: {}", context.getTaskId(), e);
            return ExecutionResult.nonRetryableFailure(
                    new IllegalArgumentException("参数类型不匹配: " + e.getMessage()));
        }
    }
    
    /**
     * 处理任务执行器未找到的情况
     */
    private void handleExecutorNotFound(String taskId, String taskType, long deliveryTag, Channel channel) throws IOException {
        logger.error("找不到任务类型 {} 的执行器", taskType);
        
        Map<String, Object> errorInfo = new HashMap<>();
        errorInfo.put("message", "找不到任务执行器: " + taskType);
        errorInfo.put("timestamp", Instant.now().toString());
        
        // 记录任务失败，标记为死信
        taskStateService.recordFailure(taskId, errorInfo, true);
        
        // 发布任务失败事件
        publishTaskFailedEvent(taskId, taskType, "Unknown", errorInfo, true);
        
        // 拒绝消息，不重新入队（进入死信队列）
        channel.basicNack(deliveryTag, false, false);
    }
    
    /**
     * 处理任务执行成功的情况
     */
    private void handleTaskSuccess(String taskId, String taskType, String userId, 
                                  Object result, long deliveryTag, Channel channel) throws IOException {
        logger.info("任务执行成功: {}", taskId);
        
        // 记录任务完成
        taskStateService.recordCompletion(taskId, result);
        
        // 发布任务完成事件
        publishTaskCompletedEvent(taskId, taskType, userId, result);
        
        // 确认消息已处理
        channel.basicAck(deliveryTag, false);
    }
    
    /**
     * 处理任务执行失败的情况
     */
    private void handleTaskFailure(String taskId, String taskType, String userId, 
                                  Throwable throwable, boolean retryable, 
                                  int retryCount, long deliveryTag, Channel channel) throws IOException {
        // 创建错误信息
        Map<String, Object> errorInfo = createErrorInfo(throwable);
        
        // 判断是否需要重试
        boolean shouldRetry = retryable && retryCount < MAX_RETRY_ATTEMPTS;
        
        if (shouldRetry) {
            handleTaskRetry(taskId, taskType, userId, errorInfo, retryCount, deliveryTag, channel);
        } else {
            handleTaskFinalFailure(taskId, taskType, userId, errorInfo, deliveryTag, channel);
        }
    }
    
    /**
     * 处理任务需要重试的情况
     */
    private void handleTaskRetry(String taskId, String taskType, String userId, 
                                Map<String, Object> errorInfo, int retryCount, 
                                long deliveryTag, Channel channel) throws IOException {
        int newRetryCount = retryCount + 1;
        
        // 计算下一次重试的延迟时间
        long delayMs = calculateRetryDelay(newRetryCount);
        Instant nextAttemptTimestamp = Instant.now().plusMillis(delayMs);
        
        logger.info("任务 {} 将在 {} 后重试, 当前重试次数: {}", 
                taskId, formatDuration(delayMs), newRetryCount);
        
        // 记录任务重试状态
        taskStateService.recordRetrying(taskId, errorInfo, nextAttemptTimestamp);
        
        // 发布任务重试事件
        publishTaskRetryingEvent(taskId, taskType, userId, errorInfo, 
                newRetryCount, MAX_RETRY_ATTEMPTS, nextAttemptTimestamp);
        
        // 选择合适的重试方式
        boolean requeued = requeueForRetry(taskId, userId, taskType, errorInfo, newRetryCount);
        
        if (requeued) {
            // 确认消息已处理
            channel.basicAck(deliveryTag, false);
        } else {
            // 如果重新入队失败，拒绝消息并进入死信队列
            logger.error("任务 {} 重新入队失败，放入死信队列", taskId);
            channel.basicNack(deliveryTag, false, false);
        }
    }
    
    /**
     * 处理任务最终失败的情况
     */
    private void handleTaskFinalFailure(String taskId, String taskType, String userId, 
                                      Map<String, Object> errorInfo, long deliveryTag, 
                                      Channel channel) throws IOException {
        logger.error("任务 {} 执行失败，不再重试", taskId);
        
        // 记录任务失败，标记为死信
        taskStateService.recordFailure(taskId, errorInfo, true);
        
        // 发布任务失败事件
        publishTaskFailedEvent(taskId, taskType, userId, errorInfo, true);
        
        // 拒绝消息，不重新入队（进入死信队列）
        channel.basicNack(deliveryTag, false, false);
    }
    
    /**
     * 将任务重新入队以进行重试
     */
    private boolean requeueForRetry(String taskId, String userId, String taskType, 
                                   Object parameters, int retryCount) {
        try {
            // 使用TaskMessageProducer发送到重试交换机
            return taskMessageProducer.sendToRetryExchange(taskId, userId, taskType, parameters, retryCount);
        } catch (Exception e) {
            logger.error("将任务 {} 重新入队失败: {}", taskId, e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * 创建任务上下文对象
     */
    @SuppressWarnings("unchecked")
    private <P> TaskContext<P> createTaskContext(String taskId, String userId, 
                                              String taskType, String parentTaskId, 
                                              Object parameters) {
        return new TaskContextImpl<>(
                taskId,
                userId,
                taskType,
                parentTaskId,
                (P) parameters,
                hostIdentifier,
                eventPublisher,
                taskStateService,
                taskMessageProducer
        );
    }
    
    /**
     * 反序列化消息体
     */
    private Object deserializeMessageBody(Message message, String taskType) throws IOException {
        try {
            return objectMapper.readValue(message.getBody(), Object.class);
        } catch (IOException e) {
            logger.error("无法反序列化任务 {} 的消息体: {}", taskType, e.getMessage(), e);
            throw new IOException("反序列化失败: " + e.getMessage(), e);
        }
    }
    
    /**
     * 创建异常的错误信息
     */
    private Map<String, Object> createErrorInfo(Throwable throwable) {
        Map<String, Object> errorInfo = new HashMap<>();
        errorInfo.put("message", throwable.getMessage());
        errorInfo.put("exceptionClass", throwable.getClass().getName());
        errorInfo.put("timestamp", Instant.now().toString());
        
        // 添加堆栈跟踪（前10个元素）
        StackTraceElement[] stackTrace = throwable.getStackTrace();
        String[] stackTraceLines = new String[Math.min(10, stackTrace.length)];
        for (int i = 0; i < stackTraceLines.length; i++) {
            stackTraceLines[i] = stackTrace[i].toString();
        }
        errorInfo.put("stackTrace", stackTraceLines);
        
        // 添加根本原因
        Throwable cause = throwable.getCause();
        if (cause != null) {
            errorInfo.put("cause", cause.getMessage());
            errorInfo.put("causeClass", cause.getClass().getName());
        }
        
        return errorInfo;
    }
    
    /**
     * 计算重试延迟时间
     */
    private long calculateRetryDelay(int retryCount) {
        // 指数退避策略
        return initialRetryDelayMs * (long) Math.pow(retryDelayMultiplier, retryCount - 1);
    }
    
    /**
     * 格式化时间间隔
     */
    private String formatDuration(long millis) {
        long seconds = millis / 1000;
        long minutes = seconds / 60;
        seconds %= 60;
        
        if (minutes > 0) {
            return String.format("%d分%d秒", minutes, seconds);
        } else {
            return String.format("%d秒", seconds);
        }
    }
    
    /**
     * 发布任务开始事件
     */
    private void publishTaskStartedEvent(String taskId, String taskType, String userId) {
        try {
            TaskStartedEvent event = new TaskStartedEvent(this, taskId, taskType, userId, hostIdentifier);
            eventPublisher.publishEvent(event);
        } catch (Exception e) {
            logger.error("发布任务开始事件失败: {}", taskId, e);
        }
    }
    
    /**
     * 发布任务完成事件
     */
    private void publishTaskCompletedEvent(String taskId, String taskType, String userId, Object result) {
        try {
            TaskCompletedEvent event = new TaskCompletedEvent(this, taskId, taskType, userId, result);
            eventPublisher.publishEvent(event);
        } catch (Exception e) {
            logger.error("发布任务完成事件失败: {}", taskId, e);
        }
    }
    
    /**
     * 发布任务失败事件
     */
    private void publishTaskFailedEvent(String taskId, String taskType, String userId, 
                                       Map<String, Object> errorInfo, boolean isDeadLetter) {
        try {
            TaskFailedEvent event = new TaskFailedEvent(this, taskId, taskType, userId, errorInfo, isDeadLetter);
            eventPublisher.publishEvent(event);
        } catch (Exception e) {
            logger.error("发布任务失败事件失败: {}", taskId, e);
        }
    }
    
    /**
     * 发布任务重试事件
     */
    private void publishTaskRetryingEvent(String taskId, String taskType, String userId,
                                         Map<String, Object> errorInfo, int retryCount,
                                         int maxRetries, Instant nextAttemptTimestamp) {
        try {
            TaskRetryingEvent event = new TaskRetryingEvent(this, taskId, taskType, userId,
                    errorInfo, retryCount, maxRetries, nextAttemptTimestamp);
            eventPublisher.publishEvent(event);
        } catch (Exception e) {
            logger.error("发布任务重试事件失败: {}", taskId, e);
        }
    }
} 