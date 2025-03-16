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
}