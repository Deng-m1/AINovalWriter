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

import java.nio.charset.StandardCharsets;
import java.util.UUID;

/**
 * 任务消息生产者，负责将任务消息发送到RabbitMQ
 */
@Component
public class TaskMessageProducer {
    private static final Logger logger = LoggerFactory.getLogger(TaskMessageProducer.class);
    
    private final RabbitTemplate rabbitTemplate;
    
    @Autowired
    public TaskMessageProducer(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }
    
    /**
     * 发送任务消息到RabbitMQ
     * 
     * @param taskId 任务ID
     * @param userId 用户ID
     * @param taskType 任务类型
     * @param body 消息体
     * @param retryCount 重试次数（对于发送到重试队列的任务）
     * @return 是否发送成功
     */
    public boolean sendTask(String taskId, String userId, String taskType, Object body, int retryCount) {
        try {
            String routingKey = RabbitMQConfig.TASK_TYPE_PREFIX + taskType;
            String correlationId = UUID.randomUUID().toString();
            
            logger.info("正在发送任务 [{} - {}] 到队列，路由键: {}, 重试次数: {}", taskId, taskType, routingKey, retryCount);
            
            MessageProperties props = MessagePropertiesBuilder.newInstance()
                    .setContentType(MessageProperties.CONTENT_TYPE_JSON)
                    .setCorrelationId(correlationId)
                    .setMessageId(taskId)
                    .setHeader("x-task-id", taskId)
                    .setHeader("x-user-id", userId)
                    .setHeader("x-task-type", taskType)
                    .setHeader("x-retry-count", retryCount)
                    .build();
            
            // 让RabbitTemplate序列化消息体
            Message message = rabbitTemplate.getMessageConverter().toMessage(
                    body, props);
            
            // 创建相关数据，用于跟踪确认
            CorrelationData correlationData = new CorrelationData(correlationId);
            
            // 同步发送，等待确认
            rabbitTemplate.convertAndSend(
                    RabbitMQConfig.TASKS_EXCHANGE,
                    routingKey,
                    message,
                    correlationData);
            
            // 简单实现，后续可以改为异步方式并使用CorrelationData中的Future检查结果
            return true;
        } catch (AmqpException e) {
            logger.error("发送任务 [{} - {}] 到RabbitMQ失败: {}", taskId, taskType, e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * 发送任务消息到RabbitMQ（无重试计数）
     */
    public boolean sendTask(String taskId, String userId, String taskType, Object body) {
        return sendTask(taskId, userId, taskType, body, 0);
    }
    
    /**
     * 发送任务消息到重试交换机
     */
    public boolean sendToRetryExchange(String taskId, String userId, String taskType, Object body, int retryCount) {
        try {
            String correlationId = UUID.randomUUID().toString();
            String queueName = getDelayQueueForRetryCount(retryCount);
            
            logger.info("正在发送任务 [{} - {}] 到重试队列: {}, 重试次数: {}", taskId, taskType, queueName, retryCount);
            
            MessageProperties props = MessagePropertiesBuilder.newInstance()
                    .setContentType(MessageProperties.CONTENT_TYPE_JSON)
                    .setCorrelationId(correlationId)
                    .setMessageId(taskId)
                    .setHeader("x-task-id", taskId)
                    .setHeader("x-user-id", userId)
                    .setHeader("x-task-type", taskType)
                    .setHeader("x-retry-count", retryCount)
                    .build();
            
            // 设置原始路由键，便于后续重新入队
            props.setHeader("x-original-routing-key", RabbitMQConfig.TASK_TYPE_PREFIX + taskType);
            
            // 让RabbitTemplate序列化消息体
            Message message = rabbitTemplate.getMessageConverter().toMessage(
                    body, props);
            
            // 创建相关数据，用于跟踪确认
            CorrelationData correlationData = new CorrelationData(correlationId);
            
            // 发送到特定延迟队列，而不是交换机
            rabbitTemplate.convertAndSend(
                    queueName,
                    message,
                    correlationData);
            
            return true;
        } catch (AmqpException e) {
            logger.error("发送任务 [{} - {}] 到重试队列失败: {}", taskId, taskType, e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * 发送事件消息到事件交换机
     */
    public boolean sendTaskEvent(String eventType, Object eventData) {
        try {
            String routingKey = "task.event." + eventType;
            String correlationId = UUID.randomUUID().toString();
            
            MessageProperties props = MessagePropertiesBuilder.newInstance()
                    .setContentType(MessageProperties.CONTENT_TYPE_JSON)
                    .setCorrelationId(correlationId)
                    .setHeader("x-event-type", eventType)
                    .build();
            
            // 让RabbitTemplate序列化消息体
            Message message = rabbitTemplate.getMessageConverter().toMessage(
                    eventData, props);
            
            // 创建相关数据，用于跟踪确认
            CorrelationData correlationData = new CorrelationData(correlationId);
            
            rabbitTemplate.convertAndSend(
                    RabbitMQConfig.TASKS_EVENTS_EXCHANGE,
                    routingKey,
                    message,
                    correlationData);
            
            return true;
        } catch (AmqpException e) {
            logger.error("发送任务事件 [{}] 到RabbitMQ失败: {}", eventType, e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * 根据重试次数选择适当的延迟队列
     */
    private String getDelayQueueForRetryCount(int retryCount) {
        if (retryCount <= 1) {
            return RabbitMQConfig.TASKS_WAIT_15S_QUEUE;
        } else if (retryCount <= 3) {
            return RabbitMQConfig.TASKS_WAIT_1M_QUEUE;
        } else if (retryCount <= 5) {
            return RabbitMQConfig.TASKS_WAIT_5M_QUEUE;
        } else {
            return RabbitMQConfig.TASKS_WAIT_30M_QUEUE;
        }
    }
} 