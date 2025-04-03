import 'dart:async';

import 'package:ainoval/models/chat_models.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:dio/dio.dart';

/// 聊天仓库实现
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required this.apiClient,
  });

  final ApiClient apiClient;

  /// 获取聊天会话列表 (流式) - 简化版
  @override
  Stream<ChatSession> fetchUserSessions(String userId) {
    AppLogger.i('ChatRepositoryImpl', '获取用户会话流: userId=$userId');
    // 直接返回 ApiClient 的流，让 BLoC 处理错误和转换
    // ApiClient 的 _processStream 已经包含了基本的错误处理
    try {
      return apiClient.listAiChatUserSessionsStream(userId);
    } catch (e, stackTrace) {
      // 捕获同步错误（例如参数问题），虽然不太可能
      AppLogger.e('ChatRepositoryImpl', '发起获取用户会话流时出错 [同步]', e, stackTrace);
      return Stream.error(
          ApiExceptionHelper.fromException(e, '发起获取用户会话流失败'), stackTrace);
    }
  }

  /// 创建新的聊天会话 (非流式)
  @override
  Future<ChatSession> createSession({
    required String userId,
    required String novelId,
    String? modelName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.i('ChatRepositoryImpl',
          '创建会话: userId=$userId, novelId=$novelId, modelName=$modelName');
      // 注意：ApiClient 方法现在直接返回 ChatSession
      final session = await apiClient.createAiChatSession(
        userId: userId,
        novelId: novelId,
        modelName: modelName,
        metadata: metadata,
      );
      AppLogger.i('ChatRepositoryImpl', '创建会话成功: sessionId=${session.id}');
      return session;
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl',
          '创建会话失败: userId=$userId, novelId=$novelId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '创建会话失败');
    }
  }

  /// 获取特定会话 (非流式)
  @override
  Future<ChatSession> getSession(String userId, String sessionId) async {
    try {
      AppLogger.i(
          'ChatRepositoryImpl', '获取会话: userId=$userId, sessionId=$sessionId');
      final session = await apiClient.getAiChatSession(userId, sessionId);
      AppLogger.i('ChatRepositoryImpl',
          '获取会话成功: sessionId=$sessionId, title=${session.title}');
      return session;
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl',
          '获取会话失败: userId=$userId, sessionId=$sessionId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '获取会话失败');
    }
  }

  /// 更新会话 (非流式)
  @override
  Future<ChatSession> updateSession({
    required String userId,
    required String sessionId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      AppLogger.i('ChatRepositoryImpl',
          '更新会话: userId=$userId, sessionId=$sessionId, updates=$updates');
      final updatedSession = await apiClient.updateAiChatSession(
        userId: userId,
        sessionId: sessionId,
        updates: updates,
      );
      AppLogger.i('ChatRepositoryImpl',
          '更新会话成功: sessionId=$sessionId, title=${updatedSession.title}');
      return updatedSession;
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl',
          '更新会话失败: userId=$userId, sessionId=$sessionId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '更新会话失败');
    }
  }

  /// 删除会话 (非流式)
  @override
  Future<void> deleteSession(String userId, String sessionId) async {
    try {
      AppLogger.i(
          'ChatRepositoryImpl', '删除会话: userId=$userId, sessionId=$sessionId');
      await apiClient.deleteAiChatSession(userId, sessionId);
      AppLogger.i('ChatRepositoryImpl', '删除会话成功: sessionId=$sessionId');
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl',
          '删除会话失败: userId=$userId, sessionId=$sessionId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '删除会话失败');
    }
  }

  /// 发送消息并获取响应 (非流式)
  @override
  Future<ChatMessage> sendMessage({
    required String userId,
    required String sessionId,
    required String content,
    Map<String, dynamic>? metadata,
    String? configId,
  }) async {
    try {
      AppLogger.i('ChatRepositoryImpl',
          '发送消息: userId=$userId, sessionId=$sessionId, configId=$configId, contentLength=${content.length}');
      final messageResponse = await apiClient.sendAiChatMessage(
        userId: userId,
        sessionId: sessionId,
        content: content,
        metadata: metadata,
      );
      AppLogger.i('ChatRepositoryImpl',
          '收到AI响应: sessionId=$sessionId, messageId=${messageResponse.id}, contentLength=${messageResponse.content.length}');
      return messageResponse;
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl',
          '发送消息失败: userId=$userId, sessionId=$sessionId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '发送消息失败');
    }
  }

  /// 流式发送消息并获取响应 - 简化版
  @override
  Stream<ChatMessage> streamMessage({
    required String userId,
    required String sessionId,
    required String content,
    Map<String, dynamic>? metadata,
    String? configId,
  }) {
    AppLogger.i('ChatRepositoryImpl',
        '开始流式消息: userId=$userId, sessionId=$sessionId, configId=$configId');
    // 直接返回 ApiClient 的流
    try {
      return apiClient.streamAiChatMessage(
        userId: userId,
        sessionId: sessionId,
        content: content,
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl', '发起流式消息请求时出错 [同步]', e, stackTrace);
      return Stream.error(
          ApiExceptionHelper.fromException(e, '发起流式消息请求失败'), stackTrace);
    }
  }

  /// 获取会话消息历史 (流式) - 简化版
  @override
  Stream<ChatMessage> getMessageHistory(
    String userId,
    String sessionId, {
    int limit = 100,
  }) {
    AppLogger.i('ChatRepositoryImpl',
        '获取消息历史流: userId=$userId, sessionId=$sessionId, limit=$limit');
    // 直接返回 ApiClient 的流
    try {
      return apiClient.getAiChatMessageHistoryStream(userId, sessionId,
          limit: limit);
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl', '发起获取消息历史流请求时出错 [同步]', e, stackTrace);
      return Stream.error(
          ApiExceptionHelper.fromException(e, '发起获取消息历史流失败'), stackTrace);
    }
  }

  /// 获取特定消息 (非流式)
  @override
  Future<ChatMessage> getMessage(String userId, String messageId) async {
    try {
      AppLogger.i(
          'ChatRepositoryImpl', '获取消息: userId=$userId, messageId=$messageId');
      final message = await apiClient.getAiChatMessage(userId, messageId);
      AppLogger.i('ChatRepositoryImpl',
          '获取消息成功: messageId=$messageId, role=${message.role}');
      return message;
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl',
          '获取消息失败: userId=$userId, messageId=$messageId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '获取消息失败');
    }
  }

  /// 删除消息 (非流式)
  @override
  Future<void> deleteMessage(String userId, String messageId) async {
    try {
      AppLogger.i(
          'ChatRepositoryImpl', '删除消息: userId=$userId, messageId=$messageId');
      await apiClient.deleteAiChatMessage(userId, messageId);
      AppLogger.i('ChatRepositoryImpl', '删除消息成功: messageId=$messageId');
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl',
          '删除消息失败: userId=$userId, messageId=$messageId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '删除消息失败');
    }
  }

  /// 获取会话消息数量 (非流式)
  @override
  Future<int> countSessionMessages(String sessionId) async {
    try {
      AppLogger.i('ChatRepositoryImpl', '统计会话消息数量: sessionId=$sessionId');
      final count = await apiClient.countAiChatSessionMessages(sessionId);
      AppLogger.i('ChatRepositoryImpl',
          '统计会话消息数量成功: sessionId=$sessionId, count=$count');
      return count;
    } catch (e, stackTrace) {
      AppLogger.e('ChatRepositoryImpl', '统计会话消息数量失败: sessionId=$sessionId', e,
          stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '统计会话消息数量失败');
    }
  }

  /// 获取用户会话数量 (非流式)
  @override
  Future<int> countUserSessions(String userId) async {
    try {
      AppLogger.i('ChatRepositoryImpl', '统计用户会话数量: userId=$userId');
      final count = await apiClient.countAiChatUserSessions(userId);
      AppLogger.i(
          'ChatRepositoryImpl', '统计用户会话数量成功: userId=$userId, count=$count');
      return count;
    } catch (e, stackTrace) {
      AppLogger.e(
          'ChatRepositoryImpl', '统计用户会话数量失败: userId=$userId', e, stackTrace);
      // 使用辅助方法处理错误
      throw ApiExceptionHelper.fromException(e, '统计用户会话数量失败');
    }
  }
}

