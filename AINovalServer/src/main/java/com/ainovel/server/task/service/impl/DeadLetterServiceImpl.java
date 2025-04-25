package com.ainovel.server.task.service.impl;

import com.ainovel.server.config.RabbitMQConfig;
import com.ainovel.server.task.producer.TaskMessageProducer;
import com.ainovel.server.task.service.DeadLetterService;
import com.ainovel.server.task.service.TaskStateService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.rabbit.core.RabbitAdmin;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

@Service
public class DeadLetterServiceImpl implements DeadLetterService {
    
    private static final Logger logger = LoggerFactory.getLogger(DeadLetterServiceImpl.class);
    
    private final RabbitAdmin rabbitAdmin;
    private final RabbitTemplate rabbitTemplate;
    private final TaskMessageProducer taskMessageProducer;
    private final TaskStateService taskStateService;
    private final ObjectMapper objectMapper;
    
    @Autowired
    public DeadLetterServiceImpl(RabbitAdmin rabbitAdmin, 
                               RabbitTemplate rabbitTemplate,
                               TaskMessageProducer taskMessageProducer,
                               TaskStateService taskStateService,
                               ObjectMapper objectMapper) {
        this.rabbitAdmin = rabbitAdmin;
        this.rabbitTemplate = rabbitTemplate;
        this.taskMessageProducer = taskMessageProducer;
        this.taskStateService = taskStateService;
        this.objectMapper = objectMapper;
    }
    
    @Override
    public Map<String, Object> getDeadLetterQueueInfo() {
        Properties props = rabbitAdmin.getQueueProperties(RabbitMQConfig.TASKS_DLQ_QUEUE);
        Map<String, Object> result = new HashMap<>();
        
        if (props != null) {
            result.put("queueName", RabbitMQConfig.TASKS_DLQ_QUEUE);
            result.put("messageCount", props.get("QUEUE_MESSAGE_COUNT"));
            result.put("consumerCount", props.get("QUEUE_CONSUMER_COUNT"));
        }
        
        return result;
    }
    
    @Override
    public List<Map<String, Object>> listDeadLetters(int limit) {
        List<Map<String, Object>> result = new ArrayList<>();
        
        // 获取死信队列中的消息（非破坏性方式）
        for (int i = 0; i < limit; i++) {
            Message message = rabbitTemplate.receive(RabbitMQConfig.TASKS_DLQ_QUEUE, 100);
            if (message == null) {
                break;
            }
            
            try {
                // 解析消息
                MessageProperties props = message.getMessageProperties();
                String taskId = props.getMessageId();
                String taskType = props.getHeader("x-task-type");
                String userId = props.getHeader("x-user-id");
                Integer retryCount = props.getHeader("x-retry-count");
                
                // 读取消息体
                Object messageBody = rabbitTemplate.getMessageConverter().fromMessage(message);
                
                // 构建消息信息
                Map<String, Object> messageInfo = new HashMap<>();
                messageInfo.put("taskId", taskId);
                messageInfo.put("taskType", taskType);
                messageInfo.put("userId", userId);
                messageInfo.put("retryCount", retryCount);
                messageInfo.put("parameters", messageBody);
                
                // 从数据库获取更详细的任务信息
                taskStateService.findById(taskId).ifPresent(task -> {
                    messageInfo.put("status", task.getStatus());
                    messageInfo.put("errorInfo", task.getErrorInfo());
                    messageInfo.put("lastAttemptTimestamp", task.getLastAttemptTimestamp());
                });
                
                result.add(messageInfo);
                
                // 重新放回队列
                rabbitTemplate.send(RabbitMQConfig.TASKS_DLQ_QUEUE, message);
            } catch (Exception e) {
                logger.error("解析死信消息失败", e);
                // 重新放回队列，避免消息丢失
                rabbitTemplate.send(RabbitMQConfig.TASKS_DLQ_QUEUE, message);
            }
        }
        
        return result;
    }
    
    @Override
    public boolean retryDeadLetter(String taskId) {
        // 检查任务是否存在
        return taskStateService.findById(taskId).map(task -> {
            // 暂时从死信队列获取并丢弃匹配的消息
            boolean found = false;
            for (int i = 0; i < 1000; i++) {  // 设置一个上限以避免无限循环
                Message message = rabbitTemplate.receive(RabbitMQConfig.TASKS_DLQ_QUEUE, 100);
                if (message == null) {
                    break;
                }
                
                MessageProperties props = message.getMessageProperties();
                String msgTaskId = props.getMessageId();
                
                if (taskId.equals(msgTaskId)) {
                    // 找到匹配的消息
                    found = true;
                    
                    try {
                        // 获取重要信息
                        String taskType = props.getHeader("x-task-type");
                        String userId = props.getHeader("x-user-id");
                        
                        // 反序列化消息体
                        Object messageBody = rabbitTemplate.getMessageConverter().fromMessage(message);
                        
                        // 更新任务状态为重试中
                        Map<String, Object> errorInfo = new HashMap<>();
                        errorInfo.put("message", "手动从死信队列重试");
                        taskStateService.recordRetrying(taskId, errorInfo, null);
                        
                        // 重新发送消息到主队列
                        return taskMessageProducer.sendTask(taskId, userId, taskType, messageBody);
                    } catch (Exception e) {
                        logger.error("处理死信消息重试失败: {}", taskId, e);
                        // 失败时放回队列
                        rabbitTemplate.send(RabbitMQConfig.TASKS_DLQ_QUEUE, message);
                        return false;
                    }
                } else {
                    // 不匹配，放回队列
                    rabbitTemplate.send(RabbitMQConfig.TASKS_DLQ_QUEUE, message);
                }
            }
            
            if (!found) {
                logger.warn("在死信队列中未找到任务消息: {}", taskId);
            }
            
            return found;
        }).orElse(false);
    }
    
    @Override
    public boolean purgeDeadLetterQueue() {
        try {
            rabbitAdmin.purgeQueue(RabbitMQConfig.TASKS_DLQ_QUEUE, false);
            return true;
        } catch (Exception e) {
            logger.error("清空死信队列失败", e);
            return false;
        }
    }
}
