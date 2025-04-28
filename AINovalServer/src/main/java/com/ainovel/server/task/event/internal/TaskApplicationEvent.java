package com.ainovel.server.task.event.internal;

import lombok.Getter;
import org.springframework.context.ApplicationEvent;

import java.time.Instant;
import java.util.UUID;

/**
 * 任务相关事件的基类
 */
@Getter
public abstract class TaskApplicationEvent extends ApplicationEvent {
    
    /**
     * 事件ID，用于幂等性处理
     */
    private String eventId;
    
    /**
     * 事件发生时间（Instant类型，与ApplicationEvent.getTimestamp()不同）
     */
    private final Instant eventTime;
    
    /**
     * 任务ID
     */
    private final String taskId;
    
    /**
     * 任务类型（可选）
     */
    private final String taskType;
    
    /**
     * 用户ID（可选）
     */
    private final String userId;
    
    /**
     * 创建任务事件（基本信息）
     * 
     * @param source 事件源
     * @param taskId 任务ID
     */
    public TaskApplicationEvent(Object source, String taskId) {
        this(source, taskId, null, null);
    }
    
    /**
     * 创建任务事件（完整信息）
     * 
     * @param source 事件源
     * @param taskId 任务ID
     * @param taskType 任务类型
     * @param userId 用户ID
     */
    public TaskApplicationEvent(Object source, String taskId, String taskType, String userId) {
        super(source);
        this.eventId = UUID.randomUUID().toString();
        this.eventTime = Instant.now();
        this.taskId = taskId;
        this.taskType = taskType;
        this.userId = userId;
    }
    
    /**
     * 手动设置事件ID
     * 主要用于测试或需要确保事件ID一致性的场景
     * 
     * @param eventId 要设置的事件ID
     */
    public void setEventId(String eventId) {
        this.eventId = eventId;
    }
} 