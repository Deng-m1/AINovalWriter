import 'package:intl/intl.dart';

import '../utils/date_time_parser.dart';

// 聊天会话模型
class ChatSession {
  
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.novelId,
    this.chapterId,
    this.modelName,
    this.status,
    this.messageCount,
  });
  
  // 从JSON转换方法
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    // 辅助函数安全地获取和转换 String
    String safeString(String key, [String defaultValue = '']) {
      return json[key] as String? ?? defaultValue;
    }
    // 辅助函数安全地获取和解析 DateTime
    DateTime safeDateTime(String key, DateTime defaultValue) {
      final value = json[key] as String?;
      return value != null ? (DateTime.tryParse(value) ?? defaultValue) : defaultValue;
    }

    return ChatSession(
      // 使用 sessionId 作为 id，并提供一个默认空字符串以防万一
      id: safeString('sessionId'),
      title: safeString('title', '无标题会话'),
      createdAt: parseBackendDateTime(json['createdAt']),
      lastUpdatedAt: parseBackendDateTime(json['updatedAt']),
      novelId: safeString('novelId'),
      chapterId: json['chapterId'] as String?,
      modelName: json['modelName'] as String?,
      status: json['status'] as String?,
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
    );
  }
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final String novelId;
  final String? chapterId;
  final String? modelName;
  final String? status;
  final int? messageCount;
  
  // 复制方法，用于创建会话的副本
  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    String? novelId,
    String? chapterId,
    String? modelName,
    String? status,
    int? messageCount,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      novelId: novelId ?? this.novelId,
      chapterId: chapterId ?? this.chapterId,
      modelName: modelName ?? this.modelName,
      status: status ?? this.status,
      messageCount: messageCount ?? this.messageCount,
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'novelId': novelId,
      'chapterId': chapterId,
      'modelName': modelName,
      'status': status,
      'messageCount': messageCount,
    };
  }
}

// 聊天消息模型
class ChatMessage {
  
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.actions,
    this.sessionId,
    this.userId,
    this.novelId,
    this.modelName,
    this.metadata,
  });
  
  // 从JSON转换方法
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<MessageAction>? parsedActions;
    if (json['metadata'] != null && json['metadata']['actions'] is List) {
       parsedActions = (json['metadata']['actions'] as List)
           .map((e) => MessageAction.fromJson(e as Map<String, dynamic>))
           .toList();
    }

    return ChatMessage(
      id: json['id'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.name == (json['role'] as String?)?.toLowerCase(),
        orElse: () => MessageRole.system,
      ),
      content: json['content'] as String,
      timestamp: parseBackendDateTime(json['createdAt']),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?)?.toLowerCase(),
        orElse: () => MessageStatus.sent,
      ),
      actions: parsedActions,
      sessionId: json['sessionId'] as String?,
      userId: json['userId'] as String?,
      novelId: json['novelId'] as String?,
      modelName: json['modelName'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final List<MessageAction>? actions;
  final String? sessionId;
  final String? userId;
  final String? novelId;
  final String? modelName;
  final Map<String, dynamic>? metadata;
  
  // 复制方法
  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    List<MessageAction>? actions,
    String? sessionId,
    String? userId,
    String? novelId,
    String? modelName,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      actions: actions ?? this.actions,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      novelId: novelId ?? this.novelId,
      modelName: modelName ?? this.modelName,
      metadata: metadata ?? this.metadata,
    );
  }
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> currentMetadata = Map.from(metadata ?? {});
    if (actions != null) {
      currentMetadata['actions'] = actions!.map((e) => e.toJson()).toList();
    }
    
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'createdAt': timestamp.toIso8601String(),
      'status': status.name,
      'sessionId': sessionId,
      'userId': userId,
      'novelId': novelId,
      'modelName': modelName,
      'metadata': currentMetadata.isEmpty ? null : currentMetadata,
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
  delivered,
  read,
  streaming,
}

// 消息关联操作
class MessageAction {
  
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
  final String id;
  final String label;
  final ActionType type;
  final Map<String, dynamic>? data;
  
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
  
  ChatContext({
    required this.novelId,
    this.chapterId,
    this.selectedText,
    this.relevantItems = const [],
  });
  
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
  final String novelId;
  final String? chapterId;
  final String? selectedText;
  final List<ContextItem> relevantItems;
  
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
  final String id;
  final ContextItemType type;
  final String title;
  final String content;
  final double relevanceScore;
  
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