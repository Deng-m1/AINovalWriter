package com.ainovel.server.task.event.external;

import com.ainovel.server.task.model.TaskStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * 外部任务事件DTO，用于发送到RabbitMQ
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TaskExternalEvent {
    
    /**
     * 事件ID
     */
    private String eventId;
    
    /**
     * 事件时间
     */
    private Instant eventTime;
    
    /**
     * 事件类型
     */
    private String eventType;
    
    /**
     * 任务ID
     */
    private String taskId;
    
    /**
     * 任务类型
     */
    private String taskType;
    
    /**
     * 用户ID
     */
    private String userId;
    
    /**
     * 任务状态
     */
    private TaskStatus status;
    
    /**
     * 事件数据（根据事件类型不同而不同）
     */
    private Object eventData;
} 