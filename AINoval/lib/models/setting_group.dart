import 'dart:convert';

/// 设定组模型
class SettingGroup {
  final String? id;
  final String? novelId;
  final String? userId;
  final String name;
  final String? description;
  final bool? isActiveContext;
  final List<String>? itemIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SettingGroup({
    this.id,
    this.novelId,
    this.userId,
    required this.name,
    this.description,
    this.isActiveContext,
    this.itemIds,
    this.createdAt,
    this.updatedAt,
  });

  factory SettingGroup.fromJson(Map<String, dynamic> json) {
    List<String>? itemIds;
    if (json['itemIds'] != null) {
      itemIds = List<String>.from(json['itemIds']);
    }

    dynamic createdAtJson = json['createdAt'];
    String? createdAtString;
    if (createdAtJson is String) {
      createdAtString = createdAtJson;
    } else if (createdAtJson is List && createdAtJson.isNotEmpty && createdAtJson.first is String) {
      createdAtString = createdAtJson.first;
    }

    dynamic updatedAtJson = json['updatedAt'];
    String? updatedAtString;
    if (updatedAtJson is String) {
      updatedAtString = updatedAtJson;
    } else if (updatedAtJson is List && updatedAtJson.isNotEmpty && updatedAtJson.first is String) {
      updatedAtString = updatedAtJson.first;
    }

    return SettingGroup(
      id: json['id'],
      novelId: json['novelId'],
      userId: json['userId'],
      name: json['name'],
      description: json['description'],
      isActiveContext: json['isActiveContext'],
      itemIds: itemIds,
      createdAt: createdAtString != null
          ? DateTime.parse(createdAtString)
          : null,
      updatedAt: updatedAtString != null
          ? DateTime.parse(updatedAtString)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    if (novelId != null) data['novelId'] = novelId;
    if (userId != null) data['userId'] = userId;
    data['name'] = name;
    if (description != null) data['description'] = description;
    if (isActiveContext != null) data['isActiveContext'] = isActiveContext;
    if (itemIds != null) data['itemIds'] = itemIds;
    return data;
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
} 