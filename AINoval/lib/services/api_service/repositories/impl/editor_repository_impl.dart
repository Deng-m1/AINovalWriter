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

  /// 将后端NovelWithScenesDto模型转换为前端Novel模型
  Novel _convertBackendNovelWithScenesToFrontend(Map<String, dynamic> backendData) {
    // 提取小说基本信息
    final backendNovel = backendData['novel'];
    
    // 提取所有场景数据，按章节ID分组
    final Map<String, List<dynamic>> scenesByChapter = 
        backendData['scenesByChapter'] != null 
            ? Map<String, List<dynamic>>.from(backendData['scenesByChapter']) 
            : {};
    
    // 提取作者信息
    Author? author;
    if (backendNovel.containsKey('author') && backendNovel['author'] != null) {
      final authorData = backendNovel['author'];
      author = Author(
        id: authorData['id'],
        username: authorData['username'],
      );
    }
    
    // 提取Acts和Chapters
    List<Act> acts = [];
    if (backendNovel.containsKey('structure') && 
        backendNovel['structure'] is Map && 
        (backendNovel['structure'] as Map).containsKey('acts')) {
      
      acts = ((backendNovel['structure'] as Map)['acts'] as List)
        .map((actData) {
          // 转换章节
          List<Chapter> chapters = [];
          if (actData.containsKey('chapters') && actData['chapters'] is List) {
            chapters = (actData['chapters'] as List).map((chapterData) {
              final chapterId = chapterData['id'];
              // 从scenesByChapter获取该章节的所有场景
              List<Scene> scenes = [];
              
              // 检查是否有该章节的场景数据
              if (scenesByChapter.containsKey(chapterId) && scenesByChapter[chapterId] is List) {
                scenes = (scenesByChapter[chapterId] as List).map((sceneData) {
                  // 使用_convertBackendSceneToFrontend将后端场景数据转换为前端模型
                  return _convertBackendSceneToFrontend(sceneData);
                }).toList();
              }
              
              return Chapter(
                id: chapterId,
                title: chapterData['title'],
                order: chapterData['order'],
                scenes: scenes,
              );
            }).toList();
          }
          
          return Act(
            id: actData['id'],
            title: actData['title'],
            order: actData['order'],
            chapters: chapters,
          );
        }).toList();
    }
    
    // 解析时间
    DateTime createdAt;
    DateTime updatedAt;
    
    try {
      createdAt = backendNovel.containsKey('createdAt') 
          ? DateTime.parse(backendNovel['createdAt']) 
          : DateTime.now();
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    try {
      updatedAt = backendNovel.containsKey('updatedAt') 
          ? DateTime.parse(backendNovel['updatedAt']) 
          : DateTime.now();
    } catch (e) {
      updatedAt = DateTime.now();
    }
    
    // 创建Novel对象
    return Novel(
      id: backendNovel['id'],
      title: backendNovel['title'] ?? '无标题',
      coverImagePath: backendNovel['coverImage'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      acts: acts,
      lastEditedChapterId: backendNovel['lastEditedChapterId'],
      author: author,
    );
  }

  /// 获取小说详情
  @override
  Future<Novel?> getNovel(String novelId) async {
    try {
      if (AppConfig.shouldUseMockData) {
        return _mockService.getNovel(novelId);
      }
      
      // 尝试从本地存储获取
      final localNovel = await _localStorageService.getNovel(novelId);
      if (localNovel != null) {
        return localNovel;
      }
      
      // 从API获取小说与所有场景
      try {
        final data = await _apiClient.getNovelDetailById(novelId);
        
        // 使用专门的转换方法处理 NovelWithScenesDto 数据格式
        final novel = _convertBackendNovelWithScenesToFrontend(data);
        
        // 保存到本地存储
        await _localStorageService.saveNovel(novel);
        
        return novel;
      } catch (e) {
        // 如果获取小说与场景的接口失败，尝试只获取小说基本信息
        AppLogger.w(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '获取小说和场景失败，尝试只获取小说基本信息',
            e);
            
        final data = await _apiClient.getNovelDetailById(novelId);
        
        // 使用原有转换方法将后端模型转换为前端模型
        final novel = _convertBackendNovelWithScenesToFrontend(data);
        
        // 保存到本地存储
        await _localStorageService.saveNovel(novel);
        
        return novel;
      }
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取小说失败',
          e);
      return null;
    }
  }
  
  /// 将前端Novel模型转换为后端API所需的JSON格式
  Map<String, dynamic> _convertFrontendNovelToBackendJson(Novel novel) {
    return {
      'id': novel.id,
      'title': novel.title,
      'coverImage': novel.coverImagePath,
      'createdAt': novel.createdAt.toIso8601String(),
      'updatedAt': novel.updatedAt.toIso8601String(),
      'lastEditedChapterId': novel.lastEditedChapterId,
      'author': novel.author?.toJson() ?? {
        'id': AppConfig.userId ?? 'unknown',
        'username': AppConfig.username ?? 'user',
      },
      'structure': {
        'acts': novel.acts.map((act) => {
          'id': act.id,
          'title': act.title,
          'order': act.order,
          'chapters': act.chapters.map((chapter) => {
            'id': chapter.id,
            'title': chapter.title,
            'order': chapter.order,
            'sceneIds': chapter.scenes.map((scene) => scene.id).toList(),
          }).toList(),
        }).toList(),
      },
      'metadata': {
        'wordCount': novel.wordCount,
        'readTime': (novel.wordCount / 200).ceil(),
        'lastEditedAt': novel.updatedAt.toIso8601String(),
        'version': 1, // 版本号可能需要更复杂的逻辑
        'contributors': [AppConfig.username ?? 'user'],
      },
      'status': 'draft', // 状态可能需要根据实际情况设置
    };
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
        // 使用转换方法构造小说基本信息
        final Map<String, dynamic> backendNovelJson = _convertFrontendNovelToBackendJson(novel);
        
        // 构造所有场景内容
        Map<String, List<Map<String, dynamic>>> scenesByChapter = {};
        for (final act in novel.acts) {
          for (final chapter in act.chapters) {
            if (chapter.scenes.isNotEmpty) {
              // 使用转换方法构造场景列表
              scenesByChapter[chapter.id] = chapter.scenes
                  .map((scene) => _convertFrontendSceneToBackendJson(scene, novel.id, chapter.id))
                  .toList();
            }
          }
        }
        
        // 构造包含小说和场景的请求体
        final novelWithScenesJson = {
          'novel': backendNovelJson,
          'scenesByChapter': scenesByChapter,
        };
        
        // 发送到API (假设ApiClient有对应方法，否则保持post)
        // 建议在ApiClient中添加 updateNovelWithScenes 方法
        await _apiClient.updateNovelWithScenes(novelWithScenesJson); 
        // 或者保持: await _apiClient.post('/api/v1/novels/upsert-with-scenes', data: novelWithScenesJson); // 假设有这样一个端点
        
        // 清除同步标记 (如果API调用成功)
        // await _localStorageService.clearSyncMark(novel.id, 'novel'); // 取决于同步策略
        
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
  
  /// 将前端Scene模型转换为后端API所需的JSON格式 (用于upsert)
  Map<String, dynamic> _convertFrontendSceneToBackendJson(Scene scene, String novelId, String chapterId) {
    return {
      'id': scene.id,
      'novelId': novelId,
      'chapterId': chapterId,
      'content': scene.content,
      'summary': scene.summary.content,
      'wordCount': scene.wordCount,
      'updatedAt': scene.lastEdited.toIso8601String(),
      'version': scene.version,
      'title': '',
      'sequence': 0,
      'sceneType': 'NORMAL',
      'history': scene.history.map((entry) => {
        'content': entry.content,
        'updatedAt': entry.updatedAt.toIso8601String(),
        'updatedBy': entry.updatedBy,
        'reason': entry.reason,
      }).toList(),
    };
  }

  /// 将后端Scene模型转换为前端Scene模型
  Scene _convertBackendSceneToFrontend(Map<String, dynamic> backendScene) {
    // 后端Scene模型中summary是字符串，需要转换为Summary对象
    final Summary summary = Summary(
      id: '${backendScene['id']}_summary', 
      content: backendScene['summary'] ?? '',
    );
    
    // 解析历史记录
    List<HistoryEntry> history = [];
    if (backendScene.containsKey('history') && backendScene['history'] is List) {
      history = (backendScene['history'] as List).map((historyEntry) => 
        HistoryEntry(
          content: historyEntry['content'],
          updatedAt: DateTime.parse(historyEntry['updatedAt']),
          updatedBy: historyEntry['updatedBy'] ?? 'unknown',
          reason: historyEntry['reason'] ?? '',
        )
      ).toList();
    }
    
    // 解析时间
    DateTime lastEdited;
    try {
      lastEdited = backendScene.containsKey('updatedAt') 
          ? DateTime.parse(backendScene['updatedAt']) 
          : DateTime.now();
    } catch (e) {
      lastEdited = DateTime.now();
    }
    
    // 创建Scene对象
    return Scene(
      id: backendScene['id'],
      content: backendScene['content'] ?? '',
      wordCount: backendScene['wordCount'] ?? 0,
      summary: summary,
      lastEdited: lastEdited,
      version: backendScene['version'] ?? 1,
      history: history,
    );
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
      
      // 使用转换方法将后端模型转换为前端模型
      final scene = _convertBackendSceneToFrontend(data);
      
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
        AppLogger.w( // 使用 warning 级别可能更合适
            'Services/api_service/repositories/impl/editor_repository_impl',
            '获取场景失败，将创建新场景',
            e);
        scene = null;
      }
      
      final currentWordCount = int.tryParse(wordCount) ?? 0;
      
      // 如果场景不存在，创建一个新的场景
      scene ??= Scene(
        id: sceneId,
        content: content,
        wordCount: currentWordCount,
        summary: summary,
        lastEdited: DateTime.now(),
        version: 1,
        history: [],
      );
      
      // 更新场景内容
      final updatedScene = scene.copyWith(
        content: content,
        wordCount: currentWordCount,
        summary: summary,
        lastEdited: DateTime.now(),
        // 考虑版本号递增逻辑
        // version: scene.version + 1, 
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
        // 使用转换方法构造后端JSON
        final Map<String, dynamic> backendSceneJson = 
            _convertFrontendSceneToBackendJson(updatedScene, novelId, chapterId);
        
        // 使用SceneController中的upsert接口保存完整场景内容
        // 建议在ApiClient中添加 upsertScene 方法
        await _apiClient.updateScene(backendSceneJson);
        // 或者保持: await _apiClient.post('/api/v1/scenes/upsert', data: backendSceneJson);
        
        // 清除同步标记 (如果API调用成功)
        // await _localStorageService.clearSyncMark(sceneKey, 'scene'); // 取决于同步策略
        
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
        // 考虑是否应该创建一个新场景，或者严格要求场景必须存在
        throw ApiException(-1, '场景不存在: $sceneId'); 
      }
      
      // 更新摘要内容
      final updatedSummary = scene.summary.copyWith(
        content: content,
      );
      
      // 更新场景并保存到本地
      // 注意：这里只更新了摘要，但 lastEdited 时间也应该更新
      final updatedScene = scene.copyWith(
        summary: updatedSummary,
        lastEdited: DateTime.now(), 
        // 考虑版本号是否也需要更新
      );
      await _localStorageService.saveSceneContent(
        novelId, actId, chapterId, sceneId, updatedScene);
      
      // 标记需要同步
      final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
      await _localStorageService.markForSyncByType(sceneKey, 'scene');
      
      if (AppConfig.shouldUseMockData) {
        // _mockService.updateSummary(novelId, actId, chapterId, sceneId, updatedSummary); // 确保 mock 服务有此方法或类似逻辑
        await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
        return updatedSummary;
      }
      
      // 发送到API - 使用 upsert 接口更新整个场景
      try {
        // 使用转换方法构造后端JSON
        final Map<String, dynamic> backendSceneJson = 
            _convertFrontendSceneToBackendJson(updatedScene, novelId, chapterId);
            
        // 使用SceneController中的upsert接口保存完整场景内容
        // 建议在ApiClient中添加 upsertScene 方法
        await _apiClient.updateScene(backendSceneJson);
        // 或者保持: await _apiClient.post('/api/v1/scenes/upsert', data: backendSceneJson);
        
        // 清除同步标记 (如果API调用成功)
        // await _localStorageService.clearSyncMark(sceneKey, 'scene'); // 取决于同步策略
        
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
      // 重新抛出更具体的异常
      throw ApiException(-1, '保存摘要失败: $e'); 
    }
  }
  
  /// 获取编辑器设置
  @override
  Future<Map<String, dynamic>> getEditorSettings() async {
    // 默认设置可以定义为常量
    const defaultSettings = {
      'fontSize': 16.0,
      'lineHeight': 1.5,
      'fontFamily': 'Roboto', // 考虑使用更通用的字体或从配置加载
      'theme': 'light',
      'autoSave': true,
    };

    // 先尝试从本地获取
    try {
      final localSettings = await _localStorageService.getEditorSettings();
      if (localSettings != null && localSettings.isNotEmpty) {
        // 合并本地设置和默认设置，以防本地缺少某些键
        return {...defaultSettings, ...localSettings};
      }
    } catch (e) {
       AppLogger.w(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '从本地获取编辑器设置失败',
          e);
    }

    if (AppConfig.shouldUseMockData) {
      return defaultSettings;
    }
    
    try {
      // 从服务器获取设置 (假设ApiClient有对应方法)
      // final data = await _apiClient.getEditorSettings(); 
      final data = await _apiClient.post('/editor/get-settings', data: {}); // 保持现有方式，如果ApiClient没有封装
      
      final serverSettings = Map<String, dynamic>.from(data);
      // 合并服务器设置和默认设置
      final mergedSettings = {...defaultSettings, ...serverSettings};
      
      // 保存到本地缓存
      await _localStorageService.saveEditorSettings(mergedSettings);
      
      return mergedSettings;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取编辑器设置从服务器失败，使用默认设置',
          e);
      // 即使API失败，也尝试返回本地设置（如果之前获取过）或默认设置
      final localSettings = await _localStorageService.getEditorSettings();
      return (localSettings != null && localSettings.isNotEmpty) 
             ? {...defaultSettings, ...localSettings} 
             : defaultSettings;
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
      
      // 保存到服务器 (假设ApiClient有对应方法)
      try {
        // await _apiClient.saveEditorSettings(settings);
        await _apiClient.post('/editor/save-settings', data: settings); // 保持现有方式
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '保存编辑器设置到服务器失败，但已保存到本地',
            e);
        // 考虑标记设置需要同步
        // await _localStorageService.markForSyncByType('editor_settings', 'settings'); 
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
