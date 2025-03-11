package com.ainovel.server.common.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 错误响应模型
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ErrorResponse {
    
    private String message;
    private LocalDateTime timestamp = LocalDateTime.now();
    
    public ErrorResponse(String message) {
        this.message = message;
    }
} 