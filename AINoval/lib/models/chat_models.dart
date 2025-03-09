import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

// 聊天会话模型
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final List<ChatMessage> messages;
  final String novelId;
  final String? chapterId;
  
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.messages,
    required this.novelId,
    this.chapterId,
  });
  
  // 复制方法，用于创建会话的副本
  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    List<ChatMessage>? messages,
    String? novelId,
    String? chapterId,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      messages: messages ?? this.messages,
      novelId: novelId ?? this.novelId,
      chapterId: chapterId ?? this.chapterId,
    );
  }
  
  // 从JSON转换方法
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
      messages: (json['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      novelId: json['novelId'] as String,
      chapterId: json['chapterId'] as String?,
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'novelId': novelId,
      'chapterId': chapterId,
    };
  }
}

// 聊天消息模型
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final List<MessageAction>? actions;
  
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.actions,
  });
  
  // 复制方法
  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    List<MessageAction>? actions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      actions: actions ?? this.actions,
    );
  }
  
  // 从JSON转换方法
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.toString() == 'MessageRole.${json['role']}',
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${json['status']}',
        orElse: () => MessageStatus.sent,
      ),
      actions: json['actions'] != null
          ? (json['actions'] as List)
              .map((e) => MessageAction.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.toString().split('.').last,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
      'actions': actions?.map((e) => e.toJson()).toList(),
    };
  }
  
  // 格式化时间戳
  String get formattedTime => DateFormat('HH:mm').format(timestamp);
  
  // 格式化日期
  String get formattedDate => DateFormat('yyyy-MM-dd').format(timestamp);
}

// 消息发送者角色
enum MessageRole {
  user,
  assistant,
  system,
}

// 消息状态
enum MessageStatus {
  sending,
  sent,
  error,
  pending,
}

// 消息关联操作
class MessageAction {
  final String id;
  final String label;
  final ActionType type;
  final Map<String, dynamic>? data;
  
  MessageAction({
    required this.id,
    required this.label,
    required this.type,
    this.data,
  });
  
  // 从JSON转换方法
  factory MessageAction.fromJson(Map<String, dynamic> json) {
    return MessageAction(
      id: json['id'] as String,
      label: json['label'] as String,
      type: ActionType.values.firstWhere(
        (e) => e.toString() == 'ActionType.${json['type']}',
      ),
      data: json['data'] as Map<String, dynamic>?,
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.toString().split('.').last,
      'data': data,
    };
  }
}

// 操作类型
enum ActionType {
  applyToEditor,
  createCharacter,
  createLocation,
  generatePlot,
  expandScene,
  createChapter,
  analyzeSentiment,
  fixGrammar,
}

// 聊天上下文模型
class ChatContext {
  final String novelId;
  final String? chapterId;
  final String? selectedText;
  final List<ContextItem> relevantItems;
  
  ChatContext({
    required this.novelId,
    this.chapterId,
    this.selectedText,
    this.relevantItems = const [],
  });
  
  // 复制方法
  ChatContext copyWith({
    String? novelId,
    String? chapterId,
    String? selectedText,
    List<ContextItem>? relevantItems,
  }) {
    return ChatContext(
      novelId: novelId ?? this.novelId,
      chapterId: chapterId ?? this.chapterId,
      selectedText: selectedText ?? this.selectedText,
      relevantItems: relevantItems ?? this.relevantItems,
    );
  }
  
  // 从JSON转换方法
  factory ChatContext.fromJson(Map<String, dynamic> json) {
    return ChatContext(
      novelId: json['novelId'] as String,
      chapterId: json['chapterId'] as String?,
      selectedText: json['selectedText'] as String?,
      relevantItems: json['relevantItems'] != null
          ? (json['relevantItems'] as List)
              .map((e) => ContextItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'novelId': novelId,
      'chapterId': chapterId,
      'selectedText': selectedText,
      'relevantItems': relevantItems.map((e) => e.toJson()).toList(),
    };
  }
}

// 上下文项目
class ContextItem {
  final String id;
  final ContextItemType type;
  final String title;
  final String content;
  final double relevanceScore;
  
  ContextItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.relevanceScore,
  });
  
  // 从JSON转换方法
  factory ContextItem.fromJson(Map<String, dynamic> json) {
    return ContextItem(
      id: json['id'] as String,
      type: ContextItemType.values.firstWhere(
        (e) => e.toString() == 'ContextItemType.${json['type']}',
      ),
      title: json['title'] as String,
      content: json['content'] as String,
      relevanceScore: json['relevanceScore'] as double,
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'content': content,
      'relevanceScore': relevanceScore,
    };
  }
}

// 上下文项目类型
enum ContextItemType {
  character,
  location,
  plot,
  chapter,
  scene,
  note,
  lore,
}

// AI回复模型
class AIChatResponse {
  final String content;
  final List<MessageAction> actions;
  
  AIChatResponse({
    required this.content,
    this.actions = const [],
  });
  
  // 从JSON转换方法
  factory AIChatResponse.fromJson(Map<String, dynamic> json) {
    return AIChatResponse(
      content: json['content'] as String,
      actions: json['actions'] != null
          ? (json['actions'] as List)
              .map((e) => MessageAction.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'actions': actions.map((e) => e.toJson()).toList(),
    };
  }
} 