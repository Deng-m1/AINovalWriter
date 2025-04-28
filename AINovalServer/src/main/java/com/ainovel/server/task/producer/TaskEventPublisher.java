package com.ainovel.server.task.producer;

import com.ainovel.server.config.RabbitMQConfig;
import com.ainovel.server.task.event.external.TaskExternalEvent;
import com.ainovel.server.task.model.TaskStatus;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.AmqpException;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.Map;
import java.util.UUID;
import java.util.HashMap;

/**
 * 响应式任务外部事件发布器，负责将任务状态变更事件发布到外部交换机
 */
@Slf4j
@Service
public class TaskEventPublisher {
    
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
     * @param eventType 事件类型 (例如 "TASK_COMPLETED", "TASK_FAILED")
     * @param eventData 事件数据Map
     * @return 表示操作完成的Mono<Void>
     */
    public Mono<Void> publishExternalEvent(String eventType, Map<String, Object> eventData) {
        return Mono.fromCallable(() -> {
            String taskId = eventData.getOrDefault("taskId", "unknown").toString();
            String correlationId = eventData.containsKey("taskId") ? 
                            eventData.get("taskId").toString() : UUID.randomUUID().toString();
            String routingKey = "task.event." + eventType.toLowerCase();
            
            log.info("正在发布任务事件 [{}] 到交换机, 事件类型: {}, 路由键: {}", 
                    taskId, eventType, routingKey);
            
            // 发送消息到事件交换机
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.TASKS_EVENTS_EXCHANGE, 
                routingKey, 
                eventData, // 直接发送Map数据
                message -> {
                    // 设置必要的头信息
                    message.getMessageProperties().setContentType(MessageProperties.CONTENT_TYPE_JSON);
                    message.getMessageProperties().setCorrelationId(correlationId);
                    message.getMessageProperties().setMessageId(UUID.randomUUID().toString());
                    message.getMessageProperties().setHeader("x-event-type", eventType);
                    if (eventData.containsKey("taskId")) {
                        message.getMessageProperties().setHeader("x-task-id", eventData.get("taskId"));
                    }
                    return message;
                },
                new CorrelationData(correlationId)
            );
            
            return null;
        })
        .subscribeOn(Schedulers.boundedElastic()) // 发送是阻塞的
        .doOnError(e -> log.error("发布任务事件 [{}] 到RabbitMQ失败: {}", 
                            eventType, e.getMessage(), e))
        .then();
    }
    
    // --- 保留旧方法作为兼容或内部使用，但不推荐直接调用 --- 
    
    /**
     * @deprecated 使用 publishExternalEvent(String eventType, Map<String, Object> eventData) 代替
     */
    @Deprecated
    public boolean publishExternalEvent(TaskExternalEvent event) {
        // 不再推荐直接使用，改为调用新的Map版本
        try {
            Map<String, Object> eventData = objectMapper.convertValue(event, Map.class);
            publishExternalEvent(event.getStatus().name(), eventData).block(); // 阻塞等待，不推荐
            return true;
        } catch (Exception e) {
            log.error("发布旧版任务事件失败: {}", event.getTaskId(), e);
            return false;
        }
    }

    /**
     * @deprecated 使用 publishExternalEvent(String eventType, Map<String, Object> eventData) 代替
     */
    @Deprecated
    public boolean publishExternalEvent(String taskId, String taskType, String userId, 
                                        TaskStatus status, Object result, Object progress, 
                                        Object errorInfo, Boolean isDeadLetter, String parentTaskId) {
        // 不再推荐直接使用，改为调用新的Map版本
        Map<String, Object> eventData = new HashMap<>();
        eventData.put("taskId", taskId);
        eventData.put("taskType", taskType);
        eventData.put("userId", userId);
        eventData.put("status", status.name());
        if (result != null) eventData.put("result", result);
        if (progress != null) eventData.put("progress", progress);
        if (errorInfo != null) eventData.put("errorInfo", errorInfo);
        if (isDeadLetter != null) eventData.put("isDeadLetter", isDeadLetter);
        if (parentTaskId != null) eventData.put("parentTaskId", parentTaskId);
        
        try {
            publishExternalEvent(status.name(), eventData).block(); // 阻塞等待，不推荐
            return true;
        } catch (Exception e) {
            log.error("发布旧版任务事件失败 (手动构建): {}", taskId, e);
            return false;
        }
    }
} 