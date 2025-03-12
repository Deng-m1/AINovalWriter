package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * AI交互领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "ai_interactions")
public class AIInteraction {
    
    @Id
    private String id;
    
    private String userId;
    
    private String novelId;
    
    /**
     * 对话消息
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Message {
        private String role;  // user, assistant
        private String content;
        private LocalDateTime timestamp;
        
        /**
         * 相关上下文
         */
        @Data
        @Builder
        @NoArgsConstructor
        @AllArgsConstructor
        public static class Context {
            @Builder.Default
            private List<String> sceneIds = new ArrayList<>();
            @Builder.Default
            private List<String> characterIds = new ArrayList<>();
            private Double retrievalScore;
        }
        
        private Context context;
    }
    
    @Builder.Default
    private List<Message> conversation = new ArrayList<>();
    
    /**
     * 生成内容
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Generation {
        private String prompt;
        private String result;
        private String model;
        private Map<String, Object> parameters;
        
        /**
         * Token使用情况
         */
        @Data
        @Builder
        @NoArgsConstructor
        @AllArgsConstructor
        public static class TokenUsage {
            private Integer prompt;
            private Integer completion;
            private Integer total;
        }
        
        private TokenUsage tokenUsage;
        private Double cost;
        private LocalDateTime createdAt;
    }
    
    @Builder.Default
    private List<Generation> generations = new ArrayList<>();
    
    private LocalDateTime createdAt;
    
    private LocalDateTime updatedAt;
} 