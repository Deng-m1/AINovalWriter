package com.ainovel.server.domain.model;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * AI请求模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AIRequest {
    
    /**
     * 请求的模型名称
     */
    private String model;
    
    /**
     * 提示内容
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
     * 是否启用上下文
     */
    @Builder.Default
    private Boolean enableContext = true;
    
    /**
     * 上下文相关的小说ID
     */
    private String novelId;
    
    /**
     * 上下文相关的场景ID
     */
    private String sceneId;
    
    /**
     * 其他参数
     */
    @Builder.Default
    private Map<String, Object> parameters = Map.of();
    
    /**
     * 对话历史
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