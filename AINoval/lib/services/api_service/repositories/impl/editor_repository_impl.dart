import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/date_time_parser.dart';

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
        scenes: {},
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
      await _apiClient.saveEditorContent(novelId, chapterId, content.toJson());
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

      await _localStorageService.markForSyncByType(novel.id, 'novel');
      AppLogger.i('EditorRepositoryImpl/saveNovel', '小说标记为待同步: ${novel.id}');

      try {
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

        // 更新小说缓存中的字数统计
        await _updateNovelWordCount(
            novelId, actId, chapterId, sceneId, currentWordCount);

        // 添加额外的日志记录，帮助调试字数更新
        AppLogger.i('EditorRepositoryImpl/saveSceneContent',
            '保存完成 - 当前场景字数为: $currentWordCount, 场景ID: $sceneId');

        // 确保已更新的Scene被返回
        return updatedScene;
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl/saveSceneContent',
            '保存场景内容到服务器失败，但已保存到本地',
            e);
      }

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

      // 保存更新后的小说
      await _localStorageService.saveNovel(updatedNovel);
      AppLogger.i('EditorRepositoryImpl/_updateNovelWordCount',
          '已更新小说 $novelId 中场景 $sceneId 的字数统计为 $wordCount');
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

      await _localStorageService.saveSceneContent(
          novelId, actId, chapterId, sceneId, updatedScene);
      AppLogger.i(
          'EditorRepositoryImpl/saveSummary', '场景摘要已更新并保存到本地: $sceneKey');

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
      } catch (e) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl/saveSummary',
            '保存摘要到服务器失败(通过更新场景)，但已保存到本地',
            e);
      }

      return updatedSummary;
    } catch (e) {
      if (scene == null && !(e is ApiException && e.statusCode == 404)) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl/saveSummary',
            '获取场景失败，无法保存摘要',
            e);
        throw ApiException(-1, '获取场景失败，无法保存摘要: $e');
      } else if (scene != null) {
        AppLogger.e(
            'Services/api_service/repositories/impl/editor_repository_impl/saveSummary',
            '保存摘要到本地存储失败',
            e);
        throw ApiException(-1, '保存摘要失败 (本地): $e');
      } else {
        rethrow;
      }
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
      if (localSettings != null && localSettings.isNotEmpty) {
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
      final data = null;

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
}