// 辅助扩展方法，如果 ApiException 没有 fromException
extension ApiExceptionHelper on ApiException {
  static ApiException fromException(dynamic e, String defaultMessage) {
    if (e is ApiException) {
      return e;
    } else if (e is DioException) {
      // 现在可以识别 DioException 了
      final statusCode = e.response?.statusCode ?? -1;
      // 尝试获取后端返回的错误信息，如果失败则使用 DioException 的 message
      final backendMessage = _tryGetBackendMessage(e.response);
      final detailedMessage = backendMessage ?? e.message ?? defaultMessage;
      return ApiException(statusCode, '$defaultMessage: $detailedMessage');
    } else {
      return ApiException(-1, '$defaultMessage: ${e.toString()}');
    }
  }

  // 尝试从 Response 中提取后端错误信息
  static String? _tryGetBackendMessage(Response? response) {
    if (response?.data != null) {
      try {
        final data = response!.data;
        if (data is Map<String, dynamic>) {
          // 查找常见的错误消息字段
          if (data.containsKey('message') && data['message'] is String) {
            return data['message'];
          }
          if (data.containsKey('error') && data['error'] is String) {
            return data['error'];
          }
          if (data.containsKey('detail') && data['detail'] is String) {
            return data['detail'];
          }
        } else if (data is String && data.isNotEmpty) {
          return data; // 如果响应体直接是错误字符串
        }
      } catch (_) {
        // 忽略解析错误
      }
    }
    return null;
  }
}
