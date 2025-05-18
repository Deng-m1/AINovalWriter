import 'dart:convert';
import 'package:equatable/equatable.dart';

/// 小说设定条目模型
class NovelSettingItem extends Equatable {
  final String? id;
  final String? novelId;
  final String? userId;
  final String name;
  final String? type;
  final String content;
  final String? description;
  final Map<String, String>? attributes;
  final String? imageUrl;
  final List<SettingRelationship>? relationships;
  final List<String>? sceneIds;
  final int? priority;
  final String? generatedBy;
  final List<String>? tags;
  final String? status;
  final List<double>? vector;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAiSuggestion;
  final Map<String, dynamic>? metadata;

  const NovelSettingItem({
    this.id,
    this.novelId,
    this.userId,
    required this.name,
    this.type,
    required this.content,
    this.description,
    this.attributes,
    this.imageUrl,
    this.relationships,
    this.sceneIds,
    this.priority,
    this.generatedBy,
    this.tags,
    this.status,
    this.vector,
    this.createdAt,
    this.updatedAt,
    this.isAiSuggestion = false,
    this.metadata,
  });

  factory NovelSettingItem.fromJson(Map<String, dynamic> json) {
    List<SettingRelationship>? relationships;
    if (json['relationships'] != null && json['relationships'] is List) {
      relationships = (json['relationships'] as List)
          .map((e) => SettingRelationship.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    Map<String, String>? attributesMap;
    if (json['attributes'] != null && json['attributes'] is Map) {
      attributesMap = Map<String, String>.from(json['attributes'] as Map);
    }

    List<String>? tagsList;
    if (json['tags'] != null && json['tags'] is List) {
      tagsList = List<String>.from(json['tags'] as List);
    }
    
    List<String>? sceneIdsList;
    if (json['sceneIds'] != null && json['sceneIds'] is List) {
      sceneIdsList = List<String>.from(json['sceneIds'] as List);
    }

    List<double>? vectorList;
    if (json['vector'] != null && json['vector'] is List) {
      vectorList = (json['vector'] as List).map((e) => (e as num).toDouble()).toList();
    }
    
    Map<String, dynamic>? metadataMap;
    if (json['metadata'] != null && json['metadata'] is Map) {
      metadataMap = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    return NovelSettingItem(
      id: json['id'] as String?,
      novelId: json['novelId'] as String?,
      userId: json['userId'] as String?,
      name: json['name'] as String? ?? '未命名设定',
      type: json['type'] as String?,
      content: json['content'] as String? ?? '',
      description: json['description'] as String?,
      attributes: attributesMap,
      imageUrl: json['imageUrl'] as String?,
      relationships: relationships,
      sceneIds: sceneIdsList,
      priority: json['priority'] as int?,
      status: json['status'] as String?,
      generatedBy: json['generatedBy'] as String?,
      tags: tagsList,
      vector: vectorList,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      isAiSuggestion: json['isAiSuggestion'] as bool? ?? false,
      metadata: metadataMap,
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
    if (attributes != null) data['attributes'] = attributes;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (relationships != null) {
      data['relationships'] = relationships!.map((e) => e.toJson()).toList();
    }
    if (sceneIds != null) data['sceneIds'] = sceneIds;
    if (priority != null) data['priority'] = priority;
    if (generatedBy != null) data['generatedBy'] = generatedBy;
    if (tags != null) data['tags'] = tags;
    if (status != null) data['status'] = status;
    if (vector != null) data['vector'] = vector;
    if (createdAt != null) data['createdAt'] = createdAt!.toIso8601String();
    if (updatedAt != null) data['updatedAt'] = updatedAt!.toIso8601String();
    data['isAiSuggestion'] = isAiSuggestion;
    if (metadata != null) data['metadata'] = metadata;
    return data;
  }

  NovelSettingItem copyWith({
    String? id,
    String? novelId,
    String? userId,
    String? name,
    String? type,
    String? content,
    String? description,
    Map<String, String>? attributes,
    String? imageUrl,
    List<SettingRelationship>? relationships,
    List<String>? sceneIds,
    int? priority,
    String? generatedBy,
    List<String>? tags,
    String? status,
    List<double>? vector,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAiSuggestion,
    Map<String, dynamic>? metadata,
  }) {
    return NovelSettingItem(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      content: content ?? this.content,
      description: description ?? this.description,
      attributes: attributes ?? this.attributes,
      imageUrl: imageUrl ?? this.imageUrl,
      relationships: relationships ?? this.relationships,
      sceneIds: sceneIds ?? this.sceneIds,
      priority: priority ?? this.priority,
      generatedBy: generatedBy ?? this.generatedBy,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      vector: vector ?? this.vector,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAiSuggestion: isAiSuggestion ?? this.isAiSuggestion,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    id, novelId, userId, name, type, content, description, attributes, 
    imageUrl, relationships, sceneIds, priority, generatedBy, tags, status, 
    vector, createdAt, updatedAt, isAiSuggestion, metadata
  ];

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

/// 设定关系模型
class SettingRelationship extends Equatable {
  final String targetItemId;
  final String type;
  final String? description;
  final int? strength;
  final String? direction;
  final DateTime? createdAt;
  final Map<String, dynamic>? attributes;

  const SettingRelationship({
    required this.targetItemId,
    required this.type,
    this.description,
    this.strength,
    this.direction,
    this.createdAt,
    this.attributes,
  });

  factory SettingRelationship.fromJson(Map<String, dynamic> json) {
    return SettingRelationship(
      targetItemId: json['targetItemId'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      strength: json['strength'] as int?,
      direction: json['direction'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      attributes: json['attributes'] != null ? Map<String, dynamic>.from(json['attributes']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['targetItemId'] = targetItemId;
    data['type'] = type;
    if (description != null) data['description'] = description;
    if (strength != null) data['strength'] = strength;
    if (direction != null) data['direction'] = direction;
    if (createdAt != null) data['createdAt'] = createdAt!.toIso8601String();
    if (attributes != null) data['attributes'] = attributes;
    return data;
  }

  @override
  List<Object?> get props => [targetItemId, type, description, strength, direction, createdAt, attributes];
} 