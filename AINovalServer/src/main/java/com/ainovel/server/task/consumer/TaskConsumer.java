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
import com.ainovel.server.task.service.TaskSubmissionService;
import com.ainovel.server.config.TaskConversionConfig;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rabbitmq.client.Channel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;
import jakarta.annotation.PostConstruct;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 响应式任务消费者，负责处理RabbitMQ中的任务消息
 */
@Slf4j
@Component
public class TaskConsumer {
    
    private static final int MAX_RETRY_ATTEMPTS = 3;
    
    private final TaskExecutorService taskExecutorService;
    private final TaskStateService taskStateService;
    private final TaskSubmissionService taskSubmissionService;
    private final ApplicationEventPublisher eventPublisher;
    private final TaskMessageProducer taskMessageProducer;
    private final TaskConversionConfig taskConversionConfig;
    private final ObjectMapper objectMapper;
    
    private final String nodeId;
    
    @Value("${task.retry.max-attempts:3}")
    private int maxRetryAttempts;
    
    @Value("${task.retry.delays:15000,60000,300000}")
    private String retryDelaysStr;
    
    private long[] retryDelays;
    
    @Autowired
    public TaskConsumer(
            TaskExecutorService taskExecutorService,
            TaskStateService taskStateService,
            TaskSubmissionService taskSubmissionService,
            ApplicationEventPublisher eventPublisher,
            TaskMessageProducer taskMessageProducer,
            TaskConversionConfig taskConversionConfig,
            @Qualifier("taskObjectMapper") ObjectMapper objectMapper) {
        this.taskExecutorService = taskExecutorService;
        this.taskStateService = taskStateService;
        this.taskSubmissionService = taskSubmissionService;
        this.eventPublisher = eventPublisher;
        this.taskMessageProducer = taskMessageProducer;
        this.taskConversionConfig = taskConversionConfig;
        this.objectMapper = objectMapper;
        
        // 生成节点ID
        String hostname;
        try {
            hostname = InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException e) {
            hostname = "unknown-host";
        }
        this.nodeId = hostname + "-" + UUID.randomUUID().toString().substring(0, 8);
        
        // 不再在此处调用 initRetryDelays()
    }

    /**
     * 在依赖注入完成后初始化重试延迟
     */
    @PostConstruct
    public void initialize() {
        initRetryDelays();
    }
    
    /**
     * 初始化重试延迟时间配置
     */
    private void initRetryDelays() {
        if (retryDelaysStr == null) {
            log.error("Retry delays string (task.retry.delays) is null. Cannot initialize retry delays.");
            // 可以选择抛出异常或使用默认值
            throw new IllegalStateException("Configuration property 'task.retry.delays' is missing or not loaded.");
            // 或者使用默认值:
            // retryDelays = new long[]{15000, 60000, 300000};
            // log.warn("Using default retry delays: {}", Arrays.toString(retryDelays));
            // return;
        }
        String[] delayStrings = retryDelaysStr.split(",");
        retryDelays = new long[delayStrings.length];
        for (int i = 0; i < delayStrings.length; i++) {
            retryDelays[i] = Long.parseLong(delayStrings[i].trim());
        }
    }
    
    /**
     * 处理从任务队列接收的消息
     * 
     * @param message 消息
     * @param channel 通道
     * @throws IOException 如果消息处理失败
     */
    @RabbitListener(queues = "${spring.rabbitmq.template.default-receive-queue:tasks.queue}", 
                   containerFactory = "rabbitListenerContainerFactory")
    public void handleTaskMessage(Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        
        try {
            // 启动响应式处理链
            processMessageReactively(message)
                .doOnSuccess(result -> {
                    // 成功处理
                    try {
                        ackMessage(channel, deliveryTag);
                    } catch (IOException e) {
                        log.error("确认消息时出错, deliveryTag={}", deliveryTag, e);
                    }
                })
                .doOnError(e -> {
                    // 错误处理
                    log.error("任务处理链中发生错误, deliveryTag={}", deliveryTag, e);
                    try {
                        // 由于这是在响应式链的错误处理中，通常意味着代码中有问题
                        // 因此发送到死信队列而不是重试
                        nackMessage(channel, deliveryTag, false);
                    } catch (IOException ex) {
                        log.error("拒绝消息时出错, deliveryTag={}", deliveryTag, ex);
                    }
                })
                .doFinally(signalType -> {
                    log.debug("响应式链完成, deliveryTag={}, signalType={}", deliveryTag, signalType);
                })
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
            
        } catch (Exception e) {
            // 处理同步异常（例如，消息解析错误）
            log.error("处理消息时发生同步异常, deliveryTag={}", deliveryTag, e);
            nackMessage(channel, deliveryTag, false);
        }
    }
    
