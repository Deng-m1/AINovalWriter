import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/services/mock_data_service.dart';
import 'package:ainoval/utils/logger.dart';

/// 编辑器仓库实现
class EditorRepositoryImpl implements EditorRepository {
  EditorRepositoryImpl({
    ApiClient? apiClient,
    MockDataService? mockService,
    LocalStorageService? localStorageService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _mockService = mockService ?? MockDataService(),
        _localStorageService = localStorageService ?? LocalStorageService();
        
  final ApiClient _apiClient;
  final MockDataService _mockService;
  final LocalStorageService _localStorageService;
  
  /// 获取本地存储服务
  LocalStorageService getLocalStorageService() {
    return _localStorageService;
  }

  /// 获取编辑器内容
  @override
  Future<EditorContent> getEditorContent(
      String novelId, String chapterId, String sceneId) async {
    if (AppConfig.shouldUseMockData) {
      return _mockService.getEditorContent(novelId, chapterId, sceneId);
    }

    try {
      final data = await _apiClient.getEditorContent(novelId, chapterId, sceneId);
      return EditorContent.fromJson(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取编辑器内容失败',
          e);
      rethrow;
    }
  }

  /// 保存编辑器内容
  @override
  Future<void> saveEditorContent(EditorContent content) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    try {
      final parts = content.id.split('-');
      if (parts.length < 2) {
        throw ApiException(-1, '无效的内容ID格式');
      }

      final novelId = parts[0];
      final chapterId = parts[1];

      await _apiClient.saveEditorContent(
        novelId, 
        chapterId, 
        content.toJson()
      );
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '保存编辑器内容失败',
          e);
      throw ApiException(-1, '保存编辑器内容失败: $e');
    }
  }

  /// 获取修订历史
  @override
  Future<List<Revision>> getRevisionHistory(
      String novelId, String chapterId) async {
    if (AppConfig.shouldUseMockData) {
      return _mockService.getRevisionHistory(novelId, chapterId);
    }

    try {
      final data = await _apiClient.getRevisionHistory(novelId, chapterId);
      if (data is List) {
        return data.map((json) => Revision.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取修订历史失败',
          e);
      rethrow;
    }
  }

  /// 创建修订版本
  @override
  Future<Revision> createRevision(
      String novelId, String chapterId, Revision revision) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return revision;
    }

