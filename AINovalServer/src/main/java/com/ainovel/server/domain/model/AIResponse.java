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
     * 推理内容
     */
    private String reasoningContent;
    
    /**
     * 工具调用
     */
    @Builder.Default
    private List<ToolCall> toolCalls = new ArrayList<>();
    
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
        
        // 手动添加getter和setter方法，以防Lombok注解未正确处理
        
        public Integer getPromptTokens() {
            return promptTokens;
        }
        
        public void setPromptTokens(Integer promptTokens) {
            this.promptTokens = promptTokens;
        }
        
        public Integer getCompletionTokens() {
            return completionTokens;
        }
        
        public void setCompletionTokens(Integer completionTokens) {
            this.completionTokens = completionTokens;
        }
    }
    
    /**
     * 工具调用
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ToolCall {
        /**
         * 调用ID
         */
        private String id;
        
        /**
         * 调用类型
         */
        private String type;
        
        /**
         * 函数
         */
        private Function function;
    }
    
    /**
     * 函数
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Function {
        /**
         * 函数名称
         */
        private String name;
        
        /**
         * 函数参数
         */
        private String arguments;
    }
    
    // 手动添加getter和setter方法，以防Lombok注解未正确处理
    
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getModel() {
        return model;
    }
    
    public void setModel(String model) {
        this.model = model;
    }
    
    public String getContent() {
        return content;
    }
    
    public void setContent(String content) {
        this.content = content;
    }
    
    public String getReasoningContent() {
        return reasoningContent;
    }
    
    public void setReasoningContent(String reasoningContent) {
        this.reasoningContent = reasoningContent;
    }
    
    public List<ToolCall> getToolCalls() {
        return toolCalls;
    }
    
    public void setToolCalls(List<ToolCall> toolCalls) {
        this.toolCalls = toolCalls;
    }
    
    public TokenUsage getTokenUsage() {
        return tokenUsage;
    }
    
    public void setTokenUsage(TokenUsage tokenUsage) {
        this.tokenUsage = tokenUsage;
    }
    
    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
    
    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
    
    public String getFinishReason() {
        return finishReason;
    }
    
    public void setFinishReason(String finishReason) {
        this.finishReason = finishReason;
    }
    
    public List<String> getUsedContext() {
        return usedContext;
    }
    
    public void setUsedContext(List<String> usedContext) {
        this.usedContext = usedContext;
    }
    
    public Map<String, Object> getMetadata() {
        return metadata;
    }
    
    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata;
    }
} 