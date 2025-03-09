import 'package:uuid/uuid.dart';
import '../models/chat_models.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/websocket_service.dart';

class ChatRepository {
  
  ChatRepository({
    required this.apiService,
    required this.localStorageService,
    required this.webSocketService,
  });
  final ApiService apiService;
  final LocalStorageService localStorageService;
  final WebSocketService webSocketService;
  
  // 获取聊天会话列表
  Future<List<ChatSession>> getChatSessions(String novelId) async {
    try {
      // 尝试从服务器获取
      final sessions = await apiService.fetchChatSessions(novelId);
      
      // 缓存到本地
      await localStorageService.saveChatSessions(novelId, sessions);
      
      return sessions;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localSessions = await localStorageService.getChatSessions(novelId);
      if (localSessions.isNotEmpty) {
        return localSessions;
      }
      
      // 如果本地也没有，返回空列表
      return [];
    }
  }
  
  // 创建新会话
  Future<ChatSession> createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  }) async {
    try {
      // 创建会话
      final newSession = await apiService.createChatSession(
        title: title,
        novelId: novelId,
        chapterId: chapterId,
      );
      
      // 保存到本地
      await localStorageService.addChatSession(novelId, newSession);
      
      return newSession;
    } catch (e) {
      // 如果服务器请求失败，创建本地临时会话
      final tempSession = ChatSession(
        id: const Uuid().v4(),
        title: title,
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        messages: [],
        novelId: novelId,
        chapterId: chapterId,
      );
      
      // 标记为需要同步
      await localStorageService.addChatSession(novelId, tempSession, needsSync: true);
      
      return tempSession;
    }
  }
  
  // 获取特定会话
  Future<ChatSession> getChatSession(String sessionId) async {
    try {
      // 尝试从服务器获取
      final session = await apiService.fetchChatSession(sessionId);
      
      // 缓存到本地
      await localStorageService.updateChatSession(session);
      
      return session;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localSession = await localStorageService.getChatSession(sessionId);
      if (localSession != null) {
        return localSession;
      }
      throw Exception('无法加载聊天会话: $e');
    }
  }
  
  // 发送消息并获取响应
  Future<AIChatResponse> sendMessage({
    required String sessionId,
    required String message,
    required ChatContext context,
  }) async {
    // 在第二周迭代中，我们使用模拟数据
    // 创建一个模拟的AI响应
    await Future.delayed(const Duration(seconds: 2)); // 模拟网络延迟
    
    final response = AIChatResponse(
      content: _generateMockResponse(message),
      actions: _generateMockActions(message),
    );
    
    return response;
  }
  
  // 保存会话消息
  Future<void> saveChatSession(String sessionId, List<ChatMessage> messages) async {
    try {
      // 保存到服务器
      await apiService.updateChatSessionMessages(sessionId, messages);
      
      // 更新本地缓存
      final session = await localStorageService.getChatSession(sessionId);
      if (session != null) {
        await localStorageService.updateChatSession(
          session.copyWith(
            messages: messages,
            lastUpdatedAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // 如果服务器请求失败，仅保存到本地并标记为需要同步
      final session = await localStorageService.getChatSession(sessionId);
      if (session != null) {
        await localStorageService.updateChatSession(
          session.copyWith(
            messages: messages,
            lastUpdatedAt: DateTime.now(),
          ),
          needsSync: true,
        );
      }
    }
  }
  
  // 更新会话
  Future<void> updateChatSession(ChatSession session) async {
    try {
      // 保存到服务器
      await apiService.updateChatSession(session);
      
      // 更新本地缓存
      await localStorageService.updateChatSession(session);
    } catch (e) {
      // 如果服务器请求失败，仅保存到本地并标记为需要同步
      await localStorageService.updateChatSession(session, needsSync: true);
    }
  }
  
  // 删除会话
  Future<void> deleteChatSession(String sessionId) async {
    try {
      // 从服务器删除
      await apiService.deleteChatSession(sessionId);
      
      // 从本地删除
      await localStorageService.deleteChatSession(sessionId);
    } catch (e) {
      // 如果服务器请求失败，仅从本地删除
      await localStorageService.deleteChatSession(sessionId);
    }
  }
  
  // 取消请求
  Future<void> cancelRequest(String sessionId) async {
    // 在第二周迭代中，我们不实际取消请求，只是模拟
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  // 生成模拟响应（用于第二周迭代）
  String _generateMockResponse(String message) {
    if (message.contains('角色')) {
      return '角色设计是小说创作中的重要环节。好的角色应该有鲜明的性格特点、合理的动机和明确的目标。您可以从以下几个方面来设计角色：\n\n1. 外貌特征：包括身高、体型、面部特征、穿着风格等\n2. 性格特点：内向/外向、乐观/悲观、勇敢/胆小等\n3. 背景故事：家庭环境、成长经历、重要事件等\n4. 目标和动机：角色想要什么，为什么想要\n5. 内在冲突：角色内心的矛盾和挣扎\n\n您想要我帮您设计一个什么样的角色呢？';
    } else if (message.contains('情节')) {
      return '情节发展需要有起承转合，保持读者的兴趣。一个好的情节应该包含：\n\n1. 引人入胜的开端\n2. 不断升级的冲突\n3. 出人意料的转折\n4. 合理的结局\n\n您可以考虑在情节中加入一些意外事件或误会，增加故事的戏剧性。同时，确保每个情节的发展都符合角色的性格和动机，保持内在逻辑的一致性。';
    } else if (message.contains('写作技巧') || message.contains('建议')) {
      return '以下是一些实用的写作技巧：\n\n1. **展示而非讲述**：通过角色的行动、对话和反应来展示情感和性格，而不是直接告诉读者。\n\n2. **感官描写**：使用视觉、听觉、嗅觉、味觉和触觉的描写，让读者身临其境。\n\n3. **对话要自然**：每个角色的对话应该符合其性格和背景，避免所有角色说话方式相同。\n\n4. **控制节奏**：使用不同长度的句子和段落来控制故事的节奏。短句增加紧张感，长句则可以用于描述和反思。\n\n5. **修改是关键**：写作的精华在于修改。完成初稿后，花时间修改和打磨。';
    } else {
      return '感谢您的提问。作为您的AI写作助手，我很乐意帮助您解决创作中遇到的问题。请告诉我您需要什么样的帮助？是角色设计、情节构思、场景描写，还是其他方面的建议？';
    }
  }
  
  // 生成模拟操作（用于第二周迭代）
  List<MessageAction> _generateMockActions(String message) {
    final actions = <MessageAction>[];
    
    if (message.contains('角色')) {
      actions.add(MessageAction(
        id: const Uuid().v4(),
        label: '创建角色',
        type: ActionType.createCharacter,
        data: {'suggestion': '根据对话创建新角色'},
      ));
    }
    
    if (message.contains('情节') || message.contains('剧情')) {
      actions.add(MessageAction(
        id: const Uuid().v4(),
        label: '生成情节',
        type: ActionType.generatePlot,
        data: {'suggestion': '根据当前内容生成情节'},
      ));
    }
    
    if (message.contains('场景') || message.contains('描写')) {
      actions.add(MessageAction(
        id: const Uuid().v4(),
        label: '扩展场景',
        type: ActionType.expandScene,
        data: {'suggestion': '扩展当前场景描写'},
      ));
    }
    
    if (message.contains('语法') || message.contains('错误')) {
      actions.add(MessageAction(
        id: const Uuid().v4(),
        label: '修复语法',
        type: ActionType.fixGrammar,
        data: {'suggestion': '修复选中文本的语法错误'},
      ));
    }
    
    // 始终添加一个应用到编辑器的操作
    actions.add(MessageAction(
      id: const Uuid().v4(),
      label: '应用到编辑器',
      type: ActionType.applyToEditor,
      data: {'suggestion': '将AI回复应用到编辑器'},
    ));
    
    return actions;
  }
} 