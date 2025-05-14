package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.HashMap;
import java.util.Map;

/**
 * 任务提交响应DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TaskSubmissionResponse {
    
    /**
     * 任务ID
     */
    private String taskId;
    
    /**
     * 错误信息映射
     */
    private Map<String, String> errors;
    
    /**
     * 只使用taskId初始化的构造函数
     * 
     * @param taskId 任务ID
     */
    public TaskSubmissionResponse(String taskId) {
        this.taskId = taskId;
        this.errors = new HashMap<>();
    }
} 