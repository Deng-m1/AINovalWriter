import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/import_status.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/scene_version.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/base/sse_client.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';
import 'package:ainoval/utils/date_time_parser.dart';
import 'package:ainoval/utils/logger.dart';

/// 小说仓库实现
class NovelRepositoryImpl implements NovelRepository {
  /// 工厂构造函数
  factory NovelRepositoryImpl() {
    return _instance;
  }

  /// 内部构造函数
  NovelRepositoryImpl._internal({
    ApiClient? apiClient,
    SseClient? sseClient,
  })  : _apiClient = apiClient ?? ApiClient(),
        _sseClient = sseClient ?? SseClient();

  /// 创建NovelRepositoryImpl单例
  static final NovelRepositoryImpl _instance = NovelRepositoryImpl._internal();
  final ApiClient _apiClient;
  final SseClient _sseClient;

  /// 获取当前用户ID
  String? get _currentUserId => AppConfig.userId;
  /// 获取当前认证 Token
  String? get _authToken => AppConfig.authToken;

  /// 工厂方法获取单例
  static NovelRepositoryImpl getInstance() {
    return _instance;
  }

  /// 获取所有小说
  @override
  Future<List<Novel>> fetchNovels() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw ApiException(401, '未登录或用户ID不可用');
      }

      final data = await _apiClient.getNovelsByAuthor(userId);
      return _convertToNovelList(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '获取小说列表失败',
          e);
      rethrow;
    }
  }

  /// 获取单个小说
  @override
  Future<Novel> fetchNovel(String id) async {
    try {
      final data = await _apiClient.getNovelDetailById(id);
      final novel = _convertToSingleNovel(data);

      if (novel == null) {
        throw ApiException(404, '小说不存在或数据格式不正确');
      }

      return novel;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '获取小说详情失败',
          e);
      rethrow;
    }
  }

  /// 创建小说
  @override
  Future<Novel> createNovel(String title,
      {String? description, String? coverImage}) async {
    try {
      // 获取当前用户ID
      final userId = _currentUserId;
      if (userId == null) {
        throw ApiException(401, '未登录或用户ID不可用');
      }

      // 准备请求体
      final body = {
        'title': title,
        'description': description ?? '',
        'coverImage': coverImage,
        'author': {'id': userId, 'username': AppConfig.username ?? 'user'},
        'status': 'draft',
        'structure': {'acts': []},
        'metadata': {'wordCount': 0, 'readTime': 0, 'version': 1}
      };

      // 发送创建请求
      final data = await _apiClient.createNovel(body);
      final novel = _convertToSingleNovel(data);

      if (novel == null) {
        throw ApiException(-1, '创建小说失败：服务器返回的数据格式不正确');
      }

      return novel;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '创建小说失败',
          e);
      throw ApiException(-1, '创建小说失败: $e');
    }
  }

  /// 根据作者ID获取小说列表
  @override
  Future<List<Novel>> fetchNovelsByAuthor(String authorId) async {
    try {
      final data = await _apiClient.getNovelsByAuthor(authorId);
      return _convertToNovelList(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '获取作者小说列表失败',
          e);
      rethrow;
    }
  }

  /// 搜索小说
  @override
  Future<List<Novel>> searchNovelsByTitle(String title) async {
    try {
      final data = await _apiClient.searchNovelsByTitle(title);
      return _convertToNovelList(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '搜索小说失败',
          e);
      rethrow;
    }
  }


  /// 删除小说
  @override
  Future<void> deleteNovel(String id) async {
    try {
      await _apiClient.deleteNovel(id);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '删除小说失败',
          e);
      throw ApiException(-1, '删除小说失败: $e');
    }
  }

  /// 获取场景内容
  @override
  Future<Scene> fetchSceneContent(
      String novelId, String actId, String chapterId, String sceneId) async {
    try {
      final data = await _apiClient.getSceneById(novelId, chapterId, sceneId);
      return _convertToSceneModel(data);
    } catch (e) {
      // 如果获取失败，特别是404，可能场景尚未创建，返回一个空场景
      if (e is ApiException && e.statusCode == 404) {
        AppLogger.w(
            'Services/api_service/repositories/impl/novel_repository_impl',
            '场景 $sceneId 未找到，返回空场景');
        return Scene.createDefault(sceneId);
      }
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '获取场景内容失败',
          e);
      rethrow;
    }
  }

  /// 更新场景内容并保存历史版本
  @override
  Future<Scene> updateSceneContentWithHistory(String novelId, String chapterId,
      String sceneId, String content, String userId, String reason) async {
    try {
      // 发送API请求
      final data = await _apiClient.updateSceneWithHistory(
          novelId, chapterId, sceneId, content, userId, reason);

      // 解析响应
      return Scene.fromJson(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '更新场景内容并保存历史版本失败',
          e);
      throw ApiException(500, '更新场景内容并保存历史版本失败: $e');
    }
  }

  /// 获取场景的历史版本列表
  @override
  Future<List<SceneHistoryEntry>> getSceneHistory(
      String novelId, String chapterId, String sceneId) async {
    try {
      // 发送API请求
      final data =
          await _apiClient.getSceneHistory(novelId, chapterId, sceneId);

      // 解析响应
      return (data as List).map((e) => SceneHistoryEntry.fromJson(e)).toList();
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '获取场景历史版本失败',
          e);
      throw ApiException(500, '获取场景历史版本失败: $e');
    }
  }

  /// 恢复场景到指定的历史版本
  @override
  Future<Scene> restoreSceneVersion(String novelId, String chapterId,
      String sceneId, int historyIndex, String userId, String reason) async {
    try {
      // 发送API请求
      // 注意：API 路径中的 historyIndex 可能需要调整为 versionId，这取决于后端实现
      // 假设后端接受 historyIndex
      final data = await _apiClient.restoreSceneVersion(
          novelId, chapterId, sceneId, historyIndex, userId, reason);

      // 解析响应
      return Scene.fromJson(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '恢复历史版本失败',
          e);
      throw ApiException(500, '恢复历史版本失败: $e');
    }
  }

  /// 对比两个场景版本
  @override
  Future<SceneVersionDiff> compareSceneVersions(
      String novelId,
      String chapterId,
      String sceneId,
      int versionIndex1,
      int versionIndex2) async {
    try {
      // 发送API请求
      // 注意：API 路径中的 versionIndex 可能需要调整为 versionId，这取决于后端实现
      // 假设后端接受 versionIndex
      final data = await _apiClient.compareSceneVersions(
          novelId, chapterId, sceneId, versionIndex1, versionIndex2);

      // 解析响应
      return SceneVersionDiff.fromJson(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '比较版本差异失败',
          e);
      throw ApiException(500, '比较版本差异失败: $e');
    }
  }

  /// 导入小说文件
  @override
  Future<String> importNovel(List<int> fileBytes, String fileName) async {
    try {
      return await _apiClient.importNovel(fileBytes, fileName);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '导入小说文件失败',
          e);
      rethrow;
    }
  }

  /// 获取导入任务状态流
  @override
  Stream<ImportStatus> getImportStatus(String jobId) {
    final String path = '/novels/import/$jobId/status';
    final String connectionId = 'import_$jobId';
    
    try {
      AppLogger.i(
          'Services/api_service/repositories/impl/novel_repository_impl',
          'Subscribing to SSE stream for job: $jobId at path: $path using SseClient');
      return _sseClient.streamEvents<ImportStatus>(
        path: path,
        parser: ImportStatus.fromJson,
        eventName: 'import-status',
        connectionId: connectionId,
      );
    } catch (e, stack) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '获取导入状态流失败 (同步)',
          e,
          stack);
      return Stream.error(
          e is ApiException ? e : ApiException(-1, '获取导入状态流失败: $e'), stack);
    }
  }

  /// 取消导入任务
  @override
  Future<bool> cancelImport(String jobId) async {
    final String connectionId = 'import_$jobId';
    
    try {
      AppLogger.i(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '取消导入任务 $jobId: 发送请求到服务器');
      
      // 首先，通过API向服务器发送取消请求
      final bool apiCanceled = await _apiClient.cancelImport(jobId);
      
      // 然后，尝试取消SSE连接
      final bool sseCanceled = await _sseClient.cancelConnection(connectionId);
      
      // 只要有一个成功就算成功
      final bool success = apiCanceled || sseCanceled;
      
      AppLogger.i(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '取消导入任务 $jobId: ${success ? '成功' : '失败或已完成'} (API: $apiCanceled, SSE: $sseCanceled)');
          
      return success;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '取消导入任务失败',
          e);
      return false;
    }
  }

  /// 将WebFlux响应转换为Novel列表
  List<Novel> _convertToNovelList(dynamic data) {
    final processedData = _handleFluxResponse(data);

    if (processedData == null) {
      return [];
    }

    if (processedData is List) {
      // 处理列表数据
      return processedData.map((item) {
        if (item is Map<String, dynamic>) {
          return _convertToNovelModel(item);
        } else {
          AppLogger.w(
              'Services/api_service/repositories/impl/novel_repository_impl',
              '警告：列表中的项目不是有效的小说数据: $item');
          // 返回一个错误占位小说对象
          final now = DateTime.now();
          return Novel(
            id: 'error_${now.millisecondsSinceEpoch}',
            title: '数据错误',
            createdAt: now,
            updatedAt: now,
            acts: [],
          );
        }
      }).toList();
    } else if (processedData is Map<String, dynamic>) {
      // 处理单个对象
      return [_convertToNovelModel(processedData)];
    }

    return [];
  }

  /// 将WebFlux响应转换为单个Novel
  Novel? _convertToSingleNovel(dynamic data) {
    final processedData = _handleFluxResponse(data);

    if (processedData == null) {
      return null;
    }

    if (processedData is List && processedData.isNotEmpty) {
      // 如果是列表，取第一个元素
      final firstItem = processedData.first;
      if (firstItem is Map<String, dynamic>) {
        return _convertToNovelModel(firstItem);
      }
    } else if (processedData is Map<String, dynamic>) {
      // 如果是单个对象，直接转换
      return _convertToNovelModel(processedData);
    }

    return null;
  }

  /// 将后端Novel模型转换为前端Novel模型
  Novel _convertToNovelModel(Map<String, dynamic> json) {
    // 检查是否为NovelWithScenesDto格式
    bool isNovelWithScenesDto =
        json.containsKey('novel') && json.containsKey('scenesByChapter');

    // 如果是NovelWithScenesDto格式，提取novel部分
    Map<String, dynamic> novelData =
        isNovelWithScenesDto ? json['novel'] as Map<String, dynamic> : json;
    Map<String, List<dynamic>>? scenesByChapter = isNovelWithScenesDto
        ? (json['scenesByChapter'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as List<dynamic>))
        : null;

    // 提取结构信息
    final structure = novelData['structure'] as Map<String, dynamic>? ?? {};
    final acts = (structure['acts'] as List?)?.map((actJson) {
          final act = actJson as Map<String, dynamic>;
          final chapters = (act['chapters'] as List?)?.map((chapterJson) {
                final chapter = chapterJson as Map<String, dynamic>;

                // 章节ID
                final chapterId = chapter['id'];

                // 如果是NovelWithScenesDto格式且有该章节的场景数据，添加场景
                List<Scene> scenes = [];
                if (isNovelWithScenesDto &&
                    scenesByChapter != null &&
                    scenesByChapter.containsKey(chapterId)) {
                  scenes = scenesByChapter[chapterId]!
                      .map((sceneJson) =>
                          Scene.fromJson(sceneJson as Map<String, dynamic>))
                      .toList();
                }

                return Chapter(
                  id: chapterId,
                  title: chapter['title'],
                  order: chapter['order'],
                  scenes: scenes,
                );
              }).toList() ??
              [];

          return Act(
            id: act['id'],
            title: act['title'],
            order: act['order'],
            chapters: chapters,
          );
        }).toList() ??
        [];

    // 提取元数据
    final metadata = novelData['metadata'] as Map<String, dynamic>? ?? {};

    // 解析创建时间和更新时间
    DateTime createdAt;
    DateTime updatedAt;

    try {
      // 使用新的工具函数解析 createdAt 和 updatedAt
      createdAt = parseBackendDateTime(novelData['createdAt']);
      updatedAt = parseBackendDateTime(novelData['updatedAt']);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '解析小说时间戳失败',
          e);
      createdAt = DateTime.now();
      updatedAt = DateTime.now();
    }

    return Novel(
      id: novelData['id'],
      title: novelData['title'] ?? '无标题',
      coverImagePath: novelData['coverImage'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      acts: acts,
      lastEditedChapterId: novelData['lastEditedChapterId'],
    );
  }

  /// 将后端Scene模型转换为前端Scene模型
  Scene _convertToSceneModel(Map<String, dynamic> json) {
    // 解析更新时间
    DateTime lastEdited;
    if (json.containsKey('updatedAt')) {
      lastEdited = parseBackendDateTime(json['updatedAt']);
    } else {
      lastEdited = DateTime.now();
    }

    final sceneId =
        json['id'] ?? 'scene_${DateTime.now().millisecondsSinceEpoch}';

    return Scene(
      id: sceneId,
      content: json['content'] ?? '',
      wordCount: json['wordCount'] ?? 0,
      summary: Summary(
        id: 'summary_$sceneId',
        content: json['summary'] ?? '',
      ),
      lastEdited: lastEdited,
    );
  }

  /// 处理WebFlux流式响应数据，统一处理数据类型
  dynamic _handleFluxResponse(dynamic data) {
    if (data == null) return null;

    // 如果是列表类型，确保列表中的每个元素都是Map类型
    if (data is List) {
      return data;
    }
    // 如果是Map类型，直接返回
    else if (data is Map<String, dynamic>) {
      return data;
    }
    // 其他类型，记录警告并返回null
    else {
      AppLogger.w(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '警告：API返回了意外的数据类型: ${data.runtimeType}');
      return null;
    }
  }

  /// 更新场景内容
  @override
  Future<Scene> updateSceneContent(String novelId, String actId,
      String chapterId, String sceneId, Scene scene) async {
    try {
      // 将前端模型转换为后端模型
      final sceneJson = {
        'id': scene.id,
        'novelId': novelId,
        'chapterId': chapterId,
        'content': scene.content,
        'summary': scene.summary.content,
        'wordCount': scene.wordCount,
        'title': '场景 ${scene.id}', // 添加标题
      };

      // 使用新的API路径更新场景内容
      final data = await _apiClient.updateScene(sceneJson);
      return _convertToSceneModel(data);
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '更新场景内容失败',
          e);
      rethrow;
    }
  }

  /// 更新摘要内容
  @override
  Future<Summary> updateSummary(String novelId, String actId, String chapterId,
      String sceneId, Summary summary) async {
    try {
      // 获取当前场景
      final scene = await fetchSceneContent(novelId, actId, chapterId, sceneId);

      // 更新摘要
      final updatedScene = await updateSceneContent(
        novelId,
        actId,
        chapterId,
        sceneId,
        scene.copyWith(summary: summary),
      );

      return updatedScene.summary;
    } catch (e) {
      AppLogger.e(
          'Services/api_service/repositories/impl/novel_repository_impl',
          '更新摘要失败',
          e);
      rethrow;
    }
  }
}
