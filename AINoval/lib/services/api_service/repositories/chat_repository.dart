import 'package:ainoval/models/chat_models.dart';

/// 聊天仓库接口
/// 
/// 定义与聊天相关的所有API操作
abstract class ChatRepository {
  /// 获取聊天会话列表
  Future<List<ChatSession>> fetchChatSessions(String novelId);
  
  /// 创建新的聊天会话
  Future<ChatSession> createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  });
  
  /// 获取特定会话
  Future<ChatSession> fetchChatSession(String sessionId);
  
  /// 更新会话消息
  Future<void> updateChatSessionMessages(String sessionId, List<ChatMessage> messages);
  
  /// 更新会话
  Future<void> updateChatSession(ChatSession session);
  
  /// 删除会话
  Future<void> deleteChatSession(String sessionId);
  
  /// 获取聊天会话列表 (对应ChatBloc中使用的方法名)
  Future<List<ChatSession>> getChatSessions(String novelId);
  
  /// 获取特定会话 (对应ChatBloc中使用的方法名)
  Future<ChatSession> getChatSession(String sessionId);
  
  /// 发送消息并获取响应
  Future<AIChatResponse> sendMessage({
    required String sessionId,
    required String message,
    required ChatContext context,
  });
  
  /// 保存会话消息
  Future<void> saveChatSession(String sessionId, List<ChatMessage> messages);
  
  /// 取消请求
  Future<void> cancelRequest(String sessionId);
}