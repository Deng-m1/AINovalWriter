package com.ainovel.server.task.listener;

import com.ainovel.server.task.event.internal.TaskSubmittedEvent;
import com.ainovel.server.task.producer.TaskMessageProducer;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.concurrent.ConcurrentHashMap;

/**
 * 任务提交事件监听器，负责监听任务提交事件并发送任务消息到MQ
 */
@Slf4j
@Component
public class TaskSubmissionListener {

    private final TaskMessageProducer taskMessageProducer;
    private final ConcurrentHashMap<String, Boolean> processedEventIds = new ConcurrentHashMap<>();
    
    @Autowired
    public TaskSubmissionListener(TaskMessageProducer taskMessageProducer) {
        this.taskMessageProducer = taskMessageProducer;
    }
    
    /**
     * 监听任务提交事件，将任务发送到消息队列
     * 
     * @param event 任务提交事件
     * @return 包含操作完成信号的Mono
     */
    @EventListener
    public Mono<Void> onTaskSubmitted(TaskSubmittedEvent event) {
        return Mono.defer(() -> {
            // 幂等性检查，防止重复处理同一事件
            if (!checkAndMarkEventProcessed(event.getEventId())) {
                log.debug("事件已处理，跳过发送MQ消息: {} - {}", event.getEventId(), event.getTaskId());
                return Mono.empty();
            }
            
            log.info("收到任务提交事件，发送任务到MQ: taskId={}, taskType={}", 
                     event.getTaskId(), event.getTaskType());
            
            // 调用TaskMessageProducer发送任务消息到MQ
            return taskMessageProducer.sendTask(
                event.getTaskId(), 
                event.getUserId(), 
                event.getTaskType(),
                event.getParameters()
            ).doOnError(e -> {
                log.error("发送任务到MQ失败: taskId={}, taskType={}, error={}", 
                         event.getTaskId(), event.getTaskType(), e.getMessage(), e);
                // 异常情况下移除幂等标记，允许后续重试
                processedEventIds.remove(event.getEventId());
            }).doOnSuccess(v -> {
                log.debug("成功发送任务到MQ: taskId={}, taskType={}", 
                         event.getTaskId(), event.getTaskType());
            });
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    /**
     * 检查事件是否已处理并标记为已处理 (幂等性)
     * 
     * @param eventId 事件ID
     * @return 如果事件未处理过返回true，否则返回false
     */
    private boolean checkAndMarkEventProcessed(String eventId) {
        return processedEventIds.putIfAbsent(eventId, Boolean.TRUE) == null;
    }
} 