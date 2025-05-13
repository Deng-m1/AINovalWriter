import 'dart:convert';

/// 小说设定条目模型
class NovelSettingItem {
  final String? id;
  final String? novelId;
  final String? userId;
  final String name;
  final String? type;
  final String content;
  final String? description;
  final int? priority;
  final String? status;
  final String? generatedBy;
  final List<SettingRelationship>? relationships;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NovelSettingItem({
    this.id,
    this.novelId,
    this.userId,
    required this.name,
    this.type,
    required this.content,
    this.description,
    this.priority,
    this.status,
    this.generatedBy,
    this.relationships,
    this.createdAt,
    this.updatedAt,
  });

  factory NovelSettingItem.fromJson(Map<String, dynamic> json) {
    List<SettingRelationship>? relationships;
    if (json['relationships'] != null) {
      relationships = (json['relationships'] as List)
          .map((e) => SettingRelationship.fromJson(e))
          .toList();
    }

    return NovelSettingItem(
      id: json['id'],
      novelId: json['novelId'],
      userId: json['userId'],
      name: json['name'],
      type: json['type'],
      content: json['content'],
      description: json['description'],
      priority: json['priority'],
      status: json['status'],
      generatedBy: json['generatedBy'],
      relationships: relationships,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    if (novelId != null) data['novelId'] = novelId;
    if (userId != null) data['userId'] = userId;
    data['name'] = name;
    if (type != null) data['type'] = type;
    data['content'] = content;
    if (description != null) data['description'] = description;
    if (priority != null) data['priority'] = priority;
    if (status != null) data['status'] = status;
    if (generatedBy != null) data['generatedBy'] = generatedBy;
    if (relationships != null) {
      data['relationships'] = relationships!.map((e) => e.toJson()).toList();
    }
    return data;
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

/// 设定关系模型
class SettingRelationship {
  final String targetItemId;
  final String type;
  final String? description;

  SettingRelationship({
    required this.targetItemId,
    required this.type,
    this.description,
  });

  factory SettingRelationship.fromJson(Map<String, dynamic> json) {
    return SettingRelationship(
      targetItemId: json['targetItemId'],
      type: json['type'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['targetItemId'] = targetItemId;
    data['type'] = type;
    if (description != null) data['description'] = description;
    return data;
  }
} 