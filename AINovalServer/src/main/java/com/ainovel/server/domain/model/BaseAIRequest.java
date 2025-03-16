package com.ainovel.server.domain.model;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 基础AI请求模型
 * 只包含与AI模型交互必需的字段，不包含业务相关字段
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BaseAIRequest {
    
    /**
     * 用户ID（用于获取用户的API密钥和配置）
     */
    private String userId;
    
    /**
     * 请求的模型名称
     */
    private String model;
    
    /**
     * API密钥（直接提供，不需要通过用户ID查询）
     */
    private String apiKey;
    
    /**
     * API端点（可选，用于自定义API服务地址）
     */
    private String apiEndpoint;
    
    /**
     * 提示内容（单轮对话时使用）
     */
    private String prompt;
    
    /**
     * 最大生成令牌数
     */
    @Builder.Default
    private Integer maxTokens = 1000;
    
    /**
     * 温度参数（0-2之间，越高越随机）
     */
    @Builder.Default
    private Double temperature = 0.7;
    
    /**
     * 其他参数
     */
    @Builder.Default
    private Map<String, Object> parameters = Map.of();
    
    /**
     * 对话历史（多轮对话时使用）
     */
    @Builder.Default
    private List<Message> messages = new ArrayList<>();
    
    /**
     * 对话消息
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Message {
        /**
         * 角色（user, assistant, system）
         */
        private String role;
        
        /**
         * 消息内容
         */
        private String content;
    }
} 