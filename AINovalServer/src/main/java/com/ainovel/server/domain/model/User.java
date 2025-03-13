package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 用户领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "users")
public class User {
    
    @Id
    private String id;
    
    @Indexed(unique = true)
    private String username;
    
    private String password;
    
    @Indexed(unique = true)
    private String email;
    
    private String displayName;
    
    private String avatar;
    
    /**
     * 用户角色
     */
    @Builder.Default
    private List<String> roles = new ArrayList<>();
    
    /**
     * AI模型配置
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AIModelConfig {
        private String provider;  // 提供商，如openai, anthropic, etc.
        private String modelName; // 模型名称，如gpt-4, claude-3-opus, etc.
        private String apiKey;    // API密钥
        private String apiEndpoint; // API端点，可选
        private Map<String, Object> additionalConfig; // 额外配置
        private Boolean isDefault; // 是否为默认模型
    }
    
    /**
     * 用户的AI模型配置列表
     */
    @Builder.Default
    private List<AIModelConfig> aiModelConfigs = new ArrayList<>();
    
    /**
     * 用户偏好设置
     */
    @Builder.Default
    private Map<String, Object> preferences = new HashMap<>();
    
    private LocalDateTime createdAt;
    
    private LocalDateTime updatedAt;
    
    /**
     * 获取默认AI模型配置
     */
    public AIModelConfig getDefaultAIModelConfig() {
        return aiModelConfigs.stream()
                .filter(config -> Boolean.TRUE.equals(config.getIsDefault()))
                .findFirst()
                .orElse(aiModelConfigs.isEmpty() ? null : aiModelConfigs.get(0));
    }
    
    /**
     * 根据提供商和模型名称获取AI模型配置
     */
    public AIModelConfig getAIModelConfig(String provider, String modelName) {
        return aiModelConfigs.stream()
                .filter(config -> config.getProvider().equals(provider) && config.getModelName().equals(modelName))
                .findFirst()
                .orElse(null);
    }
} 