package com.ainovel.server.task.event.internal;

/**
 * 任务取消事件
 */
public class TaskCancelledEvent extends TaskApplicationEvent {

    /**
     * 创建任务取消事件
     * 
     * @param source 事件源
     * @param taskId 任务ID
     * @param taskType 任务类型
     * @param userId 用户ID
     */
    public TaskCancelledEvent(Object source, String taskId, String taskType, String userId) {
        super(source, taskId, taskType, userId);
    }
} 