    /**
     * 响应式处理消息的主逻辑
     * 
     * @param message 消息对象
     * @return 处理结果的Mono
     */
    private Mono<Void> processMessageReactively(Message message) {
        MessageProperties props = message.getMessageProperties();
        String taskId = props.getMessageId();
        String taskType = props.getType();
        
        // 如果消息属性中没有必要的信息，尝试从消息体中解析
        if (taskId == null || taskType == null) {
            Map<String, Object> headers = new HashMap<>();
            try {
                headers = objectMapper.readValue(message.getBody(), Map.class);
                if (taskId == null) {
                    taskId = (String) headers.get("taskId");
                }
                if (taskType == null) {
                    taskType = (String) headers.get("taskType");
                }
            } catch (Exception e) {
                log.error("无法解析消息体: {}", new String(message.getBody()), e);
                return Mono.error(e);
            }
        }
        
        // 获取消息中的重试次数
        int retryCount = 0;
        Object retryCountHeader = props.getHeaders().get("x-retry-count");
        if (retryCountHeader != null) {
            retryCount = Integer.parseInt(retryCountHeader.toString());
        }
        
        final String finalTaskId = taskId;
        final String finalTaskType = taskType;
        final int finalRetryCount = retryCount;
        
        log.info("开始处理任务: id={}, type={}, retryCount={}", finalTaskId, finalTaskType, finalRetryCount);
        
        // 执行幂等性检查
        return taskStateService.trySetRunning(finalTaskId, nodeId)
            .flatMap(isSetRunning -> {
                if (!isSetRunning) {
                    log.info("任务已被其他节点处理, taskId={}", finalTaskId);
                    return Mono.empty();
                }
                
                // 查找任务执行器
                return taskExecutorService.findExecutor(finalTaskType)
                    .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到任务类型为 " + finalTaskType + " 的执行器")))
                    .flatMap(executable -> {
                        // 发布任务开始事件
                        eventPublisher.publishEvent(new TaskStartedEvent(this, finalTaskId, finalTaskType));
                        
                        // 查询任务信息
                        return taskStateService.getTask(finalTaskId)
                            .flatMap(task -> {
                                // 获取任务参数并转换为正确类型
                                return taskConversionConfig.convertParametersToType(finalTaskType, task.getParameters())
                                    .flatMap(typedParams -> {
                                        // 创建任务上下文
                                        TaskContext<?> context = createTaskContext(
                                            task, finalTaskType, typedParams, finalRetryCount);
                                        
                                        // 执行任务
                                        return executeTask(executable, context)
                                            .flatMap(result -> {
                                                // 处理执行结果
                                                if (result.isSuccess()) {
                                                    // 成功完成
                                                    return handleSuccessResult(task, result.getResult());
                                                } else if (result.isRetryable() && finalRetryCount < maxRetryAttempts) {
                                                    // 可重试且未达到最大重试次数
                                                    return handleRetryableFailure(task, result.getError(), finalRetryCount);
                                                } else if (result.isRetryable()) {
                                                    // 可重试但已达到最大重试次数
                                                    return handleDeadLetter(task, result.getError(), "达到最大重试次数");
                                                } else if (result.isNonRetryable()) {
                                                    // 不可重试错误
                                                    return handleNonRetryableFailure(task, result.getError());
                                                } else if (result.isCancelled()) {
                                                    // 任务被取消
                                                    return handleCancellation(task);
                                                } else {
                                                    // 未知结果状态
                                                    return Mono.error(new IllegalStateException("未知的任务结果状态"));
                                                }
                                            });
                                    });
                            });
                    });
            });
    }
    
