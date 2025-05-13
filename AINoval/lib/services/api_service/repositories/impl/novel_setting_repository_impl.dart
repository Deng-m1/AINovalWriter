import 'dart:async';

import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/models/setting_group.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/novel_setting_repository.dart';
import 'package:ainoval/utils/logger.dart';

/// 小说设定仓储实现
class NovelSettingRepositoryImpl implements NovelSettingRepository {
  NovelSettingRepositoryImpl({required this.apiClient});

  final ApiClient apiClient;

  // API路径基础部分
  String _getBasePath(String novelId) => '/api/v1/novels/$novelId/settings';

  // ==================== 设定条目管理 ====================
  @override
  Future<NovelSettingItem> createSettingItem({
    required String novelId,
    required NovelSettingItem settingItem,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '创建设定条目: novelId=$novelId, name=${settingItem.name}');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/items/create',
        data: settingItem.toJson(),
      );
      
      final result = NovelSettingItem.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '创建设定条目成功: id=${result.id}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '创建设定条目失败', e, stackTrace);
      rethrow;
    }
  }

  @override
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
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '获取设定条目列表: novelId=$novelId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/items/list',
        data: {
          'type': type,
          'name': name,
          'priority': priority,
          'generatedBy': generatedBy,
          'status': status,
          'page': page,
          'size': size,
          'sortBy': sortBy,
          'sortDirection': sortDirection,
        },
      );
      
      final List<dynamic> itemsJson = response;
      final items = itemsJson
          .map((json) => NovelSettingItem.fromJson(json))
          .toList();
      
      AppLogger.i('NovelSettingRepoImpl', '获取设定条目列表成功: count=${items.length}');
      return items;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '获取设定条目列表失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<NovelSettingItem> getSettingItemDetail({
    required String novelId,
    required String itemId,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '获取设定条目详情: novelId=$novelId, itemId=$itemId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/items/detail',
        data: {
          'itemId': itemId,
        },
      );
      
      final result = NovelSettingItem.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '获取设定条目详情成功: id=${result.id}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '获取设定条目详情失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<NovelSettingItem> updateSettingItem({
    required String novelId,
    required String itemId,
    required NovelSettingItem settingItem,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '更新设定条目: novelId=$novelId, itemId=$itemId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/items/update',
        data: {
          'itemId': itemId,
          'settingItem': settingItem.toJson(),
        },
      );
      
      final result = NovelSettingItem.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '更新设定条目成功: id=${result.id}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '更新设定条目失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteSettingItem({
    required String novelId,
    required String itemId,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '删除设定条目: novelId=$novelId, itemId=$itemId');
    try {
      await apiClient.post(
        '${_getBasePath(novelId)}/items/delete',
        data: {
          'itemId': itemId,
        },
      );
      
      AppLogger.i('NovelSettingRepoImpl', '删除设定条目成功');
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '删除设定条目失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<NovelSettingItem> addSettingRelationship({
    required String novelId,
    required String itemId,
    required String targetItemId,
    required String relationshipType,
    String? description,
  }) async {
    AppLogger.i('NovelSettingRepoImpl',
        '添加设定关系: novelId=$novelId, itemId=$itemId, targetItemId=$targetItemId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/items/add-relationship',
        data: {
          'itemId': itemId,
          'targetItemId': targetItemId,
          'relationshipType': relationshipType,
          'description': description,
        },
      );
      
      final result = NovelSettingItem.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '添加设定关系成功');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '添加设定关系失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeSettingRelationship({
    required String novelId,
    required String itemId,
    required String targetItemId,
    required String relationshipType,
  }) async {
    AppLogger.i('NovelSettingRepoImpl',
        '删除设定关系: novelId=$novelId, itemId=$itemId, targetItemId=$targetItemId');
    try {
      await apiClient.post(
        '${_getBasePath(novelId)}/items/remove-relationship',
        data: {
          'itemId': itemId,
          'targetItemId': targetItemId,
          'relationshipType': relationshipType,
        },
      );
      
      AppLogger.i('NovelSettingRepoImpl', '删除设定关系成功');
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '删除设定关系失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 设定组管理 ====================
  @override
  Future<SettingGroup> createSettingGroup({
    required String novelId,
    required SettingGroup settingGroup,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '创建设定组: novelId=$novelId, name=${settingGroup.name}');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/groups/create',
        data: settingGroup.toJson(),
      );
      
      final result = SettingGroup.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '创建设定组成功: id=${result.id}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '创建设定组失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<SettingGroup>> getNovelSettingGroups({
    required String novelId,
    String? name,
    bool? isActiveContext,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '获取设定组列表: novelId=$novelId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/groups/list',
        data: {
          'name': name,
          'isActiveContext': isActiveContext,
        },
      );
      
      final List<dynamic> groupsJson = response;
      final groups = groupsJson
          .map((json) => SettingGroup.fromJson(json))
          .toList();
      
      AppLogger.i('NovelSettingRepoImpl', '获取设定组列表成功: count=${groups.length}');
      return groups;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '获取设定组列表失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<SettingGroup> getSettingGroupDetail({
    required String novelId,
    required String groupId,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '获取设定组详情: novelId=$novelId, groupId=$groupId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/groups/detail',
        data: {
          'groupId': groupId,
        },
      );
      
      final result = SettingGroup.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '获取设定组详情成功: id=${result.id}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '获取设定组详情失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<SettingGroup> updateSettingGroup({
    required String novelId,
    required String groupId,
    required SettingGroup settingGroup,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '更新设定组: novelId=$novelId, groupId=$groupId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/groups/update',
        data: {
          'groupId': groupId,
          'settingGroup': settingGroup.toJson(),
        },
      );
      
      final result = SettingGroup.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '更新设定组成功: id=${result.id}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '更新设定组失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteSettingGroup({
    required String novelId,
    required String groupId,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '删除设定组: novelId=$novelId, groupId=$groupId');
    try {
      await apiClient.post(
        '${_getBasePath(novelId)}/groups/delete',
        data: {
          'groupId': groupId,
        },
      );
      
      AppLogger.i('NovelSettingRepoImpl', '删除设定组成功');
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '删除设定组失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<SettingGroup> addItemToGroup({
    required String novelId,
    required String groupId,
    required String itemId,
  }) async {
    AppLogger.i('NovelSettingRepoImpl',
        '添加条目到设定组: novelId=$novelId, groupId=$groupId, itemId=$itemId');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/groups/add-item',
        data: {
          'groupId': groupId,
          'itemId': itemId,
        },
      );
      
      final result = SettingGroup.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '添加条目到设定组成功');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '添加条目到设定组失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeItemFromGroup({
    required String novelId,
    required String groupId,
    required String itemId,
  }) async {
    AppLogger.i('NovelSettingRepoImpl',
        '从设定组移除条目: novelId=$novelId, groupId=$groupId, itemId=$itemId');
    try {
      await apiClient.post(
        '${_getBasePath(novelId)}/groups/remove-item',
        data: {
          'groupId': groupId,
          'itemId': itemId,
        },
      );
      
      AppLogger.i('NovelSettingRepoImpl', '从设定组移除条目成功');
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '从设定组移除条目失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<SettingGroup> setGroupActiveContext({
    required String novelId,
    required String groupId,
    required bool isActive,
  }) async {
    AppLogger.i('NovelSettingRepoImpl',
        '设置设定组激活状态: novelId=$novelId, groupId=$groupId, isActive=$isActive');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/groups/set-active',
        data: {
          'groupId': groupId,
          'active': isActive,
        },
      );
      
      final result = SettingGroup.fromJson(response);
      AppLogger.i('NovelSettingRepoImpl', '设置设定组激活状态成功');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '设置设定组激活状态失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 高级功能 ====================
  @override
  Future<List<NovelSettingItem>> extractSettingsFromText({
    required String novelId,
    required String text,
    required String type,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '从文本提取设定: novelId=$novelId, type=$type');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/extract',
        data: {
          'text': text,
          'type': type,
        },
      );
      
      final List<dynamic> itemsJson = response;
      final items = itemsJson
          .map((json) => NovelSettingItem.fromJson(json))
          .toList();
      
      AppLogger.i('NovelSettingRepoImpl', '从文本提取设定成功: count=${items.length}');
      return items;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '从文本提取设定失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<NovelSettingItem>> searchSettingItems({
    required String novelId,
    required String query,
    List<String>? types,
    List<String>? groupIds,
    double? minScore,
    int? maxResults,
  }) async {
    AppLogger.i('NovelSettingRepoImpl', '搜索设定条目: novelId=$novelId, query=$query');
    try {
      final response = await apiClient.post(
        '${_getBasePath(novelId)}/search',
        data: {
          'query': query,
          'types': types,
          'groupIds': groupIds,
          'minScore': minScore,
          'maxResults': maxResults,
        },
      );
      
      final List<dynamic> itemsJson = response;
      final items = itemsJson
          .map((json) => NovelSettingItem.fromJson(json))
          .toList();
      
      AppLogger.i('NovelSettingRepoImpl', '搜索设定条目成功: count=${items.length}');
      return items;
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingRepoImpl', '搜索设定条目失败', e, stackTrace);
      rethrow;
    }
  }
} 