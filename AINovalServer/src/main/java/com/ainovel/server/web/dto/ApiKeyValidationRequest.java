package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * API密钥验证请求DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ApiKeyValidationRequest {
    
    /**
     * 用户ID
     */
    private String userId;
    
    /**
     * 提供商名称
     */
    private String provider;
    
    /**
     * 模型名称
     */
    private String modelName;
    
    /**
     * API密钥
     */
    private String apiKey;
    
    // 手动添加getter和setter方法，以防Lombok注解未正确处理
    
    public String getUserId() {
        return userId;
    }
    
    public void setUserId(String userId) {
        this.userId = userId;
    }
    
    public String getProvider() {
        return provider;
    }
    
    public void setProvider(String provider) {
        this.provider = provider;
    }
    
    public String getModelName() {
        return modelName;
    }
    
    public void setModelName(String modelName) {
        this.modelName = modelName;
    }
    
    public String getApiKey() {
        return apiKey;
    }
    
    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }
} 