    /**
     * 创建任务上下文
     * 
     * @param task 任务对象
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @param retryCount 重试次数
     * @return 任务上下文
     */
    @SuppressWarnings("unchecked")
    private <P> TaskContext<P> createTaskContext(
            BackgroundTask task, 
            String taskType, 
            Object parameters, 
            int retryCount) {
        
        return TaskContextImpl.<P>builder()
                .taskId(task.getId())
                .taskType(taskType)
                .userId(task.getUserId())
                .parameters((P) parameters)
                .executionNodeId(nodeId)
                .parentTaskId(task.getParentTaskId())
                .taskStateService(taskStateService)
                .taskSubmissionService(taskSubmissionService)
                .eventPublisher(eventPublisher)
                .build();
    }
    
    /**
     * 类型安全地执行任务
     * 
     * @param executable 任务执行器
     * @param context 任务上下文
     * @return 执行结果的Mono
     */
    @SuppressWarnings({"unchecked", "rawtypes"})
    private Mono<ExecutionResult<?>> executeTask(BackgroundTaskExecutable<?, ?> executable, TaskContext<?> context) {
        try {
            // 使用原始类型避免泛型问题
            return taskExecutorService.executeTask((BackgroundTaskExecutable) executable, context);
        } catch (Exception e) {
            log.error("执行任务时发生异常: taskId={}", context.getTaskId(), e);
            return Mono.just(ExecutionResult.nonRetryableFailure(e));
        }
    }
    
    /**
     * 处理成功结果
     * 
     * @param task 任务对象
     * @param result 结果对象
     * @return 完成信号
     */
    private Mono<Void> handleSuccessResult(BackgroundTask task, Object result) {
        log.info("任务执行成功: taskId={}, taskType={}", task.getId(), task.getTaskType());
        
        // 发布任务完成事件
        eventPublisher.publishEvent(new TaskCompletedEvent(this, task.getId(), task.getTaskType(), task.getUserId(), result));
        
        // 更新数据库状态
        return taskStateService.recordCompletion(task.getId(), result);
    }
    
    /**
     * 处理可重试的失败
     * 
     * @param task 任务对象
     * @param error 错误对象
     * @param retryCount 当前重试次数
     * @return 完成信号
     */
    private Mono<Void> handleRetryableFailure(BackgroundTask task, Throwable error, int retryCount) {
        log.info("任务将进行重试: taskId={}, taskType={}, retryCount={}/{}", 
                task.getId(), task.getTaskType(), retryCount, maxRetryAttempts);
        
        // 计算下次重试延迟
        long delayMillis = getRetryDelay(retryCount);
        Instant nextAttemptTime = Instant.now().plusMillis(delayMillis);
        
        // 创建错误信息Map
        Map<String, Object> errorInfo = createErrorInfoMap(error);
        
        // 发布任务重试事件
        eventPublisher.publishEvent(new TaskRetryingEvent(
                this, task.getId(), task.getTaskType(), task.getUserId(), 
                retryCount + 1, maxRetryAttempts, delayMillis, errorInfo));
        
        // 重新发送带有延迟的消息
        return taskMessageProducer.sendDelayedRetryTask(
                task.getId(), task.getUserId(), task.getTaskType(), task.getParameters(), 
                retryCount + 1, delayMillis)
            .then(taskStateService.recordRetrying(
                    task.getId(), retryCount + 1, error, nextAttemptTime));
    }
    
    /**
     * 处理不可重试的失败
     * 
     * @param task 任务对象
     * @param error 错误对象
     * @return 完成信号
     */
    private Mono<Void> handleNonRetryableFailure(BackgroundTask task, Throwable error) {
        log.error("任务执行失败（不可重试）: taskId={}, taskType={}", task.getId(), task.getTaskType(), error);
        
        // 创建错误信息Map
        Map<String, Object> errorInfo = createErrorInfoMap(error);
        
        // 发布任务失败事件
        eventPublisher.publishEvent(new TaskFailedEvent(
                this, task.getId(), task.getTaskType(), task.getUserId(), errorInfo, false));
        
        // 更新数据库状态
        return taskStateService.recordFailure(task.getId(), errorInfo, false);
    }
    
