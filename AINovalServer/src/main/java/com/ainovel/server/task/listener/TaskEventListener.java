package com.ainovel.server.task.listener;

import com.ainovel.server.config.RabbitMQConfig;
import com.rabbitmq.client.Channel;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Map;

/**
 * 任务事件监听器，用于处理任务事件消息
 */
@Slf4j
@Component
public class TaskEventListener {

    /**
     * 处理任务事件消息
     * 
     * @param message 消息对象
     * @param channel RabbitMQ通道
     * @throws IOException 如果消息处理过程中发生IO异常
     */
    @RabbitListener(queues = RabbitMQConfig.TASKS_EVENTS_QUEUE)
    public void handleTaskEvent(Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        String taskId = null;
        String eventType = null;
        
        try {
            // 获取消息头中的任务ID和事件类型
            Map<String, Object> headers = message.getMessageProperties().getHeaders();
            taskId = (String) headers.get("x-task-id");
            eventType = (String) headers.get("x-event-type");
            
            log.info("收到任务事件: taskId={}, eventType={}", taskId, eventType);
            
            // 根据事件类型进行不同处理
            switch (eventType) {
                case "TASK_SUBMITTED":
                    // 处理任务提交事件
                    handleTaskSubmitted(message, taskId);
                    break;
                case "TASK_STARTED":
                    // 处理任务开始事件
                    handleTaskStarted(message, taskId);
                    break;
                case "TASK_COMPLETED":
                    // 处理任务完成事件
                    handleTaskCompleted(message, taskId);
                    break;
                case "TASK_FAILED":
                    // 处理任务失败事件
                    handleTaskFailed(message, taskId);
                    break;
                case "TASK_PROGRESS_UPDATED":
                    // 处理任务进度更新事件
                    handleTaskProgressUpdated(message, taskId);
                    break;
                default:
                    log.warn("未知的任务事件类型: {}, taskId={}", eventType, taskId);
                    break;
            }
            
            // 确认消息已处理
            channel.basicAck(deliveryTag, false);
            log.debug("任务事件处理成功: taskId={}, eventType={}", taskId, eventType);
            
        } catch (Exception e) {
            log.error("处理任务事件失败: taskId={}, eventType={}", taskId, eventType, e);
            
            // 拒绝消息并重新入队
            channel.basicNack(deliveryTag, false, true);
        }
    }
    
    /**
     * 处理任务提交事件
     */
    private void handleTaskSubmitted(Message message, String taskId) {
        // 这里可以实现任务提交事件的具体处理逻辑
        log.info("处理任务提交事件: taskId={}", taskId);
    }
    
    /**
     * 处理任务开始事件
     */
    private void handleTaskStarted(Message message, String taskId) {
        // 这里可以实现任务开始事件的具体处理逻辑
        log.info("处理任务开始事件: taskId={}", taskId);
    }
    
    /**
     * 处理任务完成事件
     */
    private void handleTaskCompleted(Message message, String taskId) {
        // 这里可以实现任务完成事件的具体处理逻辑
        log.info("处理任务完成事件: taskId={}", taskId);
    }
    
    /**
     * 处理任务失败事件
     */
    private void handleTaskFailed(Message message, String taskId) {
        // 这里可以实现任务失败事件的具体处理逻辑
        log.info("处理任务失败事件: taskId={}", taskId);
    }
    
    /**
     * 处理任务进度更新事件
     */
    private void handleTaskProgressUpdated(Message message, String taskId) {
        // 这里可以实现任务进度更新事件的具体处理逻辑
        log.info("处理任务进度更新事件: taskId={}", taskId);
    }
} 