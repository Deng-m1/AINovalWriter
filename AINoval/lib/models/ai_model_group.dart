import 'package:ainoval/models/model_info.dart'; // Import ModelInfo
import 'package:meta/meta.dart';

/// AI模型分组模型，用于UI显示
@immutable
class AIModelGroup {
  const AIModelGroup({
    required this.provider,
    required this.groups,
  });

  final String provider;
  final List<ModelPrefixGroup> groups;

  /// 从 ModelInfo 列表创建分组
  factory AIModelGroup.fromModelInfoList(String provider, List<ModelInfo> models) {
    final Map<String, List<ModelInfo>> groupedModels = {};

    for (final modelInfo in models) {
      String prefix;
      // Use model ID for prefix extraction
      final modelId = modelInfo.id;
      if (modelId.contains('/')) {
        prefix = modelId.split('/').first;
      } else if (modelId.contains(':')) {
        prefix = modelId.split(':').first;
      } else if (modelId.contains('-')) {
        final parts = modelId.split('-');
        prefix = parts.first;
      } else {
        prefix = modelId;
      }

      if (!groupedModels.containsKey(prefix)) {
        groupedModels[prefix] = [];
      }
      groupedModels[prefix]!.add(modelInfo);
    }

    final groups = groupedModels.entries
        .map((entry) => ModelPrefixGroup(
              prefix: entry.key,
              // Pass ModelInfo list to ModelPrefixGroup constructor
              modelsInfo: entry.value, 
            ))
        .toList();

    groups.sort((a, b) => a.prefix.compareTo(b.prefix));

    return AIModelGroup(
      provider: provider,
      groups: groups,
    );
  }

  /// 获取所有模型的平铺列表
  List<ModelInfo> get allModelsInfo {
    final List<ModelInfo> result = [];
    for (final group in groups) {
      result.addAll(group.modelsInfo);
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AIModelGroup &&
        other.provider == provider &&
        _listEquals(other.groups, groups);
  }

  @override
  int get hashCode => provider.hashCode ^ Object.hashAll(groups);

  // 辅助方法：比较两个列表是否相等
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 按前缀分组的模型
@immutable
class ModelPrefixGroup {
  const ModelPrefixGroup({
    required this.prefix,
    required this.modelsInfo, // Change from models (List<String>)
  });

  final String prefix;
  final List<ModelInfo> modelsInfo; // Store ModelInfo

  // Keep models getter for backward compatibility or UI that needs strings?
  List<String> get models => modelsInfo.map((info) => info.id).toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ModelPrefixGroup &&
        other.prefix == prefix &&
        _listEquals(other.modelsInfo, modelsInfo); // Compare ModelInfo lists
  }

  @override
  int get hashCode => prefix.hashCode ^ Object.hashAll(modelsInfo);

  // 辅助方法：比较两个列表是否相等
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