    try {
      final data = await _apiClient.createRevision(
          novelId, chapterId, revision.toJson());
      return Revision.fromJson(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '创建修订版本失败',
          e);
      throw ApiException(-1, '创建修订版本失败: $e');
    }
  }

  /// 应用修订版本
  @override
  Future<void> applyRevision(
      String novelId, String chapterId, String revisionId) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    try {
      await _apiClient.applyRevision(novelId, chapterId, revisionId);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '应用修订版本失败',
          e);
      throw ApiException(-1, '应用修订版本失败: $e');
    }
  }

  /// 获取小说详情
  @override
  Future<Novel?> getNovel(String novelId) async {
    try {
      if (AppConfig.shouldUseMockData) {
        return _mockService.getNovel(novelId);
      }
      
      final data = await _apiClient.getNovelDetailById(novelId);
      
      // data现在应该是NovelWithScenesDto格式，Novel.fromJson已经能够处理这种格式
      final novel = Novel.fromJson(data);
      
      return novel;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取小说失败',
          e);
      return null;
    }
  }
  
  /// 保存小说数据
  @override
  Future<bool> saveNovel(Novel novel) async {
    try {
      // 首先保存到本地存储
      await _localStorageService.saveNovel(novel);
      
      // 标记需要同步
      await _localStorageService.markForSyncByType(novel.id, 'novel');
      
      // 如果使用模拟数据，则不发送到API
      if (AppConfig.shouldUseMockData) {
        return true;
      }
      
      // 异步发送到API
      try {
        // 构造包含作者信息的请求体
        final Map<String, dynamic> novelJson = novel.toJson();
        
        // 如果没有作者信息，添加当前用户作为作者
        if (novelJson['author'] == null) {
          novelJson['author'] = {
            'id': AppConfig.userId ?? 'unknown',
            'username': AppConfig.username ?? 'user',
          };
        }
        
        // 发送到API
        await _apiClient.updateNovel(novelJson);
        return true;
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '保存小说到服务器失败，但已保存到本地',
            e);
        // 即使API调用失败，我们仍然返回true，因为数据已保存到本地
        return true;
      }
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '保存小说失败',
          e);
      return false;
    }
  }
  
  /// 获取场景内容
  @override
  Future<Scene?> getSceneContent(
      String novelId, String actId, String chapterId, String sceneId) async {
    try {
      if (AppConfig.shouldUseMockData) {
        return _mockService.getSceneContent(novelId, actId, chapterId, sceneId);
      }
      
      // 首先从本地存储获取
      final localScene = await _localStorageService.getSceneContent(
        novelId, actId, chapterId, sceneId);
      
      if (localScene != null) {
        return localScene;
      }
      
      // 如果本地没有，则从API获取
      final data = await _apiClient.getSceneById(novelId, chapterId, sceneId);
      final scene = Scene.fromJson(data);
      
      // 保存到本地存储
      await _localStorageService.saveSceneContent(
        novelId, actId, chapterId, sceneId, scene);
      
      return scene;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取场景内容失败',
          e);
      return null;
    }
  }
  
  /// 保存场景内容
  @override
  Future<Scene> saveSceneContent(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
    String content,
    String wordCount,
    Summary summary,
  ) async {
    try {
      // 获取当前场景
      Scene? scene;
      try {
        scene = await getSceneContent(novelId, actId, chapterId, sceneId);
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '获取场景失败，将创建新场景',
            e);
        scene = null;
      }
      
      // 如果场景不存在，创建一个新的场景
      scene ??= Scene(
        id: sceneId,
        content: content,
        wordCount: int.tryParse(wordCount) ?? 0,
        summary: summary,
        lastEdited: DateTime.now(),
        version: 1,
        history: [],
      );
      
      // 更新场景内容
      final updatedScene = scene.copyWith(
        content: content,
        wordCount: int.tryParse(wordCount) ?? 0,
        summary: summary,
        lastEdited: DateTime.now(),
      );
      
      // 保存到本地存储
      await _localStorageService.saveSceneContent(
        novelId, actId, chapterId, sceneId, updatedScene);
      
      // 标记需要同步
      final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
      await _localStorageService.markForSyncByType(sceneKey, 'scene');
      
      // 如果使用模拟数据，则不发送到API
      if (AppConfig.shouldUseMockData) {
        return updatedScene;
      }
      
      // 发送到API
      try {
        await _apiClient.updateScene({
          'novelId': novelId,
          'chapterId': chapterId,
          'sceneId': sceneId,
          'content': content,
          'wordCount': wordCount,
          'summary': summary.toJson(),
        });
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '保存场景内容到服务器失败，但已保存到本地',
            e);
        // 我们仍然返回更新的场景，因为数据已保存到本地
      }
      
      return updatedScene;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '保存场景内容失败',
          e);
      throw ApiException(-1, '保存场景内容失败: $e');
    }
  }
  
  /// 保存摘要
  @override
  Future<Summary> saveSummary(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
    String content,
  ) async {
    try {
      // 获取当前场景
      final scene = await getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene == null) {
        throw ApiException(-1, '场景不存在');
      }
      
      // 更新摘要内容
      final updatedSummary = scene.summary.copyWith(
        content: content,
      );
      
      // 更新场景并保存到本地
      final updatedScene = scene.copyWith(summary: updatedSummary);
      await _localStorageService.saveSceneContent(
        novelId, actId, chapterId, sceneId, updatedScene);
      
      // 标记需要同步
      final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
      await _localStorageService.markForSyncByType(sceneKey, 'scene');
      
      if (AppConfig.shouldUseMockData) {
        _mockService.updateSummary(novelId, actId, chapterId, sceneId, updatedSummary);
        await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
        return updatedSummary;
      }
      
      // 发送到API
      try {
        await _apiClient.updateScene({
          'novelId': novelId,
          'chapterId': chapterId,
          'sceneId': sceneId,
          'summary': updatedSummary.toJson(),
        });
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '保存摘要到服务器失败，但已保存到本地',
            e);
        // 仍然返回更新的摘要
      }
      
      return updatedSummary;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '保存摘要失败',
          e);
      throw ApiException(-1, '保存摘要失败: $e');
    }
  }
  
  /// 获取编辑器设置
  @override
  Future<Map<String, dynamic>> getEditorSettings() async {
    try {
      // 默认设置
      final defaultSettings = {
        'fontSize': 16.0,
        'lineHeight': 1.5,
        'fontFamily': 'Roboto',
        'theme': 'light',
        'autoSave': true,
      };
      
      if (AppConfig.shouldUseMockData) {
        return defaultSettings;
      }
      
      try {
        // 从服务器获取设置
        final data = await _apiClient.post('/editor/get-settings', data: {});
        return Map<String, dynamic>.from(data);
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '获取编辑器设置从服务器失败，使用默认设置',
            e);
        return defaultSettings;
      }
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取编辑器设置失败',
          e);
      // 返回默认设置
      return {
        'fontSize': 16.0,
        'lineHeight': 1.5,
        'fontFamily': 'Roboto',
        'theme': 'light',
        'autoSave': true,
      };
    }
  }
  
  /// 保存编辑器设置
  @override
  Future<void> saveEditorSettings(Map<String, dynamic> settings) async {
    try {
      // 保存到本地
      await _localStorageService.saveEditorSettings(settings);
      
      if (AppConfig.shouldUseMockData) {
        await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
        return;
      }
      
      // 保存到服务器
      try {
        await _apiClient.post('/editor/save-settings', data: settings);
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '保存编辑器设置到服务器失败，但已保存到本地',
            e);
      }
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '保存编辑器设置失败',
          e);
      throw ApiException(-1, '保存编辑器设置失败: $e');
    }
  }
}
