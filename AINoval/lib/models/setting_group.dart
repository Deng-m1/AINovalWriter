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

    return SettingGroup(
      id: json['id'],
      novelId: json['novelId'],
      userId: json['userId'],
      name: json['name'],
      description: json['description'],
      isActiveContext: json['isActiveContext'],
      itemIds: itemIds,
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