import 'package:ainoval/config/app_config.dart' hide LogLevel;
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:dio/dio.dart';

/// API客户端基类
///
/// 负责处理与后端API的基础通信，使用Dio包实现HTTP请求
class ApiClient {
  ApiClient({Dio? dio}) {
    _dio = dio ?? _createDio();
  }
  late final Dio _dio;

  /// 创建并配置Dio实例
  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    // 添加拦截器
    dio.interceptors.add(_createAuthInterceptor());
    dio.interceptors.add(_createLogInterceptor());

    return dio;
  }

  /// 创建认证拦截器
  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AppConfig.authToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    );
  }

  /// 创建日志拦截器
  Interceptor _createLogInterceptor() {
    final currentLogLevel = AppConfig.logLevel;

    return LogInterceptor(
      requestBody: currentLogLevel == LogLevel.warning,
      responseBody: currentLogLevel == LogLevel.warning,
      error: currentLogLevel == LogLevel.debug ||
          currentLogLevel == LogLevel.error,
      requestHeader: currentLogLevel == LogLevel.warning,
      responseHeader: currentLogLevel == LogLevel.warning,
    );
  }

  /// 基础POST请求方法
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  //==== 小说相关接口 ====//

  /// 根据作者ID获取小说列表
  Future<dynamic> getNovelsByAuthor(String authorId) async {
    return post('/novels/get-by-author', data: {'authorId': authorId});
  }

  /// 根据ID获取小说详情
  Future<dynamic> getNovelDetailById(String id) async {
    return post('/novels/get-with-scenes', data: {'id': id});
  }

  /// 创建小说
  Future<dynamic> createNovel(Map<String, dynamic> novelData) async {
    return post('/novels/create', data: novelData);
  }

  /// 更新小说
  Future<dynamic> updateNovel(Map<String, dynamic> novelData) async {
    try {
      final response = await post('/novels/update', data: novelData);
      return response;
    } catch (e) {
      AppLogger.e('Services/api_service/base/api_client', '更新小说数据失败', e);
      rethrow;
    }
  }

  /// 更新小说及其场景内容
  Future<dynamic> updateNovelWithScenes(Map<String, dynamic> novelWithScenesData) async {
    AppLogger.i('/novels/update-with-scenes', '开始更新小说及场景数据');
    AppLogger.d('/novels/update-with-scenes', '发送的数据: $novelWithScenesData');
    try {
      final response = await post('/novels/update-with-scenes', data: novelWithScenesData);
      AppLogger.i('/novels/update-with-scenes', '更新成功，响应: $response');
      return response;
    } catch (e) {
      AppLogger.e('/novels/update-with-scenes', '更新小说及场景数据失败，发送的数据: $novelWithScenesData', e);
      rethrow;
    }
  }

  /// 删除小说
  Future<dynamic> deleteNovel(String id) async {
    return post('/novels/delete', data: {'id': id});
  }

  /// 根据标题搜索小说
  Future<dynamic> searchNovelsByTitle(String title) async {
    return post('/novels/search-by-title', data: {'title': title});
  }



  //==== 场景相关接口 ====//

  /// 根据ID获取场景内容
  Future<dynamic> getSceneById(
      String novelId, String chapterId, String sceneId) async {
    try {
      final response = await post('/scenes/get', data: {
        'id': sceneId,
      });
      return response;
    } catch (e) {
      AppLogger.e('Services/api_service/base/api_client', '获取场景数据失败', e);
      rethrow;
    }
  }

  /// 根据章节ID获取所有场景
  Future<dynamic> getScenesByChapter(String novelId, String chapterId) async {
    return post('/scenes/get-by-chapter',
        data: {'novelId': novelId, 'chapterId': chapterId});
  }

  /// 创建场景,未使用
  Future<dynamic> createScene(Map<String, dynamic> sceneData) async {
    return post('/scenes/create', data: sceneData);
  }

  /// 更新场景 (调用后端的 upsert 接口)
  Future<dynamic> updateScene(Map<String, dynamic> sceneData) async {
    try {
      final response = await post('/scenes/upsert', data: sceneData);
      return response;
    } catch (e) {
      AppLogger.e('Services/api_service/base/api_client', '更新/创建场景数据失败', e); // 更新日志消息
      rethrow;
    }
  }

  /// 更新场景并保存历史版本
  Future<dynamic> updateSceneWithHistory(String novelId, String chapterId,
      String sceneId, String content, String userId, String reason) async {
    return post('/scenes/update-with-history', data: {
      'novelId': novelId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'content': content,
      'userId': userId,
      'reason': reason
    });
  }

  /// 获取场景历史版本
  Future<dynamic> getSceneHistory(
      String novelId, String chapterId, String sceneId) async {
    return post('/scenes/history',
        data: {'novelId': novelId, 'chapterId': chapterId, 'sceneId': sceneId});
  }

  /// 恢复场景历史版本
  Future<dynamic> restoreSceneVersion(String novelId, String chapterId,
      String sceneId, int historyIndex, String userId, String reason) async {
    return post('/scenes/restore', data: {
      'novelId': novelId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'historyIndex': historyIndex,
      'userId': userId,
      'reason': reason
    });
  }

  /// 比较场景版本
  Future<dynamic> compareSceneVersions(String novelId, String chapterId,
      String sceneId, int versionIndex1, int versionIndex2) async {
    return post('/scenes/compare', data: {
      'novelId': novelId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'versionIndex1': versionIndex1,
      'versionIndex2': versionIndex2
    });
  }

  //==== 编辑器相关接口 ====//

  /// 获取编辑器内容
  Future<dynamic> getEditorContent(
      String novelId, String chapterId, String sceneId) async {
    return post('/editor/get-content',
        data: {'novelId': novelId, 'chapterId': chapterId, 'sceneId': sceneId});
  }

  /// 保存编辑器内容
  Future<dynamic> saveEditorContent(
      String novelId, String chapterId, Map<String, dynamic> content) async {
    return post('/editor/save-content',
        data: {'novelId': novelId, 'chapterId': chapterId, 'content': content});
  }

  /// 获取修订历史
  Future<dynamic> getRevisionHistory(String novelId, String chapterId) async {
    return post('/editor/get-revisions',
        data: {'novelId': novelId, 'chapterId': chapterId});
  }

  /// 创建修订版本
  Future<dynamic> createRevision(
      String novelId, String chapterId, Map<String, dynamic> revision) async {
    return post('/editor/create-revision', data: {
      'novelId': novelId,
      'chapterId': chapterId,
      'revision': revision
    });
  }

  /// 应用修订版本
  Future<dynamic> applyRevision(
      String novelId, String chapterId, String revisionId) async {
    return post('/editor/apply-revision', data: {
      'novelId': novelId,
      'chapterId': chapterId,
      'revisionId': revisionId
    });
  }

  //==== 聊天相关接口 ====//

  /// 获取聊天会话列表
  Future<dynamic> getChatSessions(String novelId) async {
    return post('/chats/get-by-novel', data: {'novelId': novelId});
  }

  /// 获取特定会话
  Future<dynamic> getChatSession(String sessionId) async {
    return post('/chats/get-by-id', data: {'sessionId': sessionId});
  }

  /// 创建新的聊天会话
  Future<dynamic> createChatSession(
      String novelId, String title, String? chapterId) async {
    return post('/chats/create',
        data: {'novelId': novelId, 'title': title, 'chapterId': chapterId});
  }

  /// 更新会话消息
  Future<dynamic> updateChatSessionMessages(
      String sessionId, List<Map<String, dynamic>> messages) async {
    return post('/chats/update-messages',
        data: {'sessionId': sessionId, 'messages': messages});
  }

  /// 更新会话
  Future<dynamic> updateChatSession(Map<String, dynamic> session) async {
    return post('/chats/update', data: session);
  }

  /// 删除会话
  Future<dynamic> deleteChatSession(String sessionId) async {
    return post('/chats/delete', data: {'sessionId': sessionId});
  }

  /// 处理Dio错误
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(408, '请求超时，请稍后重试');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 500;
        final message = _getErrorMessageFromResponse(error.response);
        return ApiException(statusCode, message);
      case DioExceptionType.cancel:
        return ApiException(499, '请求被取消');
      case DioExceptionType.connectionError:
        return ApiException(0, '网络连接失败，请检查您的网络连接');
      default:
        return ApiException(-1, '请求失败: ${error.message}');
    }
  }

  /// 从响应中获取错误信息
  String _getErrorMessageFromResponse(Response? response) {
    if (response == null) return '未知错误';

    try {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['message'] ?? data['error'] ?? '未知错误';
      }
      return data.toString();
    } catch (e) {
      return response.statusMessage ?? '未知错误';
    }
  }

  /// 关闭客户端
  void dispose() {
    _dio.close();
  }
}
