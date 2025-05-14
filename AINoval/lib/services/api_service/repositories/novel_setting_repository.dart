import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/models/setting_group.dart';

/// 小说设定仓储接口
abstract class NovelSettingRepository {
  // ==================== 设定条目管理 ====================
  /// 创建小说设定条目
  Future<NovelSettingItem> createSettingItem({
    required String novelId,
    required NovelSettingItem settingItem,
  });

  /// 获取小说设定条目列表
  Future<List<NovelSettingItem>> getNovelSettingItems({
    required String novelId,
    String? type,
    String? name,
    int? priority,
    String? generatedBy,
    String? status,
    required int page,
    required int size,
    required String sortBy,
    required String sortDirection,
  });

  /// 获取小说设定条目详情
  Future<NovelSettingItem> getSettingItemDetail({
    required String novelId,
    required String itemId,
  });

  /// 更新小说设定条目
  Future<NovelSettingItem> updateSettingItem({
    required String novelId,
    required String itemId,
    required NovelSettingItem settingItem,
  });

  /// 删除小说设定条目
  Future<void> deleteSettingItem({
    required String novelId,
    required String itemId,
  });

  /// 添加设定条目之间的关系
  Future<NovelSettingItem> addSettingRelationship({
    required String novelId,
    required String itemId,
    required String targetItemId,
    required String relationshipType,
    String? description,
  });

  /// 删除设定条目之间的关系
  Future<void> removeSettingRelationship({
    required String novelId,
    required String itemId,
    required String targetItemId,
    required String relationshipType,
  });

  // ==================== 设定组管理 ====================
  /// 创建设定组
  Future<SettingGroup> createSettingGroup({
    required String novelId,
    required SettingGroup settingGroup,
  });

  /// 获取小说的设定组列表
  Future<List<SettingGroup>> getNovelSettingGroups({
    required String novelId,
    String? name,
    bool? isActiveContext,
  });

  /// 获取设定组详情
  Future<SettingGroup> getSettingGroupDetail({
    required String novelId,
    required String groupId,
  });

  /// 更新设定组
  Future<SettingGroup> updateSettingGroup({
    required String novelId,
    required String groupId,
    required SettingGroup settingGroup,
  });

  /// 删除设定组
  Future<void> deleteSettingGroup({
    required String novelId,
    required String groupId,
  });

  /// 添加设定条目到设定组
  Future<SettingGroup> addItemToGroup({
    required String novelId,
    required String groupId,
    required String itemId,
  });

  /// 从设定组中移除设定条目
  Future<void> removeItemFromGroup({
    required String novelId,
    required String groupId,
    required String itemId,
  });

  /// 激活/停用设定组作为上下文
  Future<SettingGroup> setGroupActiveContext({
    required String novelId,
    required String groupId,
    required bool isActive,
  });

  // ==================== 高级功能 ====================
  /// 从文本中自动提取设定条目
  Future<List<NovelSettingItem>> extractSettingsFromText({
    required String novelId,
    required String text,
    required String type,
  });

  /// 根据关键词搜索设定条目
  Future<List<NovelSettingItem>> searchSettingItems({
    required String novelId,
    required String query,
    List<String>? types,
    List<String>? groupIds,
    double? minScore,
    int? maxResults,
  });
} 