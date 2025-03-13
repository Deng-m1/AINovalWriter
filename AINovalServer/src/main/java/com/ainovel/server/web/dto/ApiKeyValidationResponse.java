package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * API密钥验证响应DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ApiKeyValidationResponse {
    
    /**
     * 是否有效
     */
    private Boolean isValid;
    
} 