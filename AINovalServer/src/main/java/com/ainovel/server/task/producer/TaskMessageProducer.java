package com.ainovel.server.task.producer;

import com.ainovel.server.config.RabbitMQConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.AmqpException;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageBuilder;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.core.MessagePropertiesBuilder;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.Map;
import java.util.UUID;

/**
 * 任务消息生产者，负责向RabbitMQ发送任务消息
 */
@Slf4j
@Component
public class TaskMessageProducer {
    
    private final RabbitTemplate rabbitTemplate;
    
    @Autowired
    public TaskMessageProducer(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }
    
    /**
     * 发送任务消息
     * 
     * @param taskId 任务ID
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @return 包含操作完成信号的Mono
     */
    public Mono<Void> sendTask(String taskId, String userId, String taskType, Object parameters) {
        return Mono.fromCallable(() -> {
            log.info("发送任务消息: {} [类型: {}, 用户: {}]", taskId, taskType, userId);
            
            // 构建路由键
            String routingKey = RabbitMQConfig.TASK_TYPE_PREFIX + taskType;
            
            // 发送消息到任务交换机
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.TASKS_EXCHANGE, 
                routingKey, // 使用包含前缀的路由键
                parameters, 
                message -> {
                    // 直接设置消息属性和头信息
                    message.getMessageProperties().setHeader("x-task-id", taskId);
                    message.getMessageProperties().setHeader("x-user-id", userId);
                    message.getMessageProperties().setHeader("x-task-type", taskType);
                    message.getMessageProperties().setHeader("x-retry-count", 0);
                    message.getMessageProperties().setCorrelationId(taskId);
                    message.getMessageProperties().setMessageId(UUID.randomUUID().toString());
                    return message;
                },
                new CorrelationData(taskId)
            );
            
            return null;
        })
        .subscribeOn(Schedulers.boundedElastic()) // 消息发送是阻塞的，调度到适当的线程池
        .then();
    }
    
    /**
     * 发送任务消息到重试交换机
     * 
     * @param taskId 任务ID
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @param retryCount 重试次数
     * @return 包含操作完成信号的Mono
     */
    public Mono<Void> sendToRetryExchange(String taskId, String userId, String taskType, Object parameters, int retryCount) {
        return Mono.fromCallable(() -> {
            log.info("发送任务消息到重试交换机: {} [类型: {}, 用户: {}, 重试次数: {}]", 
                      taskId, taskType, userId, retryCount);
            
            // 发送消息到重试交换机
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.TASKS_RETRY_EXCHANGE, 
                taskType, // 对于FanoutExchange，路由键通常被忽略，这里保持一致
                parameters, 
                message -> {
                    // 直接设置消息属性和头信息
                    message.getMessageProperties().setHeader("x-task-id", taskId);
                    message.getMessageProperties().setHeader("x-user-id", userId);
                    message.getMessageProperties().setHeader("x-task-type", taskType);
                    message.getMessageProperties().setHeader("x-retry-count", retryCount);
                    message.getMessageProperties().setCorrelationId(taskId);
                    message.getMessageProperties().setMessageId(UUID.randomUUID().toString());
                    return message;
                },
                new CorrelationData(taskId)
            );
            
            return null;
        })
        .subscribeOn(Schedulers.boundedElastic())
        .then();
    }
    
    /**
     * 发送任务事件消息
     * 
     * @param eventType 事件类型
     * @param eventData 事件数据
     * @return 包含操作完成信号的Mono
     */
    public Mono<Void> sendTaskEvent(String eventType, Map<String, Object> eventData) {
        return Mono.fromCallable(() -> {
            String correlationId = eventData.containsKey("taskId") ? 
                            eventData.get("taskId").toString() : UUID.randomUUID().toString();
            
            log.debug("发送任务事件消息: {} [correlationId: {}]", eventType, correlationId);
            
            // 构建事件路由键
            String routingKey = "task.event." + eventType.toLowerCase();
            
            // 发送消息到事件交换机
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.TASKS_EVENTS_EXCHANGE, 
                routingKey, // 使用包含前缀和事件类型的路由键
                eventData, 
                message -> {
                    message.getMessageProperties().setCorrelationId(correlationId);
                    message.getMessageProperties().setMessageId(UUID.randomUUID().toString());
                    message.getMessageProperties().setHeader("x-event-type", eventType);
                    return message;
                },
                new CorrelationData(correlationId)
            );
            
            return null;
        })
        .subscribeOn(Schedulers.boundedElastic())
        .then();
    }

    /**
     * 发送带有延迟的重试任务消息
     * 
     * @param taskId 任务ID
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param parameters 任务参数
     * @param retryCount 重试次数
     * @param delayMillis 延迟时间（毫秒）
     * @return 完成信号
     */
    public Mono<Void> sendDelayedRetryTask(String taskId, String userId, String taskType, Object parameters, 
                                           int retryCount, long delayMillis) {
        return Mono.fromCallable(() -> {
            log.info("发送带有延迟的重试任务消息: {} [类型: {}, 用户: {}, 重试次数: {}, 延迟时间: {}毫秒]", 
                      taskId, taskType, userId, retryCount, delayMillis);
            
            // 发送消息到重试交换机
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.TASKS_RETRY_EXCHANGE, 
                taskType, // 对于FanoutExchange，路由键通常被忽略
                parameters, 
                message -> {
                    // 直接设置消息属性和头信息
                    message.getMessageProperties().setHeader("x-task-id", taskId);
                    message.getMessageProperties().setHeader("x-user-id", userId);
                    message.getMessageProperties().setHeader("x-task-type", taskType);
                    message.getMessageProperties().setHeader("x-retry-count", retryCount);
                    message.getMessageProperties().setCorrelationId(taskId);
                    message.getMessageProperties().setMessageId(UUID.randomUUID().toString());
                    message.getMessageProperties().setHeader("x-delay", delayMillis);
                    return message;
                },
                new CorrelationData(taskId)
            );
            
            return null;
        })
        .subscribeOn(Schedulers.boundedElastic())
        .then();
    }
} 