
/// 场景历史版本条目
class SceneHistoryEntry {

  factory SceneHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SceneHistoryEntry(
      content: json['content'],
      updatedAt: DateTime.parse(json['updatedAt']),
      updatedBy: json['updatedBy'],
      reason: json['reason'],
    );
  }
  SceneHistoryEntry({
    this.content,
    required this.updatedAt,
    required this.updatedBy,
    required this.reason,
  });

  final String? content;
  final DateTime updatedAt;
  final String updatedBy;
  final String reason;

  Map<String, dynamic> toJson() => {
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'updatedBy': updatedBy,
    'reason': reason,
  };
}

/// 场景版本差异
class SceneVersionDiff {

  SceneVersionDiff({
    required this.originalContent,
    required this.newContent,
    required this.diff,
  });

  factory SceneVersionDiff.fromJson(Map<String, dynamic> json) {
    return SceneVersionDiff(
      originalContent: json['originalContent'] ?? '',
      newContent: json['newContent'] ?? '',
      diff: json['diff'] ?? '',
    );
  }
  final String originalContent;
  final String newContent;
  final String diff;

  Map<String, dynamic> toJson() => {
    'originalContent': originalContent,
    'newContent': newContent,
    'diff': diff,
  };
}

/// 场景内容更新请求
class SceneContentUpdateDto {

  SceneContentUpdateDto({
    required this.content,
    required this.userId,
    required this.reason,
  });
  final String content;
  final String userId;
  final String reason;

  Map<String, dynamic> toJson() => {
    'content': content,
    'userId': userId,
    'reason': reason,
  };
}

/// 场景版本恢复请求
class SceneRestoreDto {

  SceneRestoreDto({
    required this.historyIndex,
    required this.userId,
    required this.reason,
  });
  final int historyIndex;
  final String userId;
  final String reason;

  Map<String, dynamic> toJson() => {
    'historyIndex': historyIndex,
    'userId': userId,
    'reason': reason,
  };
}

/// 场景版本比较请求
class SceneVersionCompareDto {

  SceneVersionCompareDto({
    required this.versionIndex1,
    required this.versionIndex2,
  });
  final int versionIndex1;
  final int versionIndex2;

  Map<String, dynamic> toJson() => {
    'versionIndex1': versionIndex1,
    'versionIndex2': versionIndex2,
  };
} 