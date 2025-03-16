import 'dart:async';
import 'dart:convert';
import 'package:ainoval/config/app_config.dart' hide LogLevel;
import 'package:ainoval/models/chat_models.dart';
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
  Future<dynamic> post(String path, {dynamic data, Options? options}) async {
    try {
      final response = await _dio.post(path, data: data, options: options);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('ApiClient', 'post 执行出错，路径: $path', e);
      throw ApiException(-1, '执行 POST 请求时发生意外错误: ${e.toString()}');
    }
  }

  /// 基础流式POST请求方法
  ///
  /// 返回原始字节流 Stream<List<int>>
  Future<Stream<List<int>>> postStream(String path, {dynamic data, Options? options}) async {
    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: data,
        options: (options ?? Options()).copyWith(responseType: ResponseType.stream),
      );
      if (response.data != null) {
        return response.data!.stream;
      } else {
        AppLogger.w('ApiClient', 'postStream 收到空的响应数据，路径: $path');
        return Stream.error(ApiException(-1, '流式请求收到空的响应数据'));
      }
    } on DioException catch (e) {
      AppLogger.e('ApiClient', 'postStream 请求失败，路径: $path', e);
      throw _handleDioError(e);
    } catch (e) {
      AppLogger.e('ApiClient', 'postStream 执行出错，路径: $path', e);
       throw ApiException(-1, '执行流式请求时发生意外错误: ${e.toString()}');
    }
  }

  /// 辅助方法：处理字节流，解码，解析 SSE，并生成指定类型的流
  Stream<T> _processStream<T>({
      required Future<Stream<List<int>>> byteStreamFuture,
      required T Function(Map<String, dynamic>) fromJson,
      required String logContext,
  }) {
    final controller = StreamController<T>();

    byteStreamFuture.then((byteStream) {
        // 直接将 utf8.decoder 绑定到字节流，得到 Stream<String>
        final stringStream = utf8.decoder.bind(byteStream);

        // 然后对 Stream<String> 应用 LineSplitter
        stringStream
            .transform(const LineSplitter()) // 对字符串流按行分割
            .listen(
              (rawLine) {
                try {
                  final line = rawLine.trim();

                  if (line.startsWith('data:')) {
                    final eventData = line.substring(5).trim();
                    if (eventData.isNotEmpty && eventData != '[DONE]') {
                      final json = jsonDecode(eventData);
                      final item = fromJson(json);
                      AppLogger.v('ApiClient', '[$logContext] 解析流式数据: ${item.runtimeType}');
                      if (!controller.isClosed) {
                        controller.add(item);
                      }
                    } else if (eventData == '[DONE]') {
                      AppLogger.i('ApiClient', '[$logContext] 收到流结束标记 [DONE]');
                    }
                  } else if (line.isEmpty) {
                    // 忽略完全是空白的行（原始行 trim 后为空）
                  } else {
                    AppLogger.v('ApiClient', '[$logContext] 忽略非数据行: "$rawLine"');
                  }
                } catch (e, stackTrace) {
                  AppLogger.e('ApiClient', '[$logContext] 解析流式响应行失败: "$rawLine"', e, stackTrace);
                   if (!controller.isClosed) {
                     // 考虑是否要在解析单行失败时关闭整个流
                     // controller.addError(e, stackTrace); // 可以只发送错误而不关闭
                   }
                }
              },
              onDone: () {
                AppLogger.i('ApiClient', '[$logContext] 流式字节流处理完成');
                if (!controller.isClosed) {
                    controller.close();
                }
              },
              onError: (error, stackTrace) {
                AppLogger.e('ApiClient', '[$logContext] 流处理错误', error, stackTrace);
                if (!controller.isClosed) {
                    controller.addError(ApiException(-1, '[$logContext] 流处理失败: ${error.toString()}'), stackTrace);
                    controller.close();
                }
              },
              cancelOnError: true,
            );
      }).catchError((error, stackTrace) {
         AppLogger.e('ApiClient', '[$logContext] 获取流式字节流失败', error, stackTrace);
         if (!controller.isClosed) {
             // ---------- 修改开始 ----------
             // 传递原始 ApiException（如果它是），否则包装
             final apiError = (error is ApiException)
                 ? error
                 : ApiException(-1, '[$logContext] 启动流式请求失败: ${error.toString()}');
             controller.addError(apiError, stackTrace); // 使用 apiError
             // ---------- 修改结束 ----------
             controller.close(); // 关闭控制器表示流结束（虽然是错误结束）
         }
      });

    return controller.stream;
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

  //==== AI 聊天相关接口 (新) ====//

  /// 创建 AI 聊天会话 (非流式)
  Future<ChatSession> createAiChatSession({
    required String userId,
    required String novelId,
    String? modelName,
    Map<String, dynamic>? metadata,
  }) async {
     try {
        final response = await post('/ai-chat/sessions/create', data: {
            'userId': userId,
            'novelId': novelId,
            'modelName': modelName,
            'metadata': metadata,
        });
        return ChatSession.fromJson(response);
     } catch (e) {
         AppLogger.e('ApiClient', '创建 AI 会话失败', e);
         rethrow;
     }
  }

  /// 获取特定 AI 会话 (非流式)
  Future<ChatSession> getAiChatSession(String userId, String sessionId) async {
     try {
        final response = await post('/ai-chat/sessions/get', data: {
          'userId': userId,
          'sessionId': sessionId,
        });
        return ChatSession.fromJson(response);
     } catch (e) {
         AppLogger.e('ApiClient', '获取 AI 会话失败 (ID: $sessionId)', e);
         rethrow;
     }
  }

  /// 获取用户的所有 AI 会话 (流式)
  ///
  /// 返回 ChatSession 流
  Stream<ChatSession> listAiChatUserSessionsStream(String userId, {int page = 0, int size = 100}) {
    final byteStreamFuture = postStream('/ai-chat/sessions/list', data: {'id': userId});
    return _processStream<ChatSession>(
        byteStreamFuture: byteStreamFuture,
        fromJson: ChatSession.fromJson,
        logContext: 'listAiChatUserSessionsStream',
    );
  }

  /// 更新 AI 会话 (非流式)
  Future<ChatSession> updateAiChatSession({
    required String userId,
    required String sessionId,
    required Map<String, dynamic> updates,
  }) async {
     try {
       final response = await post('/ai-chat/sessions/update', data: {
         'userId': userId,
         'sessionId': sessionId,
         'updates': updates,
       });
       return ChatSession.fromJson(response);
     } catch (e) {
         AppLogger.e('ApiClient', '更新 AI 会话失败 (ID: $sessionId)', e);
         rethrow;
     }
  }

  /// 删除 AI 会话 (非流式)
  Future<void> deleteAiChatSession(String userId, String sessionId) async {
     try {
       await post('/ai-chat/sessions/delete', data: {
         'userId': userId,
         'sessionId': sessionId,
       });
     } catch (e) {
         AppLogger.e('ApiClient', '删除 AI 会话失败 (ID: $sessionId)', e);
         rethrow;
     }
  }

  /// 发送 AI 消息 (非流式)
  Future<ChatMessage> sendAiChatMessage({
    required String userId,
    required String sessionId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
       final response = await post('/ai-chat/messages/send', data: {
         'userId': userId,
         'sessionId': sessionId,
         'content': content,
         'metadata': metadata,
       });
       return ChatMessage.fromJson(response);
    } catch (e) {
        AppLogger.e('ApiClient', '发送 AI 消息失败 (SessionID: $sessionId)', e);
        rethrow;
    }
  }

  /// 流式发送 AI 消息
  ///
  /// 返回解析后的 ChatMessage 流
  Stream<ChatMessage> streamAiChatMessage({
    required String userId,
    required String sessionId,
    required String content,
    Map<String, dynamic>? metadata,
  }) {
    final byteStreamFuture = postStream('/ai-chat/messages/stream', data: {
      'userId': userId,
      'sessionId': sessionId,
      'content': content,
      'metadata': metadata,
    });

    return _processStream<ChatMessage>(
      byteStreamFuture: byteStreamFuture,
      fromJson: ChatMessage.fromJson,
      logContext: 'streamAiChatMessage',
    );
  }

  /// 获取 AI 会话消息历史 (流式)
  ///
  /// 返回 ChatMessage 流
  Stream<ChatMessage> getAiChatMessageHistoryStream(String userId, String sessionId, {int limit = 100}) {
     final requestData = {
       'userId': userId,
       'sessionId': sessionId,
       'limit': limit,
     };
     final byteStreamFuture = postStream('/ai-chat/messages/history', data: requestData);

     return _processStream<ChatMessage>(
         byteStreamFuture: byteStreamFuture,
         fromJson: ChatMessage.fromJson,
         logContext: 'getAiChatMessageHistoryStream',
     );
  }

  /// 获取特定 AI 消息 (非流式)
  Future<ChatMessage> getAiChatMessage(String userId, String messageId) async {
    try {
      final response = await post('/ai-chat/messages/get', data: {
        'userId': userId,
        'messageId': messageId,
      });
      return ChatMessage.fromJson(response);
    } catch (e) {
        AppLogger.e('ApiClient', '获取 AI 消息失败 (ID: $messageId)', e);
        rethrow;
    }
  }

  /// 删除 AI 消息 (非流式)
  Future<void> deleteAiChatMessage(String userId, String messageId) async {
    try {
       await post('/ai-chat/messages/delete', data: {
         'userId': userId,
         'messageId': messageId,
       });
    } catch (e) {
        AppLogger.e('ApiClient', '删除 AI 消息失败 (ID: $messageId)', e);
        rethrow;
    }
  }

  /// 获取 AI 会话消息数量 (非流式)
  Future<int> countAiChatSessionMessages(String sessionId) async {
     try {
        final response = await post('/ai-chat/messages/count', data: {'id': sessionId});
        if (response is int) {
            return response;
        } else if (response is String) {
            return int.tryParse(response) ?? (throw ApiException(-1, "无法解析消息数量响应: $response"));
        } else if (response is Map<String, dynamic> && response.containsKey('count')) {
             final count = response['count'];
             if (count is int) return count;
        }
        throw ApiException(-1, "无法解析消息数量响应: $response");
     } catch (e) {
         AppLogger.e('ApiClient', '获取消息数量失败 (SessionID: $sessionId)', e);
         rethrow;
     }
  }

  /// 获取用户 AI 会话数量 (非流式)
  Future<int> countAiChatUserSessions(String userId) async {
     try {
        final response = await post('/ai-chat/sessions/count', data: {'id': userId});
        if (response is int) {
            return response;
        } else if (response is String) {
            return int.tryParse(response) ?? (throw ApiException(-1, "无法解析会话数量响应: $response"));
        } else if (response is Map<String, dynamic> && response.containsKey('count')) {
             final count = response['count'];
             if (count is int) return count;
        }
        throw ApiException(-1, "无法解析会话数量响应: $response");
     } catch (e) {
         AppLogger.e('ApiClient', '获取用户会话数量失败 (UserID: $userId)', e);
         rethrow;
     }
  }

  //==== 旧的聊天相关接口 ====//
  /*
  /// 获取聊天会话列表
  Future<dynamic> getChatSessions(String novelId) async {
    return post('/chats/get-by-novel', data: {'novelId': novelId});
  }
  // ... 其他旧方法 ...
  */

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
