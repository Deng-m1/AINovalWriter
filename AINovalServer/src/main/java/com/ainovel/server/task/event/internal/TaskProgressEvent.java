package com.ainovel.server.task.event.internal;

import org.springframework.context.ApplicationEvent;

import java.time.Instant;
import java.util.UUID;

/**
 * 任务进度更新事件
 */
public class TaskProgressEvent extends TaskApplicationEvent {
    
    private final Object progressData;
    
    /**
     * 创建任务进度事件
     * 
     * @param source 事件源
     * @param taskId 任务ID
     * @param progressData 进度数据
     */
    public TaskProgressEvent(Object source, String taskId, Object progressData) {
        super(source, taskId);
        this.progressData = progressData;
    }
    
    /**
     * 获取进度数据
     * 
     * @return 进度数据
     */
    public Object getProgressData() {
        return progressData;
    }
} 