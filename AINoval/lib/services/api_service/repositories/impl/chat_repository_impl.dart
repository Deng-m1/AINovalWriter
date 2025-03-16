import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/chat_models.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart';
import 'package:ainoval/services/mock_data_service.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:uuid/uuid.dart';

/// 聊天仓库实现
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    ApiClient? apiClient,
    MockDataService? mockService,
  })  : _apiClient = apiClient ?? ApiClient(),
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
      final data = await _apiClient.getChatSessions(novelId);
      if (data is List) {
        return data.map((json) => ChatSession.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl',
          '获取聊天会话列表失败', e);
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
      final data =
          await _apiClient.createChatSession(novelId, title, chapterId);
      return ChatSession.fromJson(data);
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl',
          '创建聊天会话失败', e);
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
      final data = await _apiClient.getChatSession(sessionId);
      return ChatSession.fromJson(data);
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl',
          '获取聊天会话失败', e);
      // 如果API请求失败，回退到模拟数据
      return _mockService.getChatSession(sessionId);
    }
  }

  /// 更新会话消息
  @override
  Future<void> updateChatSessionMessages(
      String sessionId, List<ChatMessage> messages) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }

    try {
      await _apiClient.updateChatSessionMessages(
          sessionId, messages.map((m) => m.toJson()).toList());
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl',
          '更新聊天消息失败', e);
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
      await _apiClient.updateChatSession(session.toJson());
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl',
          '更新聊天会话失败', e);
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
      await _apiClient.deleteChatSession(sessionId);
    } catch (e) {
      AppLogger.e('Services/api_service/repositories/impl/chat_repository_impl',
          '删除聊天会话失败', e);
      throw ApiException(-1, '删除聊天会话失败: $e');
    }
  }
  
  /// ChatBloc中使用的方法 - 获取聊天会话列表
  @override
  Future<List<ChatSession>> getChatSessions(String novelId) async {
    return fetchChatSessions(novelId);
  }
  
  /// ChatBloc中使用的方法 - 获取特定会话
  @override
  Future<ChatSession> getChatSession(String sessionId) async {
    return fetchChatSession(sessionId);
  }
  
  /// 发送消息并获取响应
  @override
  Future<AIChatResponse> sendMessage({
    required String sessionId,
    required String message,
    required ChatContext context,
  }) async {
    // 在这个实现中，我们使用模拟数据
    // 创建一个模拟的AI响应
    await Future.delayed(const Duration(seconds: 2)); // 模拟网络延迟
    
    final response = AIChatResponse(
      content: _generateMockResponse(message),
      actions: _generateMockActions(message),
    );
    
    return response;
  }
  
  /// 保存会话消息
  @override
  Future<void> saveChatSession(String sessionId, List<ChatMessage> messages) async {
    // 直接调用已有的更新会话消息方法
    return updateChatSessionMessages(sessionId, messages);
  }
  
  /// 取消请求
  @override
  Future<void> cancelRequest(String sessionId) async {
    // 在这个实现中，我们不实际取消请求，只是模拟
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  // 生成模拟响应
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
  
  // 生成模拟操作
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
