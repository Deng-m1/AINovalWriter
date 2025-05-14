/// 设定条目列表请求DTO
class SettingItemListRequest {
  final String? type;
  final String? name;
  final int? priority;
  final String? generatedBy;
  final String? status;
  final int page;
  final int size;
  final String sortBy;
  final String sortDirection;

  SettingItemListRequest({
    this.type,
    this.name,
    this.priority,
    this.generatedBy,
    this.status,
    this.page = 0,
    this.size = 20,
    this.sortBy = 'createdAt',
    this.sortDirection = 'desc',
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (name != null) data['name'] = name;
    if (priority != null) data['priority'] = priority;
    if (generatedBy != null) data['generatedBy'] = generatedBy;
    if (status != null) data['status'] = status;
    data['page'] = page;
    data['size'] = size;
    data['sortBy'] = sortBy;
    data['sortDirection'] = sortDirection;
    return data;
  }
}

/// 设定条目详情请求DTO
class SettingItemDetailRequest {
  final String itemId;

  SettingItemDetailRequest({required this.itemId});

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
    };
  }
}

/// 设定条目更新请求DTO
class SettingItemUpdateRequest {
  final String itemId;
  final dynamic settingItem;

  SettingItemUpdateRequest({required this.itemId, required this.settingItem});

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'settingItem': settingItem,
    };
  }
}

/// 设定条目删除请求DTO
class SettingItemDeleteRequest {
  final String itemId;

  SettingItemDeleteRequest({required this.itemId});

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
    };
  }
}

/// 设定关系请求DTO
class SettingRelationshipRequest {
  final String itemId;
  final String targetItemId;
  final String relationshipType;
  final String? description;

  SettingRelationshipRequest({
    required this.itemId,
    required this.targetItemId,
    required this.relationshipType,
    this.description,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['itemId'] = itemId;
    data['targetItemId'] = targetItemId;
    data['relationshipType'] = relationshipType;
    if (description != null) data['description'] = description;
    return data;
  }
}

/// 设定关系删除请求DTO
class SettingRelationshipDeleteRequest {
  final String itemId;
  final String targetItemId;
  final String relationshipType;

  SettingRelationshipDeleteRequest({
    required this.itemId,
    required this.targetItemId,
    required this.relationshipType,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'targetItemId': targetItemId,
      'relationshipType': relationshipType,
    };
  }
}

/// 设定组列表请求DTO
class SettingGroupListRequest {
  final String? name;
  final bool? isActiveContext;

  SettingGroupListRequest({this.name, this.isActiveContext});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (isActiveContext != null) data['isActiveContext'] = isActiveContext;
    return data;
  }
}

/// 设定组详情请求DTO
class SettingGroupDetailRequest {
  final String groupId;

  SettingGroupDetailRequest({required this.groupId});

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
    };
  }
}

/// 设定组更新请求DTO
class SettingGroupUpdateRequest {
  final String groupId;
  final dynamic settingGroup;

  SettingGroupUpdateRequest({required this.groupId, required this.settingGroup});

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'settingGroup': settingGroup,
    };
  }
}

/// 设定组删除请求DTO
class SettingGroupDeleteRequest {
  final String groupId;

  SettingGroupDeleteRequest({required this.groupId});

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
    };
  }
}

/// 设定组条目请求DTO
class GroupItemRequest {
  final String groupId;
  final String itemId;

  GroupItemRequest({required this.groupId, required this.itemId});

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'itemId': itemId,
    };
  }
}

/// 设置设定组激活状态请求DTO
class SetGroupActiveRequest {
  final String groupId;
  final bool active;

  SetGroupActiveRequest({required this.groupId, required this.active});

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'active': active,
    };
  }
}

/// 从文本提取设定条目请求DTO
class ExtractSettingsRequest {
  final String text;
  final String type;

  ExtractSettingsRequest({required this.text, required this.type});

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type,
    };
  }
}

/// 搜索设定条目请求DTO
class SettingSearchRequest {
  final String query;
  final List<String>? types;
  final List<String>? groupIds;
  final double? minScore;
  final int? maxResults;

  SettingSearchRequest({
    required this.query,
    this.types,
    this.groupIds,
    this.minScore,
    this.maxResults,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['query'] = query;
    if (types != null) data['types'] = types;
    if (groupIds != null) data['groupIds'] = groupIds;
    if (minScore != null) data['minScore'] = minScore;
    if (maxResults != null) data['maxResults'] = maxResults;
    return data;
  }
} 