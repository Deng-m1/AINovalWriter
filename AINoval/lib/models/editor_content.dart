import 'package:equatable/equatable.dart';

class EditorContent extends Equatable {
  
  const EditorContent({
    required this.id,
    required this.content,
    required this.lastSaved,
    this.revisions = const [],
    this.scenes,
  });
  
  // 从JSON转换
  factory EditorContent.fromJson(Map<String, dynamic> json) {
    Map<String, SceneContent>? scenesMap;
    if (json['scenes'] != null) {
      scenesMap = {};
      json['scenes'].forEach((key, value) {
        scenesMap![key] = SceneContent.fromJson(value);
      });
    }

    return EditorContent(
      id: json['id'],
      content: json['content'],
      lastSaved: DateTime.parse(json['lastSaved']),
      revisions: (json['revisions'] as List?)
          ?.map((e) => Revision.fromJson(e))
          .toList() ?? [],
      scenes: scenesMap,
    );
  }
  final String id;
  final String content;
  final DateTime lastSaved;
  final List<Revision> revisions;
  final Map<String, SceneContent>? scenes;
  
  @override
  List<Object?> get props => [id, content, lastSaved, revisions, scenes];
  
  // 创建副本但更新部分内容
  EditorContent copyWith({
    String? id,
    String? content,
    DateTime? lastSaved,
    List<Revision>? revisions,
    Map<String, SceneContent>? scenes,
  }) {
    return EditorContent(
      id: id ?? this.id,
      content: content ?? this.content,
      lastSaved: lastSaved ?? this.lastSaved,
      revisions: revisions ?? this.revisions,
      scenes: scenes ?? this.scenes,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'content': content,
      'lastSaved': lastSaved.toIso8601String(),
      'revisions': revisions.map((e) => e.toJson()).toList(),
    };

    if (scenes != null) {
      data['scenes'] = {};
      scenes!.forEach((key, value) {
        data['scenes'][key] = value.toJson();
      });
    }

    return data;
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

class SceneContent extends Equatable {

  const SceneContent({
    required this.content,
    required this.summary,
    required this.title,
    required this.subtitle,
  });

  // 从JSON转换
  factory SceneContent.fromJson(Map<String, dynamic> json) {
    return SceneContent(
      content: json['content'] ?? '',
      summary: json['summary'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
    );
  }
  final String content;
  final String summary;
  final String title;
  final String subtitle;

  @override
  List<Object?> get props => [content, summary, title, subtitle];
  
  // 创建副本但更新部分内容
  SceneContent copyWith({
    String? content,
    String? summary,
    String? title,
    String? subtitle,
  }) {
    return SceneContent(
      content: content ?? this.content,
      summary: summary ?? this.summary,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'summary': summary,
      'title': title,
      'subtitle': subtitle,
    };
  }
} 