    /**
     * 处理达到最大重试次数的任务（死信）
     * 
     * @param task 任务对象
     * @param error 错误对象
     * @param reason 原因描述
     * @return 完成信号
     */
    private Mono<Void> handleDeadLetter(BackgroundTask task, Throwable error, String reason) {
        log.error("任务进入死信: taskId={}, taskType={}, reason={}", 
                task.getId(), task.getTaskType(), reason, error);
        
        // 创建错误信息Map
        Map<String, Object> errorInfo = createErrorInfoMap(error);
        errorInfo.put("deadLetterReason", reason);
        
        // 发布任务失败事件（标记为死信）
        eventPublisher.publishEvent(new TaskFailedEvent(
                this, task.getId(), task.getTaskType(), task.getUserId(), errorInfo, true));
        
        // 更新数据库状态
        return taskStateService.recordFailure(task.getId(), errorInfo, true);
    }
    
    /**
     * 处理任务取消
     * 
     * @param task 任务对象
     * @return 完成信号
     */
    private Mono<Void> handleCancellation(BackgroundTask task) {
        log.info("任务已被取消: taskId={}, taskType={}", task.getId(), task.getTaskType());
        
        // 发布任务取消事件
        eventPublisher.publishEvent(new TaskCancelledEvent(
                this, task.getId(), task.getTaskType(), task.getUserId()));
        
        // 更新数据库状态
        return taskStateService.recordCancellation(task.getId());
    }
    
    /**
     * 确认消息
     * 
     * @param channel 通道
     * @param deliveryTag 投递标签
     * @throws IOException 如果确认失败
     */
    private void ackMessage(Channel channel, long deliveryTag) throws IOException {
        channel.basicAck(deliveryTag, false);
        log.debug("确认消息: deliveryTag={}", deliveryTag);
    }
    
    /**
     * 拒绝消息
     * 
     * @param channel 通道
     * @param deliveryTag 投递标签
     * @param requeue 是否重新排队
     * @throws IOException 如果拒绝失败
     */
    private void nackMessage(Channel channel, long deliveryTag, boolean requeue) throws IOException {
        channel.basicNack(deliveryTag, false, requeue);
        log.debug("拒绝消息: deliveryTag={}, requeue={}", deliveryTag, requeue);
    }
    
    /**
     * 获取重试延迟时间
     * 
     * @param retryCount 当前重试次数
     * @return 延迟毫秒数
     */
    private long getRetryDelay(int retryCount) {
        if (retryCount < retryDelays.length) {
            return retryDelays[retryCount];
        }
        // 如果重试次数超过配置的延迟数组长度，使用最后一个延迟值
        return retryDelays[retryDelays.length - 1];
    }
    
    /**
     * 创建错误信息Map
     * 
     * @param error 错误对象
     * @return 错误信息Map
     */
    private Map<String, Object> createErrorInfoMap(Throwable error) {
        Map<String, Object> errorInfo = new HashMap<>();
        errorInfo.put("message", error.getMessage());
        errorInfo.put("exceptionClass", error.getClass().getName());
        errorInfo.put("timestamp", Instant.now().toString());
        
        // 添加堆栈跟踪（可选，可能会增加存储开销）
        StackTraceElement[] stackTrace = error.getStackTrace();
        if (stackTrace != null && stackTrace.length > 0) {
            String[] stackTraceStrings = new String[Math.min(stackTrace.length, 10)]; // 限制堆栈深度
            for (int i = 0; i < stackTraceStrings.length; i++) {
                stackTraceStrings[i] = stackTrace[i].toString();
            }
            errorInfo.put("stackTrace", stackTraceStrings);
        }
        
        // 添加根本原因
        Throwable cause = error.getCause();
        if (cause != null && cause != error) {
            Map<String, String> causeInfo = new HashMap<>();
            causeInfo.put("message", cause.getMessage());
            causeInfo.put("exceptionClass", cause.getClass().getName());
            errorInfo.put("cause", causeInfo);
        }
        
        return errorInfo;
    }
} 