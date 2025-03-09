import 'package:equatable/equatable.dart';

class EditorContent extends Equatable {
  
  const EditorContent({
    required this.id,
    required this.content,
    required this.lastSaved,
    this.revisions = const [],
  });
  
  // 从JSON转换
  factory EditorContent.fromJson(Map<String, dynamic> json) {
    return EditorContent(
      id: json['id'],
      content: json['content'],
      lastSaved: DateTime.parse(json['lastSaved']),
      revisions: (json['revisions'] as List?)
          ?.map((e) => Revision.fromJson(e))
          .toList() ?? [],
    );
  }
  final String id;
  final String content;
  final DateTime lastSaved;
  final List<Revision> revisions;
  
  @override
  List<Object?> get props => [id, content, lastSaved, revisions];
  
  // 创建副本但更新部分内容
  EditorContent copyWith({
    String? id,
    String? content,
    DateTime? lastSaved,
    List<Revision>? revisions,
  }) {
    return EditorContent(
      id: id ?? this.id,
      content: content ?? this.content,
      lastSaved: lastSaved ?? this.lastSaved,
      revisions: revisions ?? this.revisions,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'lastSaved': lastSaved.toIso8601String(),
      'revisions': revisions.map((e) => e.toJson()).toList(),
    };
  }
}

class Revision extends Equatable {
  
  const Revision({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.authorId,
    this.comment = '',
  });
  
  // 从JSON转换
  factory Revision.fromJson(Map<String, dynamic> json) {
    return Revision(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      authorId: json['authorId'],
      comment: json['comment'] ?? '',
    );
  }
  final String id;
  final String content;
  final DateTime timestamp;
  final String authorId;
  final String comment;
  
  @override
  List<Object?> get props => [id, content, timestamp, authorId, comment];
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'authorId': authorId,
      'comment': comment,
    };
  }
} 