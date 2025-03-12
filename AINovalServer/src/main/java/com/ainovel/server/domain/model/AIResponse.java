package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * AI响应模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AIResponse {
    
    /**
     * 响应ID
     */
    private String id;
    
    /**
     * 使用的模型
     */
    private String model;
    
    /**
     * 生成的内容
     */
    private String content;
    
    /**
     * 使用的令牌数
     */
    @Builder.Default
    private TokenUsage tokenUsage = new TokenUsage();
    
    /**
     * 生成时间
     */
    @Builder.Default
    private LocalDateTime createdAt = LocalDateTime.now();
    
    /**
     * 完成原因
     */
    private String finishReason;
    
    /**
     * 使用的上下文
     */
    @Builder.Default
    private List<String> usedContext = new ArrayList<>();
    
    /**
     * 其他元数据
     */
    @Builder.Default
    private Map<String, Object> metadata = Map.of();
    
    /**
     * 令牌使用情况
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TokenUsage {
        /**
         * 提示令牌数
         */
        @Builder.Default
        private Integer promptTokens = 0;
        
        /**
         * 完成令牌数
         */
        @Builder.Default
        private Integer completionTokens = 0;
        
        /**
         * 总令牌数
         */
        public Integer getTotalTokens() {
            return promptTokens + completionTokens;
        }
    }
} 