import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/chat_models.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart';
import 'package:ainoval/services/mock_data_service.dart';
import 'package:ainoval/utils/logger.dart';


/// 聊天仓库实现
class ChatRepositoryImpl implements ChatRepository {
  
  ChatRepositoryImpl({
    ApiClient? apiClient,
    MockDataService? mockService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _mockService = mockService ?? MockDataService();
  final ApiClient _apiClient;
  final MockDataService _mockService;
  
  /// 获取聊天会话列表
  @override
  Future<List<ChatSession>> fetchChatSessions(String novelId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockService.getChatSessions(novelId);
    }
    
    try {
      final data = await _apiClient.get('/novels/$novelId/chats');
      if (data is List) {
        return data.map((json) => ChatSession.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl', '获取聊天会话列表失败', e);
      // 如果API请求失败，回退到模拟数据
      return _mockService.getChatSessions(novelId);
    }
  }
  
  /// 创建新的聊天会话
  @override
  Future<ChatSession> createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  }) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockService.createChatSession(
        title: title,
        novelId: novelId,
        chapterId: chapterId,
      );
    }
    
    try {
      final body = {
        'title': title,
        'chapterId': chapterId,
      };
      
      final data = await _apiClient.post('/novels/$novelId/chats', data: body);
      return ChatSession.fromJson(data);
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl', '创建聊天会话失败', e);
      // 如果API请求失败，回退到模拟数据
      return _mockService.createChatSession(
        title: title,
        novelId: novelId,
        chapterId: chapterId,
      );
    }
  }
  
  /// 获取特定会话
  @override
  Future<ChatSession> fetchChatSession(String sessionId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockService.getChatSession(sessionId);
    }
    
    try {
      final data = await _apiClient.get('/chats/$sessionId');
      return ChatSession.fromJson(data);
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl', '获取聊天会话失败', e);
      // 如果API请求失败，回退到模拟数据
      return _mockService.getChatSession(sessionId);
    }
  }
  
  /// 更新会话消息
  @override
  Future<void> updateChatSessionMessages(String sessionId, List<ChatMessage> messages) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    
    try {
      await _apiClient.put('/chats/$sessionId/messages', 
          data: messages.map((m) => m.toJson()).toList());
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl', '更新聊天消息失败', e);
      throw ApiException(-1, '更新聊天消息失败: $e');
    }
  }
  
  /// 更新会话
  @override
  Future<void> updateChatSession(ChatSession session) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    
    try {
      await _apiClient.put('/chats/${session.id}', data: session.toJson());
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl', '更新聊天会话失败', e);
      throw ApiException(-1, '更新聊天会话失败: $e');
    }
  }
  
  /// 删除会话
  @override
  Future<void> deleteChatSession(String sessionId) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    
    try {
      await _apiClient.delete('/chats/$sessionId');
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl', '删除聊天会话失败', e);
      throw ApiException(-1, '删除聊天会话失败: $e');
    }
  }
}