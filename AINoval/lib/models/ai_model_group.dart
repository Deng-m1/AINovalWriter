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

  /// 从模型列表创建分组
  factory AIModelGroup.fromModelList(String provider, List<String> models) {
    // 按模型前缀分组
    final Map<String, List<String>> groupedModels = {};

    for (final model in models) {
      // 提取前缀，使用第一个 '/' 或 ':' 或 '-' 作为分隔符
      // 如果没有这些分隔符，则使用整个模型名称作为前缀
      String prefix;
      if (model.contains('/')) {
        prefix = model.split('/').first;
      } else if (model.contains(':')) {
        prefix = model.split(':').first;
      } else if (model.contains('-')) {
        final parts = model.split('-');
        // 对于像 gpt-3.5-turbo 这样的模型，我们希望前缀是 gpt
        prefix = parts.first;
      } else {
        prefix = model;
      }

      // 添加到对应的分组
      if (!groupedModels.containsKey(prefix)) {
        groupedModels[prefix] = [];
      }
      groupedModels[prefix]!.add(model);
    }

    // 转换为 ModelPrefixGroup 列表
    final groups = groupedModels.entries
        .map((entry) => ModelPrefixGroup(
              prefix: entry.key,
              models: entry.value,
            ))
        .toList();

    // 按前缀字母顺序排序
    groups.sort((a, b) => a.prefix.compareTo(b.prefix));

    return AIModelGroup(
      provider: provider,
      groups: groups,
    );
  }

  /// 获取所有模型的平铺列表
  List<String> get allModels {
    final List<String> result = [];
    for (final group in groups) {
      result.addAll(group.models);
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
    required this.models,
  });

  final String prefix;
  final List<String> models;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ModelPrefixGroup &&
        other.prefix == prefix &&
        _listEquals(other.models, models);
  }

  @override
  int get hashCode => prefix.hashCode ^ Object.hashAll(models);

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
