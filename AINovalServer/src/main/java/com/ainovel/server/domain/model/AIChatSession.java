package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * AI聊天会话领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "ai_chat_sessions")
@CompoundIndexes({
    @CompoundIndex(name = "user_session_idx", def = "{'userId': 1, 'sessionId': 1}"),
    @CompoundIndex(name = "user_novel_idx", def = "{'userId': 1, 'novelId': 1}")
})
public class AIChatSession {

    @Id
    private String id;

    @Indexed
    private String sessionId;

    @Indexed
    private String userId;

    // 关联的小说ID（可选）
    private String novelId;

    // 会话标题（自动生成或用户指定）
    private String title;

    // 会话元数据
    private Map<String, Object> metadata;

    // 使用的AI模型配置
    private String selectedModelConfigId;

    // 会话状态（ACTIVE, ARCHIVED等）
    private String status;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // 最后一条消息的时间
    private LocalDateTime lastMessageAt;

    // 消息总数
    private int messageCount;
}
