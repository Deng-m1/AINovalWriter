package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

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
} 