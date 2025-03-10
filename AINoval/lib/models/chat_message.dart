/// 消息发送者枚举
enum MessageSender {
  user,  // 用户发送的消息
  ai,    // AI助手发送的消息
}

/// 聊天消息模型
class ChatMessage {
  
  /// 构造函数
  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
  });
  
  /// 从JSON创建ChatMessage实例
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      sender: MessageSender.values.byName(json['sender'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
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
  
  /// 将ChatMessage实例转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
} 