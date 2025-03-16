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
 * AI聊天消息领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "ai_chat_messages")
@CompoundIndexes({
    @CompoundIndex(name = "session_message_idx", def = "{'sessionId': 1, 'createdAt': 1}"),
    @CompoundIndex(name = "user_message_idx", def = "{'userId': 1, 'createdAt': 1}")
})
public class AIChatMessage {

    @Id
    private String id;

    @Indexed
    private String sessionId;

    @Indexed
    private String userId;

    // 消息角色：user/assistant/system
    private String role;

    // 消息内容
    private String content;

    // 关联的小说ID（可选）
    private String novelId;

    // 关联的场景ID（可选）
    private String sceneId;

    // 使用的AI模型
    private String modelName;

    // 消息元数据
    private Map<String, Object> metadata;

    // 消息状态（SENT, DELIVERED, READ等）
    private String status;

    // 消息类型（TEXT, IMAGE, COMMAND等）
    private String messageType;

    // 父消息ID（用于消息线程）
    private String parentMessageId;

    // 消息token数
    private Integer tokenCount;

    private LocalDateTime createdAt;
}
