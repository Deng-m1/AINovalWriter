package com.ainovel.server.task.producer;

import com.ainovel.server.config.RabbitMQConfig;
import com.ainovel.server.task.event.external.TaskExternalEvent;
import com.ainovel.server.task.model.TaskStatus;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.AmqpException;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.core.MessagePropertiesBuilder;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

/**
 * 任务外部事件发布器，负责将任务状态变更事件发布到外部交换机
 */
@Service
public class TaskEventPublisher {
    private static final Logger logger = LoggerFactory.getLogger(TaskEventPublisher.class);
    
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;
    
    @Autowired
    public TaskEventPublisher(RabbitTemplate rabbitTemplate, ObjectMapper objectMapper) {
        this.rabbitTemplate = rabbitTemplate;
        this.objectMapper = objectMapper;
    }
    
    /**
     * 发布外部事件
     * 
     * @param event 外部事件对象
     * @return 是否成功发布
     */
    public boolean publishExternalEvent(TaskExternalEvent event) {
        if (event == null) {
            logger.error("无法发布空事件");
            return false;
        }
        
        try {
            String eventType = event.getStatus().name();
            String routingKey = "task.event." + eventType.toLowerCase();
            String correlationId = UUID.randomUUID().toString();
            
            logger.info("正在发布任务事件 [{} - {}] 到交换机, 路由键: {}", 
                    event.getTaskId(), eventType, routingKey);
            
            MessageProperties props = MessagePropertiesBuilder.newInstance()
                    .setContentType(MessageProperties.CONTENT_TYPE_JSON)
                    .setCorrelationId(correlationId)
                    .setMessageId(event.getEventId())
                    .setHeader("x-event-type", eventType)
                    .setHeader("x-task-id", event.getTaskId())
                    .build();
            
            // 让RabbitTemplate序列化消息体
            Message message = rabbitTemplate.getMessageConverter().toMessage(
                    event, props);
            
            // 创建相关数据，用于跟踪确认
            CorrelationData correlationData = new CorrelationData(correlationId);
            
            rabbitTemplate.convertAndSend(
                    RabbitMQConfig.TASKS_EVENTS_EXCHANGE,
                    routingKey,
                    message,
                    correlationData);
            
            return true;
        } catch (AmqpException e) {
            logger.error("发布任务事件 [{}] 到RabbitMQ失败: {}", 
                    event.getTaskId(), e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * 创建并发布外部事件
     * 
     * @param taskId 任务ID
     * @param taskType 任务类型
     * @param userId 用户ID
     * @param status 任务状态
     * @param result 任务结果(可选)
     * @param progress 任务进度(可选)
     * @param errorInfo 错误信息(可选)
     * @param isDeadLetter 是否为死信(可选)
     * @param parentTaskId 父任务ID(可选)
     * @return 是否成功发布
     */
    public boolean publishExternalEvent(String taskId, String taskType, String userId, 
                                        TaskStatus status, Object result, Object progress, 
                                        Object errorInfo, Boolean isDeadLetter, String parentTaskId) {
        TaskExternalEvent event = new TaskExternalEvent();
        event.setEventId(UUID.randomUUID().toString());
        event.setTaskId(taskId);
        event.setTaskType(taskType);
        event.setUserId(userId);
        event.setStatus(status);
        event.setTimestamp(Instant.now());
        
        if (result != null) {
            event.setResult(result);
        }
        
        if (progress != null) {
            event.setProgress(progress);
        }
        
        if (errorInfo != null) {
            event.setErrorInfo(objectMapper.convertValue(errorInfo, objectMapper.getTypeFactory()
                    .constructMapType(java.util.Map.class, String.class, Object.class)));
        }
        
        if (isDeadLetter != null) {
            event.setDeadLetter(isDeadLetter);
        }
        
        if (parentTaskId != null) {
            event.setParentTaskId(parentTaskId);
        }
        
        return publishExternalEvent(event);
    }
} 