/// 消息发送者枚举
enum MessageSender {
  user,  // 用户发送的消息
  ai,    // AI助手发送的消息
}

// 可以为消息状态定义一个枚举
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error,
  unknown, // 处理未知状态
}

// 可以为消息类型定义一个枚举
enum MessageType {
  text,
  image,
  audio,
  command,
  unknown, // 处理未知类型
}

/// 聊天消息模型
class ChatMessage {
  
  /// 构造函数
  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    // 添加新字段，设为可选，以便旧数据或不需要这些字段的地方能兼容
    this.sessionId,
    this.status,
    this.messageType,
    this.metadata,
  });
  
  /// 从JSON创建ChatMessage实例
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // 修正：根据后端 'role' 字段映射到 'sender' 枚举
    MessageSender sender;
    final role = json['role'] as String?;
    if (role == 'assistant') {
      sender = MessageSender.ai;
    } else if (role == 'user') {
      sender = MessageSender.user;
    } else {
       sender = MessageSender.ai; // 或其他默认处理
       print("Warning: Unknown message role '$role' received, mapping to 'ai'.");
    }

    // 解析 status (可选)
    MessageStatus? status;
    final statusString = json['status'] as String?;
    if (statusString != null) {
        try {
            status = MessageStatus.values.byName(statusString.toLowerCase());
        } catch (e) {
            status = MessageStatus.unknown;
            print("Warning: Unknown message status '$statusString' received.");
        }
    }

    // 解析 messageType (可选)
    MessageType? messageType;
    final typeString = json['messageType'] as String?;
     if (typeString != null) {
        try {
            messageType = MessageType.values.byName(typeString.toLowerCase());
        } catch (e) {
            messageType = MessageType.unknown;
            print("Warning: Unknown message type '$typeString' received.");
        }
    }

    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      sender: sender, // 使用上面转换后的 sender
      // 修正：读取 'createdAt' 字段并解析为 DateTime
      timestamp: DateTime.parse(json['createdAt'] as String),
      // 读取新添加的可选字段
      sessionId: json['sessionId'] as String?,
      status: status,
      messageType: messageType,
      metadata: json['metadata'] as Map<String, dynamic>?, // Dart 中通常用 Map<String, dynamic>
    );
  }
  /// 消息唯一标识符
  final String id;
  
  /// 消息内容
  final String content;
  
  /// 消息发送者
  final MessageSender sender;
  
  /// 消息发送时间
  final DateTime timestamp;

  // --- 新添加的字段 ---
  /// 会话ID (可选)
  final String? sessionId;

  /// 消息状态 (可选)
  final MessageStatus? status;

  /// 消息类型 (可选)
  final MessageType? messageType;

  /// 消息元数据 (可选)
  final Map<String, dynamic>? metadata;
  // --- 结束 ---


  /// 将ChatMessage实例转换为JSON
  Map<String, dynamic> toJson() {
    // 修正：将 sender 枚举映射到后端的 'role' 字符串
    String role;
    if (sender == MessageSender.ai) {
      role = 'assistant';
    } else {
      role = 'user'; 
    }

    // 注意：通常前端发送消息时，不需要发送所有字段给后端
    // 比如 status, messageType 可能由后端确定或不需要前端发送
    // sessionId 通常在请求的 URL 或其他地方指定，而不是在消息体里
    // metadata 可能需要发送
    // 这里我们只包含基础字段和 metadata 示例，根据你的 API 设计调整
    final data = <String, dynamic>{
      'id': id, // id 通常由后端生成，发送时可能不需要或为空
      'content': content,
      // 修正：使用 'role' 键和映射后的值
      'role': role,
      // 修正：使用 'createdAt' 键 (或者后端会自己设置时间戳？根据API定)
      // 'createdAt': timestamp.toIso8601String(), // 如果需要前端指定创建时间
    };

    // 按需添加其他字段到发送的 JSON 中
    if (sessionId != null) {
       // 通常 sessionId 不在消息体里发送，而是在 URL 或 DTO 的顶层字段
       // data['sessionId'] = sessionId; 
    }
     if (metadata != null) {
       data['metadata'] = metadata;
     }
     // status 和 messageType 通常不由前端指定发送

    return data;
  }
} 