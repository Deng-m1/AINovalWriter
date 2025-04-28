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
import reactor.core.publisher.Mono;

import java.time.Instant;
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
                // 注意：这里使用同步方式获取信息，在生产环境中应考虑完全异步实现
                taskStateService.getTask(taskId)
                    .doOnNext(task -> {
                        messageInfo.put("status", task.getStatus());
                        messageInfo.put("errorInfo", task.getErrorInfo());
                        messageInfo.put("lastAttemptTimestamp", task.getLastAttemptTimestamp());
                    })
                    .subscribe();
                
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
        // 注意：这里使用同步方式获取结果，实际上应该重写整个方法为响应式接口
        return taskStateService.getTask(taskId)
            .flatMap(task -> {
                // 这个逻辑只能同步处理，我们将它封装在Mono中
                return Mono.fromCallable(() -> {
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
                                taskStateService.recordRetry(taskId, errorInfo, Instant.now().plusSeconds(5)).subscribe();
                                
                                // 重新发送消息到主队列
                                try {
                                    taskMessageProducer.sendTask(taskId, userId, taskType, messageBody);
                                    return true;
                                } catch (Exception e) {
                                    logger.error("发送任务到队列时失败: {}", taskId, e);
                                    rabbitTemplate.send(RabbitMQConfig.TASKS_DLQ_QUEUE, message); // 失败时放回队列
                                    return false;
                                }
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
                });
            })
            .defaultIfEmpty(false)
            .block(); // 注意：在实际响应式系统中应避免使用block()
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
