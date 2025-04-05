import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/date_time_parser.dart';
import 'package:ainoval/utils/logger.dart';
import 'dart:convert';

/// 编辑器仓库实现
class EditorRepositoryImpl implements EditorRepository {
  EditorRepositoryImpl({
    ApiClient? apiClient,
    LocalStorageService? localStorageService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _localStorageService = localStorageService ?? LocalStorageService();

  final ApiClient _apiClient;
  final LocalStorageService _localStorageService;

  /// 获取本地存储服务
  LocalStorageService getLocalStorageService() {
    return _localStorageService;
  }

  /// 获取API客户端
  ApiClient getApiClient() {
    return _apiClient;
  }

  /// 获取编辑器内容
  @override
  Future<EditorContent> getEditorContent(
      String novelId, String chapterId, String sceneId) async {
    try {
      final data =
          await _apiClient.getEditorContent(novelId, chapterId, sceneId);
      return EditorContent.fromJson(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取编辑器内容失败，返回空内容',
          e);
      return EditorContent(
        id: '$novelId-$chapterId-$sceneId',
        content: '{"ops":[{"insert":"\\n"}]}',
        lastSaved: DateTime.now(),
        scenes: const {},
      );
    }
  }

  /// 保存编辑器内容
  @override
  Future<void> saveEditorContent(EditorContent content) async {
    try {
      final parts = content.id.split('-');
      if (parts.length < 2) {
        throw ApiException(-1, '无效的内容ID格式');
      }

      final novelId = parts[0];
      final chapterId = parts[1];

      // 先保存到本地
      await _localStorageService.saveEditorContent(content);
      AppLogger.i('EditorRepositoryImpl/saveEditorContent',
          '编辑器内容已保存到本地: ${content.id}');
      
      // 检查是否为当前小说
      final currentNovelId = await _localStorageService.getCurrentNovelId();
      if (currentNovelId == novelId) {
        // 标记为需要同步
        final syncKey = '${novelId}_$chapterId';
        await _localStorageService.markForSyncByType(syncKey, 'editor');
        AppLogger.i('EditorRepositoryImpl/saveEditorContent',
            '编辑器内容标记为待同步: $syncKey');

        try {
          // 上传到服务器
          await _apiClient.saveEditorContent(novelId, chapterId, content.toJson());
          AppLogger.i('EditorRepositoryImpl/saveEditorContent',
              '编辑器内容已同步到服务器: ${content.id}');

          // 清除同步标记
          await _localStorageService.clearSyncFlagByType('editor', syncKey);
          AppLogger.i('EditorRepositoryImpl/saveEditorContent',
              '编辑器内容同步标记已清除: $syncKey');
        } catch (e) {
          AppLogger.e(
              'Services/api_service/repositories/impl/editor_repository_impl',
              '保存编辑器内容到服务器失败，但已保存到本地',
              e);
        }
      } else {
        AppLogger.i(
            'EditorRepositoryImpl/saveEditorContent', 
            '编辑器内容不属于当前编辑的小说，跳过同步: ${content.id}, 当前小说ID: $currentNovelId');
      }
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
  Novel _convertBackendNovelWithScenesToFrontend(
      Map<String, dynamic> backendData) {
    try {
      // 提取小说基本信息
      final backendNovel = backendData['novel'];

      // 提取所有场景数据，按章节ID分组
      final Map<String, List<dynamic>> scenesByChapter =
          backendData['scenesByChapter'] != null
              ? Map<String, List<dynamic>>.from(backendData['scenesByChapter'])
              : {};

      // 提取作者信息
      Author? author;
      if (backendNovel.containsKey('author') &&
          backendNovel['author'] != null) {
        final authorData = backendNovel['author'];
        if (!authorData.containsKey('username') || authorData['username'] == null){
           authorData['username']='unknown';
        }
        if (authorData.containsKey('id') && authorData['id'] != null) {
          author = Author(
            id: authorData['id'],
            username: authorData['username'] ?? 'unknown',
          );
        }
      }

      // 提取Acts和Chapters
      List<Act> acts = [];
      if (backendNovel.containsKey('structure') &&
          backendNovel['structure'] is Map &&
          (backendNovel['structure'] as Map).containsKey('acts')) {
        acts =
            ((backendNovel['structure'] as Map)['acts'] as List).map((actData) {
          // 转换章节
          List<Chapter> chapters = [];
          if (actData.containsKey('chapters') && actData['chapters'] is List) {
            chapters = (actData['chapters'] as List).map((chapterData) {
              final chapterId = chapterData['id'];
              // 从scenesByChapter获取该章节的所有场景
              List<Scene> scenes = [];

              // 检查是否有该章节的场景数据
              if (scenesByChapter.containsKey(chapterId) &&
                  scenesByChapter[chapterId] is List) {
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
    } catch (e) {
      AppLogger.e('_convertBackendNovelWithScenesToFrontend',
          '转换后端NovelWithScenesDto模型为前端Novel模型失败', e);
      rethrow;
    }
  }

  /// 获取小说详情
  @override
  Future<Novel?> getNovel(String novelId) async {
    try {
      final localNovel = await _localStorageService.getNovel(novelId);
      if (localNovel != null) {
        AppLogger.i('EditorRepositoryImpl/getNovel', '从本地存储加载小说: $novelId');
        return localNovel;
      }

      AppLogger.i(
          'EditorRepositoryImpl/getNovel', '本地未找到小说，尝试从API获取: $novelId');
      try {
        final data = await _apiClient.getNovelDetailById(novelId);

        final novel = _convertBackendNovelWithScenesToFrontend(data);

        await _localStorageService.saveNovel(novel);
        AppLogger.i(
            'EditorRepositoryImpl/getNovel', '从API获取小说成功并保存到本地: $novelId');

        return novel;
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl/getNovel',
            '从API获取小说失败，本地也无缓存',
            e);
        return null;
      }
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl/getNovel',
          '获取小说时发生未知错误',
          e);
      return null;
    }
  }

  /// 获取小说详情（分页加载场景）
  /// 基于上次编辑章节为中心，获取前后指定数量的章节及其场景内容
  @override
  Future<Novel?> getNovelWithPaginatedScenes(String novelId, String lastEditedChapterId, {int chaptersLimit = 5}) async {
    try {
      AppLogger.i(
          'EditorRepositoryImpl/getNovelWithPaginatedScenes', 
          '从API获取小说(分页): novelId=$novelId, lastChapter=$lastEditedChapterId, limit=$chaptersLimit');
      
      // 使用新的分页API获取数据
      final data = await _apiClient.getNovelWithPaginatedScenes(
        novelId, 
        lastEditedChapterId,
        chaptersLimit: chaptersLimit
      );

      // 转换数据格式
      final novel = _convertBackendNovelWithScenesToFrontend(data);
      
      // 将小说基本信息保存到本地（不包含场景内容）
      await _localStorageService.saveNovel(novel);
      
      // 将场景内容分别保存到本地
      for (final act in novel.acts) {
        for (final chapter in act.chapters) {
          for (final scene in chapter.scenes) {
            await _localStorageService.saveSceneContent(
              novelId, 
              act.id, 
              chapter.id, 
              scene.id, 
              scene
            );
          }
        }
      }
      
      AppLogger.i(
          'EditorRepositoryImpl/getNovelWithPaginatedScenes', 
          '从API获取小说(分页)成功: $novelId, 返回章节数: ${novel.acts.fold(0, (sum, act) => sum + act.chapters.length)}');
      return novel;
    } catch (e) {
      AppLogger.e(
          'EditorRepositoryImpl/getNovelWithPaginatedScenes',
          '从API获取小说(分页)失败',
          e);
          
      // 如果分页加载失败，尝试回退到本地存储
      try {
        final localNovel = await _localStorageService.getNovel(novelId);
        if (localNovel != null) {
          AppLogger.i('EditorRepositoryImpl/getNovelWithPaginatedScenes', 
              '分页加载失败，回退到本地存储小说: $novelId');
          return localNovel;
        }
      } catch (localError) {
        AppLogger.e(
            'EditorRepositoryImpl/getNovelWithPaginatedScenes',
            '本地存储回退也失败',
            localError);
      }
      return null;
    }
  }

  /// 加载更多章节场景
  /// 根据方向（向上或向下）加载更多章节的场景内容
  @override
  Future<Map<String, List<Scene>>> loadMoreScenes(String novelId, String fromChapterId, String direction, {int chaptersLimit = 5}) async {
    try {
      AppLogger.i(
          'EditorRepositoryImpl/loadMoreScenes', 
          '加载更多场景: novelId=$novelId, fromChapter=$fromChapterId, direction=$direction, limit=$chaptersLimit');
      
      // 调用API加载更多场景
      final data = await _apiClient.loadMoreScenes(
        novelId, 
        fromChapterId, 
        direction,
        chaptersLimit: chaptersLimit
      );
      
      // 转换数据格式 - data是Map<String, List<Map<String, dynamic>>>
      final Map<String, List<Scene>> result = {};
      
      if (data is Map) {
        data.forEach((chapterId, scenes) {
          if (scenes is List) {
            result[chapterId] = scenes
                .map((sceneData) => _convertBackendSceneToFrontend(sceneData))
                .toList();
                
            // 对每个场景保存到本地存储
            // 注意：这里我们需要知道actId，但API可能没有返回，需要从之前的数据中查找
            _saveScenesToLocalStorage(novelId, chapterId, result[chapterId]!);
          }
        });
      }
      
      AppLogger.i(
          'EditorRepositoryImpl/loadMoreScenes', 
          '加载更多场景成功: $novelId, 返回章节数: ${result.length}');
      return result;
    } catch (e) {
      AppLogger.e(
          'EditorRepositoryImpl/loadMoreScenes',
          '加载更多场景失败',
          e);
      // 返回空映射表示加载失败
      return {};
    }
  }
  
  /// 辅助方法：将场景保存到本地存储
  Future<void> _saveScenesToLocalStorage(String novelId, String chapterId, List<Scene> scenes) async {
    try {
      // 获取当前小说结构以找到正确的actId
      final novel = await _localStorageService.getNovel(novelId);
      if (novel == null) {
        AppLogger.w('EditorRepositoryImpl/_saveScenesToLocalStorage', 
            '无法保存场景到本地，小说结构不存在: $novelId');
        return;
      }
      
      // 查找chapter对应的act
      String? actId;
      for (final act in novel.acts) {
        for (final chapter in act.chapters) {
          if (chapter.id == chapterId) {
            actId = act.id;
            break;
          }
        }
        if (actId != null) break;
      }
      
      if (actId == null) {
        AppLogger.w('EditorRepositoryImpl/_saveScenesToLocalStorage', 
            '无法保存场景到本地，找不到章节对应的act: $chapterId');
        return;
      }
      
      // 保存每个场景
      for (final scene in scenes) {
        await _localStorageService.saveSceneContent(
          novelId, 
          actId, 
          chapterId, 
          scene.id, 
          scene
        );
        AppLogger.v('EditorRepositoryImpl/_saveScenesToLocalStorage', 
            '场景保存到本地: ${scene.id}');
      }
      
      AppLogger.i('EditorRepositoryImpl/_saveScenesToLocalStorage', 
          '成功保存 ${scenes.length} 个场景到本地，章节: $chapterId');
    } catch (e) {
      AppLogger.e(
          'EditorRepositoryImpl/_saveScenesToLocalStorage',
          '保存场景到本地失败',
          e);
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
      'author': novel.author?.toJson() ??
          {
            'id': AppConfig.userId ?? 'unknown',
            'username': AppConfig.username ?? 'user',
          },
      'structure': {
        'acts': novel.acts
            .map((act) => {
                  'id': act.id,
                  'title': act.title,
                  'order': act.order,
                  'chapters': act.chapters
                      .map((chapter) => {
                            'id': chapter.id,
                            'title': chapter.title,
                            'order': chapter.order,
                            'sceneIds': chapter.scenes
                                .map((scene) => scene.id)
                                .toList(),
                          })
                      .toList(),
                })
            .toList(),
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
    bool localSaveSuccess = false;
    try {
      await _localStorageService.saveNovel(novel);
      localSaveSuccess = true;
      AppLogger.i('EditorRepositoryImpl/saveNovel', '小说已保存到本地: ${novel.id}');

      // 检查是否为当前小说，只同步当前小说
      final currentNovelId = await _localStorageService.getCurrentNovelId();
      if (currentNovelId == novel.id) {
        await _localStorageService.markForSyncByType(novel.id, 'novel');
        AppLogger.i('EditorRepositoryImpl/saveNovel', '小说标记为待同步: ${novel.id}');
      } else {
        AppLogger.i('EditorRepositoryImpl/saveNovel', '小说不是当前编辑的小说，跳过同步标记: ${novel.id}, 当前小说ID: $currentNovelId');
      }

      try {
        // 只有当前小说才实时同步到服务器
        if (currentNovelId == novel.id) {
          final Map<String, dynamic> backendNovelJson =
              _convertFrontendNovelToBackendJson(novel);
          Map<String, List<Map<String, dynamic>>> scenesByChapter = {};
          for (final act in novel.acts) {
            for (final chapter in act.chapters) {
              if (chapter.scenes.isNotEmpty) {
                scenesByChapter[chapter.id] = chapter.scenes
                    .map((scene) => _convertFrontendSceneToBackendJson(
                        scene, novel.id, chapter.id))
                    .toList();
              }
            }
          }
          final novelWithScenesJson = {
            'novel': backendNovelJson,
            'scenesByChapter': scenesByChapter,
          };

          await _apiClient.updateNovelWithScenes(novelWithScenesJson);
          AppLogger.i('EditorRepositoryImpl/saveNovel', '小说已同步到服务器: ${novel.id}');
        }

        return true;
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '保存小说到服务器失败，但已保存到本地',
            e);
        return true;
      }
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '保存小说到本地存储失败',
          e);
      return false;
    }
  }

  /// 将前端Scene模型转换为后端API所需的JSON格式 (用于upsert)
  Map<String, dynamic> _convertFrontendSceneToBackendJson(
      Scene scene, String novelId, String chapterId) {
    return {
      'id': scene.id,
      'novelId': novelId,
      'chapterId': chapterId,
      'content': scene.content,
      'summary': scene.summary.content,
      'updatedAt': scene.lastEdited.toIso8601String(),
      'version': scene.version,
      'title': '',
      'sequence': 0,
      'sceneType': 'NORMAL',
      'history': scene.history
          .map((entry) => {
                'content': entry.content,
                'updatedAt': entry.updatedAt.toIso8601String(),
                'updatedBy': entry.updatedBy,
                'reason': entry.reason,
              })
          .toList(),
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
    if (backendScene.containsKey('history') &&
        backendScene['history'] is List) {
      history = (backendScene['history'] as List)
          .map((historyEntryData) {
            // 使用新的工具函数解析 updatedAt
            final DateTime entryUpdatedAt =
                parseBackendDateTime(historyEntryData['updatedAt']);

            return HistoryEntry(
              content: historyEntryData['content']?.toString() ?? '',
              updatedAt: entryUpdatedAt,
              updatedBy: historyEntryData['updatedBy']?.toString() ?? 'unknown',
              reason: historyEntryData['reason']?.toString() ?? '',
            );
          })
          .whereType<HistoryEntry>()
          .toList();
    }

    // 使用新的工具函数解析 Scene 的 lastEdited
    final DateTime lastEdited = parseBackendDateTime(backendScene['updatedAt']);

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
    final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
    try {
      final localScene = await _localStorageService.getSceneContent(
          novelId, actId, chapterId, sceneId);

      if (localScene != null) {
        AppLogger.i(
            'EditorRepositoryImpl/getSceneContent', '从本地存储加载场景: $sceneKey');
        return localScene;
      }

      AppLogger.i('EditorRepositoryImpl/getSceneContent',
          '本地未找到场景，尝试从API获取: $sceneKey');
      final data = await _apiClient.getSceneById(novelId, chapterId, sceneId);

      final scene = _convertBackendSceneToFrontend(data);

      await _localStorageService.saveSceneContent(
          novelId, actId, chapterId, sceneId, scene);
      AppLogger.i('EditorRepositoryImpl/getSceneContent',
          '从API获取场景成功并保存到本地: $sceneKey');

      return scene;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取场景内容失败，本地也无缓存',
          e);
      if (e is ApiException && e.statusCode == 404) {
        AppLogger.w('EditorRepositoryImpl/getSceneContent',
            '场景 $sceneKey 在服务器上未找到，返回默认空场景');
        return Scene.createDefault(sceneId);
      }
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
      // 将字数转换为整数
      int currentWordCount = int.tryParse(wordCount) ?? 0;

      // 构建唯一的场景键
      final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';

      // 获取当前场景内容
      Scene? scene = await getSceneContent(novelId, actId, chapterId, sceneId);

      if (scene == null) {
        throw ApiException(404, '场景不存在: $sceneKey');
      }

      // 更新场景数据
      final updatedScene = scene.copyWith(
        content: content,
        wordCount: currentWordCount,
        lastEdited: DateTime.now(),
        summary: summary, // 确保摘要也被更新
      );

      // 保存到本地存储
      await _localStorageService.saveSceneContent(
          novelId, actId, chapterId, sceneId, updatedScene);
      AppLogger.i(
          'EditorRepositoryImpl/saveSceneContent', '场景内容已保存到本地: $sceneKey');

      // 检查是否为当前小说，只同步当前小说
      final currentNovelId = await _localStorageService.getCurrentNovelId();
      if (currentNovelId == novelId) {
        // 标记为需要同步
        await _localStorageService.markForSyncByType(sceneKey, 'scene');
        AppLogger.i(
            'EditorRepositoryImpl/saveSceneContent', '场景标记为待同步: $sceneKey');

        try {
          final Map<String, dynamic> backendSceneJson =
              _convertFrontendSceneToBackendJson(
                  updatedScene, novelId, chapterId);

          // 同步到服务器
          await _apiClient.updateScene(backendSceneJson);
          AppLogger.i(
              'EditorRepositoryImpl/saveSceneContent', '场景已同步到服务器: $sceneKey');

          // 清除该场景的同步标记，表示已完成同步
          await _localStorageService.clearSyncFlagByType('scene', sceneKey);
          AppLogger.i(
              'EditorRepositoryImpl/saveSceneContent', '场景同步标记已清除: $sceneKey');
        } catch (e) {
          AppLogger.e(
              'Services/api_service/repositories/impl/editor_repository_impl/saveSceneContent',
              '保存场景内容到服务器失败，但已保存到本地',
              e);
        }
        
        // 仅当场景属于当前小说时才更新小说字数统计
        // 更新小说缓存中的字数统计
        await _updateNovelWordCount(
            novelId, actId, chapterId, sceneId, currentWordCount);
        
        // 添加额外的日志记录，帮助调试字数更新
        AppLogger.i('EditorRepositoryImpl/saveSceneContent',
            '保存完成 - 当前场景字数为: $currentWordCount, 场景ID: $sceneId');
      } else {
        AppLogger.i(
            'EditorRepositoryImpl/saveSceneContent', 
            '场景不属于当前编辑的小说，跳过同步和字数统计更新: $sceneKey, 当前小说ID: $currentNovelId');
      }

      // 确保已更新的Scene被返回
      return updatedScene;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl/saveSceneContent',
          '保存场景内容到本地存储失败',
          e);
      throw ApiException(-1, '保存场景内容失败: $e');
    }
  }

  // 更新小说中特定场景的字数统计
  Future<void> _updateNovelWordCount(String novelId, String actId,
      String chapterId, String sceneId, int wordCount) async {
    try {
      final novel = await getNovel(novelId);
      if (novel == null) {
        AppLogger.w('EditorRepositoryImpl/_updateNovelWordCount',
            '无法找到小说以更新字数统计: $novelId');
        return;
      }

      // 遍历小说结构并更新对应场景的字数
      final updatedActs = novel.acts.map((act) {
        if (act.id == actId) {
          final updatedChapters = act.chapters.map((chapter) {
            if (chapter.id == chapterId) {
              final updatedScenes = chapter.scenes.map((scene) {
                if (scene.id == sceneId) {
                  // 更新当前场景的字数
                  return scene.copyWith(wordCount: wordCount);
                }
                return scene;
              }).toList();
              return chapter.copyWith(scenes: updatedScenes);
            }
            return chapter;
          }).toList();
          return act.copyWith(chapters: updatedChapters);
        }
        return act;
      }).toList();

      // 创建更新后的小说对象
      final updatedNovel = novel.copyWith(
        acts: updatedActs,
        updatedAt: DateTime.now(),
      );

      // 直接保存到本地，不触发同步标记
      // 这是因为场景已经单独被标记为同步，不需要重复标记整本小说
      await _localStorageService.saveNovel(updatedNovel);
      
      // 检查当前小说ID，只记录日志，不触发同步
      final currentNovelId = await _localStorageService.getCurrentNovelId();
      if (currentNovelId == novelId) {
        AppLogger.i('EditorRepositoryImpl/_updateNovelWordCount',
            '已更新当前小说 $novelId 中场景 $sceneId 的字数统计为 $wordCount');
      } else {
        AppLogger.i('EditorRepositoryImpl/_updateNovelWordCount',
            '已更新非当前小说 $novelId 中场景 $sceneId 的字数统计为 $wordCount (当前小说: $currentNovelId)，不触发同步');
      }
    } catch (e, stackTrace) {
      AppLogger.e('EditorRepositoryImpl/_updateNovelWordCount', '更新小说字数统计失败', e,
          stackTrace);
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
    final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
    Scene? scene;
    try {
      scene = await getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene == null) {
        AppLogger.e(
            'EditorRepositoryImpl/saveSummary', '尝试为不存在的场景保存摘要: $sceneKey');
        throw ApiException(404, '无法为不存在的场景保存摘要: $sceneId');
      }

      final updatedSummary = scene.summary.copyWith(
        content: content,
      );

      final updatedScene = scene.copyWith(
        summary: updatedSummary,
        lastEdited: DateTime.now(),
      );

      // 直接保存到本地，不触发同步
      await _localStorageService.saveSceneContent(
          novelId, actId, chapterId, sceneId, updatedScene);
      AppLogger.i(
          'EditorRepositoryImpl/saveSummary', '场景摘要已更新并保存到本地: $sceneKey');

      // 检查是否为当前小说，只同步当前小说
      final currentNovelId = await _localStorageService.getCurrentNovelId();
      if (currentNovelId == novelId) {
        await _localStorageService.markForSyncByType(sceneKey, 'scene');
        AppLogger.i(
            'EditorRepositoryImpl/saveSummary', '场景标记为待同步 (摘要更新): $sceneKey');

        try {
          final Map<String, dynamic> backendSceneJson =
              _convertFrontendSceneToBackendJson(
                  updatedScene, novelId, chapterId);

          await _apiClient.updateScene(backendSceneJson);
          AppLogger.i(
              'EditorRepositoryImpl/saveSummary', '场景摘要更新已同步到服务器: $sceneKey');
          
          // 清除该场景的同步标记，表示已完成同步
          await _localStorageService.clearSyncFlagByType('scene', sceneKey);
          AppLogger.i(
              'EditorRepositoryImpl/saveSummary', '场景同步标记已清除: $sceneKey');
        } catch (e) {
          AppLogger.e(
              'Services/api_service/repositories/impl/editor_repository_impl/saveSummary',
              '保存摘要到服务器失败(通过更新场景)，但已保存到本地',
              e);
        }
        
        // 如果未来需要更新字数统计，应该放在这里
        
      } else {
        AppLogger.i(
            'EditorRepositoryImpl/saveSummary', 
            '场景不属于当前编辑的小说，跳过同步: $sceneKey, 当前小说ID: $currentNovelId');
      }

      return updatedSummary;
    } catch (e, stackTrace) {
      AppLogger.e('EditorRepositoryImpl/saveSummary',
          '保存场景摘要失败: $sceneKey', e, stackTrace);
      if (scene != null) {
        return scene.summary;
      }
      throw ApiException(-1, '保存场景摘要失败: $e');
    }
  }

  /// 获取编辑器设置
  @override
  Future<Map<String, dynamic>> getEditorSettings() async {
    const defaultSettings = {
      'fontSize': 16.0,
      'lineHeight': 1.5,
      'fontFamily': 'SystemDefault',
      'theme': 'light',
      'autoSave': true,
      'autoSaveInterval': 30,
      'spellCheck': false,
    };

    Map<String, dynamic>? localSettings;
    try {
      localSettings = await _localStorageService.getEditorSettings();
      if (localSettings.isNotEmpty) {
        AppLogger.i('EditorRepositoryImpl/getEditorSettings', '从本地加载编辑器设置');
        return {...defaultSettings, ...localSettings};
      }
    } catch (e) {
      AppLogger.w(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '从本地获取编辑器设置失败',
          e);
    }

    AppLogger.i('EditorRepositoryImpl/getEditorSettings', '本地无设置，尝试从API获取');
    try {
      //final data = await _apiClient.getEditorSettings();
      const data = null;

      final serverSettings = Map<String, dynamic>.from(data);
      final mergedSettings = {...defaultSettings, ...serverSettings};

      await _localStorageService.saveEditorSettings(mergedSettings);
      AppLogger.i('EditorRepositoryImpl/getEditorSettings', '从API获取设置成功并保存到本地');

      return mergedSettings;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '从API获取编辑器设置失败，使用默认设置',
          e);
      try {
        await _localStorageService.saveEditorSettings(defaultSettings);
      } catch (localSaveError) {
        AppLogger.e('EditorRepositoryImpl/getEditorSettings', '保存默认设置到本地也失败了',
            localSaveError);
      }
      return defaultSettings;
    }
  }

  /// 保存编辑器设置
  @override
  Future<void> saveEditorSettings(Map<String, dynamic> settings) async {
    try {
      await _localStorageService.saveEditorSettings(settings);
      AppLogger.i('EditorRepositoryImpl/saveEditorSettings', '编辑器设置已保存到本地');

      try {
        //await _apiClient.saveEditorSettings(settings);
        AppLogger.i('EditorRepositoryImpl/saveEditorSettings', '编辑器设置已同步到服务器');
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '保存编辑器设置到服务器失败，但已保存到本地',
            e);
      }
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '保存编辑器设置到本地失败',
          e);
      throw ApiException(-1, '保存编辑器设置失败: $e');
    }
  }

  /// 获取小说数据（包含场景摘要，适用于Plan视图）
  @override
  Future<Novel?> getNovelWithSceneSummaries(String novelId) async {
    try {
      // 使用专门的API端点获取场景摘要
      final data = await _apiClient.getNovelWithSceneSummaries(novelId);
      
      if (data == null) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '获取小说(带场景摘要)失败: 返回null');
        return null;
      }
      
      // 转换后端数据为前端模型
      return _convertBackendNovelWithSummariesToFrontend(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '获取小说(带场景摘要)失败',
          e);
      return null;
    }
  }
  
  /// 移动场景（用于Plan视图的拖拽功能）
  Future<Novel?> moveScene(
    String novelId,
    String sourceActId,
    String sourceChapterId,
    String sourceSceneId,
    String targetActId,
    String targetChapterId,
    int targetIndex,
  ) async {
    try {
      // 调用API移动场景
      final data = await _apiClient.moveScene(
        novelId,
        sourceActId,
        sourceChapterId,
        sourceSceneId,
        targetActId,
        targetChapterId,
        targetIndex,
      );
      
      if (data == null) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl',
            '移动场景失败: 返回null');
        return null;
      }
      
      // 转换后端数据为前端模型
      return _convertBackendNovelWithScenesToFrontend(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/editor_repository_impl',
          '移动场景失败',
          e);
      return null;
    }
  }

  /// 更新Act标题
  Future<void> updateActTitle(
    String novelId,
    String actId,
    String title,
  ) async {
    try {
      final data = {
        'novelId': novelId,
        'actId': actId,
        'title': title,
      };
      
      await _apiClient.post('/novels/update-act-title', data: data);
    } catch (e) {
      AppLogger.e('EditorRepositoryImpl', '更新Act标题失败', e);
      throw ApiException(-1, '更新Act标题失败: $e');
    }
  }

  /// 更新Chapter标题
  Future<void> updateChapterTitle(
    String novelId,
    String actId,
    String chapterId,
    String title,
  ) async {
    try {
      final data = {
        'novelId': novelId,
        'actId': actId,
        'chapterId': chapterId,
        'title': title,
      };
      
      await _apiClient.post('/novels/update-chapter-title', data: data);
    } catch (e) {
      AppLogger.e('EditorRepositoryImpl', '更新Chapter标题失败', e);
      throw ApiException(-1, '更新Chapter标题失败: $e');
    }
  }

  /// 更新场景摘要
  Future<void> updateSummary(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
    String summary,
  ) async {
    try {
      final data = {
        'novelId': novelId,
        'actId': actId,
        'chapterId': chapterId,
        'sceneId': sceneId,
        'summary': summary,
      };
      
      await _apiClient.post('/novels/update-scene-summary', data: data);
    } catch (e) {
      AppLogger.e('EditorRepositoryImpl', '更新场景摘要失败', e);
      throw ApiException(-1, '更新场景摘要失败: $e');
    }
  }

  /// 添加新Act
  Future<Novel?> addNewAct(String novelId, String title) async {
    try {
      final data = {
        'novelId': novelId,
        'title': title,
      };
      
      final response = await _apiClient.post('/novels/add-act', data: data);
      if (response != null) {
        return _convertBackendNovelWithScenesToFrontend(response);
      }
      return null;
    } catch (e) {
      AppLogger.e('EditorRepositoryImpl', '添加新Act失败', e);
      throw ApiException(-1, '添加新Act失败: $e');
    }
  }

  /// 添加新Chapter
  Future<Novel?> addNewChapter(
    String novelId,
    String actId,
    String title,
  ) async {
    try {
      final data = {
        'novelId': novelId,
        'actId': actId,
        'title': title,
      };
      
      final response = await _apiClient.post('/novels/add-chapter', data: data);
      if (response != null) {
        return _convertBackendNovelWithScenesToFrontend(response);
      }
      return null;
    } catch (e) {
      AppLogger.e('EditorRepositoryImpl', '添加新Chapter失败', e);
      throw ApiException(-1, '添加新Chapter失败: $e');
    }
  }

  /// 添加新Scene
  Future<Novel?> addNewScene(
    String novelId,
    String actId,
    String chapterId,
  ) async {
    try {
      final data = {
        'novelId': novelId,
        'actId': actId,
        'chapterId': chapterId,
      };
      
      final response = await _apiClient.post('/novels/add-scene', data: data);
      if (response != null) {
        return _convertBackendNovelWithScenesToFrontend(response);
      }
      return null;
    } catch (e) {
      AppLogger.e('EditorRepositoryImpl', '添加新Scene失败', e);
      throw ApiException(-1, '添加新Scene失败: $e');
    }
  }

  /// 删除场景
  Future<Novel?> deleteScene(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
  ) async {
    try {
      final data = {
        'novelId': novelId,
        'actId': actId,
        'chapterId': chapterId,
        'sceneId': sceneId,
      };
      
      final response = await _apiClient.post('/novels/delete-scene', data: data);
      if (response != null) {
        return _convertBackendNovelWithScenesToFrontend(response);
      }
      return null;
    } catch (e) {
      AppLogger.e('EditorRepositoryImpl', '删除场景失败', e);
      throw ApiException(-1, '删除场景失败: $e');
    }
  }

  /// 将后端返回的带场景摘要的小说数据转换为前端模型
  Novel _convertBackendNovelWithSummariesToFrontend(
      Map<String, dynamic> backendData) {
    try {
      // 提取小说基本信息
      final backendNovel = backendData['novel'];

      // 提取所有场景摘要数据，按章节ID分组
      final Map<String, List<dynamic>> summariesByChapter =
          backendData['sceneSummariesByChapter'] != null
              ? Map<String, List<dynamic>>.from(backendData['sceneSummariesByChapter'])
              : {};

      // 提取作者信息
      Author? author;
      if (backendNovel.containsKey('author') &&
          backendNovel['author'] != null) {
        final authorData = backendNovel['author'];
        if (!authorData.containsKey('username') || authorData['username'] == null){
           authorData['username']='unknown';
        }
        if (authorData.containsKey('id') && authorData['id'] != null) {
          author = Author(
            id: authorData['id'],
            username: authorData['username'] ?? 'unknown',
          );
        }
      }

      // 提取Acts和Chapters
      List<Act> acts = [];
      if (backendNovel.containsKey('structure') &&
          backendNovel['structure'] is Map &&
          (backendNovel['structure'] as Map).containsKey('acts')) {
        acts =
            ((backendNovel['structure'] as Map)['acts'] as List).map((actData) {
          // 转换章节
          List<Chapter> chapters = [];
          if (actData.containsKey('chapters') && actData['chapters'] is List) {
            chapters = (actData['chapters'] as List).map((chapterData) {
              final chapterId = chapterData['id'];
              // 从summariesByChapter获取该章节的所有场景摘要
              List<Scene> scenes = [];

              // 检查是否有该章节的场景摘要数据
              if (summariesByChapter.containsKey(chapterId) &&
                  summariesByChapter[chapterId] is List) {
                scenes = (summariesByChapter[chapterId] as List).map((summaryData) {
                  // 将摘要数据转换为Scene对象，但不包含完整内容
                  return Scene(
                    id: summaryData['id'],
                    content: '', // 不包含完整内容
                    wordCount: summaryData['wordCount'] ?? 0,
                    summary: Summary(
                      id: '${summaryData['id']}_summary',
                      content: summaryData['summary'] ?? '',
                    ),
                    lastEdited: parseBackendDateTime(summaryData['updatedAt']),
                    version: 1,
                    history: [],
                  );
                }).toList();
                
                // 按序列号排序
                scenes.sort((a, b) {
                  final seqA = (summariesByChapter[chapterId] as List)
                      .firstWhere((s) => s['id'] == a.id)['sequence'] ?? 0;
                  final seqB = (summariesByChapter[chapterId] as List)
                      .firstWhere((s) => s['id'] == b.id)['sequence'] ?? 0;
                  return seqA.compareTo(seqB);
                });
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
    } catch (e) {
      AppLogger.e('_convertBackendNovelWithSummariesToFrontend',
          '转换后端NovelWithSummariesDto模型为前端Novel模型失败', e);
      rethrow;
    }
  }
}
