import 'dart:async';
import 'dart:convert';
import 'package:ainoval/config/app_config.dart' hide LogLevel;
import 'package:ainoval/models/chat_models.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
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

  /// 辅助方法：处理字节流，解码，解析 SSE 或单行 JSON 数组，并生成指定类型的流
  Stream<T> _processStream<T>({
      required Future<Stream<List<int>>> byteStreamFuture,
      required T Function(Map<String, dynamic>) fromJson,
      required String logContext,
  }) {
    final controller = StreamController<T>();

    byteStreamFuture.then((byteStream) async {
        final stringStream = utf8.decoder.bind(byteStream);

        await for (final rawLine in stringStream.transform(const LineSplitter())) {
            try {
                final line = rawLine.trim();

                if (line.isEmpty) {
                    continue;
                }

                if (line.startsWith('data:')) {
                    final eventData = line.substring(5).trim();
                    if (eventData.isNotEmpty && eventData != '[DONE]') {
                        final json = jsonDecode(eventData);
                        if (json is Map<String, dynamic>) {
                            final item = fromJson(json);
                            AppLogger.v('ApiClient', '[$logContext] 解析 SSE 数据: ${item.runtimeType}');
                            if (!controller.isClosed) {
                                controller.add(item);
                            }
                        } else {
                             AppLogger.w('ApiClient', '[$logContext] SSE 数据不是有效的 JSON 对象: $eventData');
                        }
                    } else if (eventData == '[DONE]') {
                        AppLogger.i('ApiClient', '[$logContext] 收到 SSE 流结束标记 [DONE]');
                    }
                } else if (line.startsWith('[') && line.endsWith(']')) {
                    AppLogger.v('ApiClient', '[$logContext] 检测到单行 JSON 数组，尝试解析，长度: ${line.length}');
                    final decodedList = jsonDecode(line);
                    if (decodedList is List) {
                        int count = 0;
                        for (final itemJson in decodedList) {
                           await Future.delayed(Duration.zero);

                            if (controller.isClosed) break;

                            if (itemJson is Map<String, dynamic>) {
                                try {
                                    final item = fromJson(itemJson);
                                    AppLogger.v('ApiClient', '[$logContext] 解析 JSON 数组元素 ${++count}: ${item.runtimeType}');
                                    if (!controller.isClosed) {
                                        controller.add(item);
                                    }
                                } catch (e, stackTrace) {
                                    AppLogger.e('ApiClient', '[$logContext] 从 JSON 数组元素转换失败: $itemJson', e, stackTrace);
                                }
                            } else {
                                AppLogger.w('ApiClient', '[$logContext] JSON 数组中的元素不是 Map: $itemJson');
                            }
                        }
                        AppLogger.i('ApiClient', '[$logContext] 成功处理 ${count} 个 JSON 数组元素');
                    } else {
                       AppLogger.w('ApiClient', '[$logContext] 解析为 JSON 但不是列表: "$line"');
                    }
                } else {
                    AppLogger.v('ApiClient', '[$logContext] 忽略非 SSE 且非 JSON 数组的行: "$line"');
                }
            } catch (e, stackTrace) {
                AppLogger.e('ApiClient', '[$logContext] 解析流式响应行失败: "$rawLine"', e, stackTrace);
            }
             if (controller.isClosed) break;
        }
         AppLogger.i('ApiClient', '[$logContext] 流式字符串处理完成');
         if (!controller.isClosed) {
            controller.close();
         }

      }).catchError((error, stackTrace) {
         AppLogger.e('ApiClient', '[$logContext] 获取或解码流式字节流失败', error, stackTrace);
         if (!controller.isClosed) {
             final apiError = (error is ApiException)
                 ? error
                 : ApiException(-1, '[$logContext] 启动或解码流式请求失败: ${error.toString()}');
             controller.addError(apiError, stackTrace);
             controller.close();
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

  //==== 用户 AI 模型配置相关接口 (新) ====//
  final String _userAIConfigBasePath = '/user-ai-configs';

  /// 获取系统支持的 AI 提供商列表
  Future<List<String>> listAIProviders() async {
    final path = '$_userAIConfigBasePath/providers/list';
    try {
      // 后端返回 Flux<String>，在 Dio 拦截器/转换器中转为 List<dynamic>
      final responseData = await post(path);
      if (responseData is List) {
        // 确保列表中的每个元素都转换为 String
        final providers = responseData.map((item) => item.toString()).toList();
        return providers;
      } else {
        AppLogger.e('ApiClient', 'listAIProviders 响应格式错误: $responseData');
        throw ApiException(-1, '获取可用提供商列表响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '获取可用 AI 提供商列表失败', e);
      rethrow; // post 方法已经处理了 DioException
    }
  }

  /// 获取指定 AI 提供商支持的模型列表
  Future<List<String>> listAIModelsForProvider({required String provider}) async {
    final path = '$_userAIConfigBasePath/providers/models/list';
    final body = {'provider': provider};
    try {
      final responseData = await post(path, data: body);
       if (responseData is List) {
        final models = responseData.map((item) => item.toString()).toList();
        return models;
      } else {
        AppLogger.e('ApiClient', 'listAIModelsForProvider 响应格式错误: $responseData');
        throw ApiException(-1, '获取模型列表响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '获取提供商 $provider 的模型列表失败', e);
      rethrow;
    }
  }

  /// 添加新的用户 AI 模型配置
  Future<UserAIModelConfigModel> addAIConfiguration({
    required String userId,
    required String provider,
    required String modelName,
    String? alias,
    required String apiKey,
    String? apiEndpoint,
  }) async {
    final path = '$_userAIConfigBasePath/users/$userId/create';
    final body = <String, dynamic>{
      'provider': provider,
      'modelName': modelName,
      'apiKey': apiKey, // API Key 由后端处理加密
      if (alias != null) 'alias': alias,
      if (apiEndpoint != null) 'apiEndpoint': apiEndpoint,
    };
    try {
      final responseData = await post(path, data: body);
      if (responseData is Map<String, dynamic>) {
        return UserAIModelConfigModel.fromJson(responseData);
      } else {
         AppLogger.e('ApiClient', 'addAIConfiguration 响应格式错误: $responseData');
         throw ApiException(-1, '添加配置响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '添加 AI 配置失败 for user $userId', e);
      rethrow;
    }
  }

  /// 列出用户所有的 AI 模型配置
  Future<List<UserAIModelConfigModel>> listAIConfigurations({
    required String userId,
    bool? validatedOnly,
  }) async {
    final path = '$_userAIConfigBasePath/users/$userId/list';
    final body = <String, dynamic>{};
    if (validatedOnly != null) {
      body['validatedOnly'] = validatedOnly;
    }
    try {
      // 如果 body 为空，data 应该传 null
      final responseData = await post(path, data: body.isEmpty ? null : body);
      if (responseData is List) {
         final configs = responseData
            .map((json) => UserAIModelConfigModel.fromJson(json as Map<String, dynamic>))
            .toList();
         return configs;
      } else {
          AppLogger.e('ApiClient', 'listAIConfigurations 响应格式错误: $responseData');
          throw ApiException(-1, '列出配置响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '列出 AI 配置失败 for user $userId', e);
      rethrow;
    }
  }

  /// 获取指定 ID 的用户 AI 模型配置
  Future<UserAIModelConfigModel> getAIConfigurationById({
    required String userId,
    required String configId,
  }) async {
    final path = '$_userAIConfigBasePath/users/$userId/get/$configId';
    try {
      // POST with no body
      final responseData = await post(path);
       if (responseData is Map<String, dynamic>) {
        return UserAIModelConfigModel.fromJson(responseData);
      } else {
          AppLogger.e('ApiClient', 'getAIConfigurationById 响应格式错误 ($userId/$configId): $responseData');
          throw ApiException(-1, '获取配置详情响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '获取 AI 配置失败 ($userId / $configId)', e);
      rethrow;
    }
  }

  /// 更新指定 ID 的用户 AI 模型配置
  Future<UserAIModelConfigModel> updateAIConfiguration({
    required String userId,
    required String configId,
    String? alias,
    String? apiKey,
    String? apiEndpoint,
  }) async {
    final path = '$_userAIConfigBasePath/users/$userId/update/$configId';
    final body = <String, dynamic>{};
    if (alias != null) body['alias'] = alias;
    if (apiKey != null) body['apiKey'] = apiKey; // 明文发送
    if (apiEndpoint != null) body['apiEndpoint'] = apiEndpoint;

    // 前端仓库层应该已经做了空检查，但以防万一
    if (body.isEmpty) {
       AppLogger.w('ApiClient', '尝试更新配置但没有提供字段 ($userId/$configId)');
       // 可以选择抛出错误或返回当前配置（需要额外调用 get）
       // 这里选择继续发送请求，让后端处理或返回错误
       // throw ApiException(-1, 'Update called with no fields to update');
    }

    try {
      final responseData = await post(path, data: body);
       if (responseData is Map<String, dynamic>) {
        return UserAIModelConfigModel.fromJson(responseData);
      } else {
          AppLogger.e('ApiClient', 'updateAIConfiguration 响应格式错误 ($userId/$configId): $responseData');
          throw ApiException(-1, '更新配置响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '更新 AI 配置失败 ($userId / $configId)', e);
      rethrow;
    }
  }

  /// 删除指定 ID 的用户 AI 模型配置
  Future<void> deleteAIConfiguration({
    required String userId,
    required String configId,
  }) async {
    final path = '$_userAIConfigBasePath/users/$userId/delete/$configId';
    try {
      // POST with no body. Expect 204 No Content for success.
      // Dio's post method should handle 204 correctly (doesn't throw by default).
      // The response.data might be null or empty string for 204.
      await post(path);
      // 不需要检查返回值，如果 post 没抛异常就认为成功
    } catch (e) {
      AppLogger.e('ApiClient', '删除 AI 配置失败 ($userId / $configId)', e);
      // 如果是 404 Not Found 等，post 会抛出 ApiException
      rethrow;
    }
  }

  /// 手动触发指定配置的 API Key 验证
  Future<UserAIModelConfigModel> validateAIConfiguration({
    required String userId,
    required String configId,
  }) async {
    final path = '$_userAIConfigBasePath/users/$userId/validate/$configId';
    try {
      // POST with no body
      final responseData = await post(path);
       if (responseData is Map<String, dynamic>) {
        return UserAIModelConfigModel.fromJson(responseData);
      } else {
          AppLogger.e('ApiClient', 'validateAIConfiguration 响应格式错误 ($userId/$configId): $responseData');
          throw ApiException(-1, '验证配置响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '验证 AI 配置失败 ($userId / $configId)', e);
      rethrow;
    }
  }

   /// 设置指定配置为用户的默认模型
  Future<UserAIModelConfigModel> setDefaultAIConfiguration({
    required String userId,
    required String configId,
  }) async {
    final path = '$_userAIConfigBasePath/users/$userId/set-default/$configId';
    try {
      // POST with no body
      final responseData = await post(path);
       if (responseData is Map<String, dynamic>) {
        return UserAIModelConfigModel.fromJson(responseData);
      } else {
           AppLogger.e('ApiClient', 'setDefaultAIConfiguration 响应格式错误 ($userId/$configId): $responseData');
           throw ApiException(-1, '设置默认配置响应格式错误');
      }
    } catch (e) {
      AppLogger.e('ApiClient', '设置默认 AI 配置失败 ($userId / $configId)', e);
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
