import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/chat_models.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/mock_data_generator.dart';

/// API服务，用于与后端通信
class ApiService {
  
  ApiService({
    this.baseUrl = 'http://localhost:8080/api',
    http.Client? client,
  }) : _client = client ?? http.Client() {
    // 构造函数中立即初始化缓存
    _initializeCache();
  }
  final String baseUrl;
  final http.Client _client;
  
  // 添加静态Map来存储运行时的小说数据
  static final Map<String, novel_models.Novel> _novelCache = {};
  static bool _isInitialized = false;
  
  // 初始化缓存
  void _initializeCache() {
    if (!_isInitialized) {
      final novels = _getMockNovels();
      for (final novel in novels) {
        // 同时存储原始ID和带前缀的ID，确保两种形式都能匹配
        _novelCache[novel.id] = novel;
        if (!novel.id.startsWith('novel-')) {
          _novelCache['novel-${novel.id}'] = novel;
        }
      }
      _isInitialized = true;
      print('API服务缓存已初始化，共${_novelCache.length}个条目');
    }
  }
  
  /// 获取所有小说
  Future<List<novel_models.Novel>> fetchNovels() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/novels'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => novel_models.Novel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch novels: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error fetching novels: $e');
      // 返回模拟数据
      return _getMockNovels();
    }
  }
  
  /// 获取单个小说
  Future<novel_models.Novel> fetchNovel(String id) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/novels/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Novel.fromJson(data);
      } else {
        throw Exception('Failed to fetch novel: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error fetching novel: $e');
      
      // 尝试不同形式的ID
      String normalizedId = id;
      if (id.startsWith('novel-')) {
        normalizedId = id.substring(6); // 移除'novel-'前缀
      }
      
      // 先尝试直接匹配
      if (_novelCache.containsKey(id)) {
        print('从缓存中找到小说: $id');
        return _novelCache[id]!;
      } 
      // 再尝试匹配不带前缀的ID
      else if (_novelCache.containsKey(normalizedId)) {
        print('从缓存中找到小说(无前缀): $normalizedId');
        return _novelCache[normalizedId]!;
      }
      // 最后尝试匹配带前缀的ID
      else if (_novelCache.containsKey('novel-$normalizedId')) {
        print('从缓存中找到小说(带前缀): novel-$normalizedId');
        return _novelCache['novel-$normalizedId']!;
      } 
      else {
        // 如果找不到匹配的小说，返回第一个
        print('未找到匹配的小说，返回第一个缓存项');
        return _novelCache.values.first;
      }
    }
  }
  
  /// 创建小说
  Future<novel_models.Novel> createNovel(String title) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/novels'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title}),
      );
      
      if (response.statusCode == 201) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Novel.fromJson(data);
      } else {
        throw Exception('Failed to create novel: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error creating novel: $e');
      // 返回模拟数据
      final now = DateTime.now();
      return novel_models.Novel(
        id: 'new-${now.millisecondsSinceEpoch}',
        title: title,
        createdAt: now,
        updatedAt: now,
        acts: [],
      );
    }
  }
  
  /// 更新小说
  Future<novel_models.Novel> updateNovel(novel_models.Novel novel) async {
    try {
      // 尝试使用原始ID和带前缀的ID
      String requestId = novel.id;
      if (!novel.id.startsWith('novel-') && novel.id != '1') {
        requestId = '1'; // 使用固定ID进行API请求
      }
      
      final response = await _client.put(
        Uri.parse('$baseUrl/novels/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(novel.toJson()),
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Novel.fromJson(data);
      } else {
        throw Exception('Failed to update novel: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error updating novel: $e');
      // 更新缓存中的小说
      _novelCache[novel.id] = novel;
      
      // 同时更新带前缀的版本
      if (!novel.id.startsWith('novel-')) {
        _novelCache['novel-${novel.id}'] = novel;
      }
      
      print('已更新缓存中的小说: ${novel.id}');
      return novel;
    }
  }
  
  /// 删除小说
  Future<void> deleteNovel(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/novels/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode != 204) {
        throw Exception('Failed to delete novel: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error deleting novel: $e');
    }
  }
  
  /// 获取场景内容
  Future<novel_models.Scene> fetchSceneContent(
    String novelId, 
    String actId, 
    String chapterId
  ) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/novels/$novelId/acts/$actId/chapters/$chapterId/scene'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Scene.fromJson(data);
      } else {
        throw Exception('Failed to fetch scene: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error fetching scene: $e');
      
      // 尝试不同形式的ID
      String normalizedId = novelId;
      if (novelId.startsWith('novel-')) {
        normalizedId = novelId.substring(6); // 移除'novel-'前缀
      }
      
      // 从缓存中获取场景
      if (_novelCache.containsKey(novelId)) {
        return _getSceneFromNovel(_novelCache[novelId]!, actId, chapterId);
      } 
      else if (_novelCache.containsKey(normalizedId)) {
        return _getSceneFromNovel(_novelCache[normalizedId]!, actId, chapterId);
      }
      else if (_novelCache.containsKey('novel-$normalizedId')) {
        return _getSceneFromNovel(_novelCache['novel-$normalizedId']!, actId, chapterId);
      }
      else {
        return novel_models.Scene.createEmpty();
      }
    }
  }
  
  // 从小说对象中获取场景
  novel_models.Scene _getSceneFromNovel(novel_models.Novel novel, String actId, String chapterId) {
    try {
      final act = novel.acts.firstWhere((act) => act.id == actId);
      final chapter = act.chapters.firstWhere((chapter) => chapter.id == chapterId);
      return chapter.scene;
    } catch (e) {
      print('获取场景内容失败: $e');
      return novel_models.Scene.createEmpty();
    }
  }
  
  /// 更新场景内容
  Future<novel_models.Scene> updateSceneContent(
    String novelId, 
    String actId, 
    String chapterId, 
    novel_models.Scene scene
  ) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/novels/$novelId/acts/$actId/chapters/$chapterId/scene'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(scene.toJson()),
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Scene.fromJson(data);
      } else {
        throw Exception('Failed to update scene: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error updating scene: $e');
      
      // 尝试不同形式的ID
      String normalizedId = novelId;
      if (novelId.startsWith('novel-')) {
        normalizedId = novelId.substring(6); // 移除'novel-'前缀
      }
      
      // 更新缓存中的场景
      _updateSceneInCache(novelId, actId, chapterId, scene);
      
      // 同时更新其他形式的ID
      if (novelId != normalizedId) {
        _updateSceneInCache(normalizedId, actId, chapterId, scene);
      }
      if (!novelId.startsWith('novel-')) {
        _updateSceneInCache('novel-$novelId', actId, chapterId, scene);
      }
      
      print('已更新缓存中的场景');
      return scene;
    }
  }
  
  // 在缓存中更新场景
  void _updateSceneInCache(String novelId, String actId, String chapterId, novel_models.Scene scene) {
    if (_novelCache.containsKey(novelId)) {
      final novel = _novelCache[novelId]!;
      final acts = novel.acts.map((act) {
        if (act.id == actId) {
          final chapters = act.chapters.map((chapter) {
            if (chapter.id == chapterId) {
              return chapter.copyWith(scene: scene);
            }
            return chapter;
          }).toList();
          return act.copyWith(chapters: chapters);
        }
        return act;
      }).toList();
      
      _novelCache[novelId] = novel.copyWith(
        acts: acts,
        updatedAt: DateTime.now(),
      );
    }
  }
  
  /// 更新摘要内容
  Future<novel_models.Summary> updateSummary(
    String novelId, 
    String actId, 
    String chapterId, 
    novel_models.Summary summary
  ) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/novels/$novelId/acts/$actId/chapters/$chapterId/summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(summary.toJson()),
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Summary.fromJson(data);
      } else {
        throw Exception('Failed to update summary: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error updating summary: $e');
      
      // 尝试不同形式的ID
      String normalizedId = novelId;
      if (novelId.startsWith('novel-')) {
        normalizedId = novelId.substring(6); // 移除'novel-'前缀
      }
      
      // 更新缓存中的摘要
      _updateSummaryInCache(novelId, actId, chapterId, summary);
      
      // 同时更新其他形式的ID
      if (novelId != normalizedId) {
        _updateSummaryInCache(normalizedId, actId, chapterId, summary);
      }
      if (!novelId.startsWith('novel-')) {
        _updateSummaryInCache('novel-$novelId', actId, chapterId, summary);
      }
      
      print('已更新缓存中的摘要');
      return summary;
    }
  }
  
  // 在缓存中更新摘要
  void _updateSummaryInCache(String novelId, String actId, String chapterId, novel_models.Summary summary) {
    if (_novelCache.containsKey(novelId)) {
      final novel = _novelCache[novelId]!;
      final acts = novel.acts.map((act) {
        if (act.id == actId) {
          final chapters = act.chapters.map((chapter) {
            if (chapter.id == chapterId) {
              final updatedScene = chapter.scene.copyWith(summary: summary);
              return chapter.copyWith(scene: updatedScene);
            }
            return chapter;
          }).toList();
          return act.copyWith(chapters: chapters);
        }
        return act;
      }).toList();
      
      _novelCache[novelId] = novel.copyWith(
        acts: acts,
        updatedAt: DateTime.now(),
      );
    }
  }
  
  /// 获取模拟小说数据
  List<novel_models.Novel> _getMockNovels() {
    final novels = <novel_models.Novel>[];
    
    // 添加一个模拟小说
    novels.add(MockDataGenerator.generateMockNovel('1', '真有钱了怎么办'));
    
    // 添加更多模拟小说
    final titles = [
      '风吹稻浪',
      '月光下的守望者',
      '城市边缘',
      '时间的形状',
      '梦境迷宫',
      '蓝色海岸线',
      '记忆碎片',
      '星际旅行指南',
      '未知的边界',
      '寂静花园',
    ];
    
    for (int i = 0; i < 5; i++) {
      final title = titles[i];
      novels.add(MockDataGenerator.generateMockNovel('${i+2}', title));
    }
    
    return novels;
  }
  
  // 获取聊天会话列表
  Future<List<ChatSession>> fetchChatSessions(String novelId) async {
    // 在第二周迭代中，我们使用模拟数据
    await Future.delayed(const Duration(milliseconds: 800)); // 模拟网络延迟
    
    // 返回模拟的会话列表
    return [
      ChatSession(
        id: '1',
        title: '角色设计讨论',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 5)),
        messages: _generateMockMessages(5),
        novelId: novelId,
      ),
      ChatSession(
        id: '2',
        title: '情节构思',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        messages: _generateMockMessages(3),
        novelId: novelId,
      ),
      ChatSession(
        id: '3',
        title: '写作技巧咨询',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        messages: _generateMockMessages(7),
        novelId: novelId,
      ),
    ];
  }
  
  // 创建新的聊天会话
  Future<ChatSession> createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  }) async {
    // 在第二周迭代中，我们使用模拟数据
    await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
    
    // 返回模拟的新会话
    return ChatSession(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      messages: [],
      novelId: novelId,
      chapterId: chapterId,
    );
  }
  
  // 获取特定会话
  Future<ChatSession> fetchChatSession(String sessionId) async {
    // 在第二周迭代中，我们使用模拟数据
    await Future.delayed(const Duration(milliseconds: 600)); // 模拟网络延迟
    
    // 返回模拟的会话
    return ChatSession(
      id: sessionId,
      title: '模拟会话',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      messages: _generateMockMessages(5),
      novelId: 'novel-1',
    );
  }
  
  // 更新会话消息
  Future<void> updateChatSessionMessages(String sessionId, List<ChatMessage> messages) async {
    // 在第二周迭代中，我们只模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 400));
  }
  
  // 更新会话
  Future<void> updateChatSession(ChatSession session) async {
    // 在第二周迭代中，我们只模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 400));
  }
  
  // 删除会话
  Future<void> deleteChatSession(String sessionId) async {
    // 在第二周迭代中，我们只模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));
  }
  
  // 生成模拟消息
  List<ChatMessage> _generateMockMessages(int count) {
    final messages = <ChatMessage>[];
    final now = DateTime.now();
    
    for (int i = 0; i < count; i++) {
      final isUser = i % 2 == 0;
      
      messages.add(ChatMessage(
        id: 'msg-$i',
        role: isUser ? MessageRole.user : MessageRole.assistant,
        content: isUser 
            ? _generateMockUserMessage(i) 
            : _generateMockAIMessage(i),
        timestamp: now.subtract(Duration(minutes: (count - i) * 5)),
        status: MessageStatus.sent,
        actions: isUser ? null : _generateMockActions(i),
      ));
    }
    
    return messages;
  }
  
  // 生成模拟用户消息
  String _generateMockUserMessage(int index) {
    final messages = [
      '我想设计一个有深度的主角，有什么建议？',
      '如何构思一个引人入胜的情节？',
      '我的故事发生在一个古老的城市，如何描写这个场景？',
      '如何写好角色之间的对话？',
      '有什么好的写作技巧可以分享吗？',
      '我的故事节奏感不强，怎么改进？',
      '如何处理多条故事线？',
    ];
    
    return messages[index % messages.length];
  }
  
  // 生成模拟AI消息
  String _generateMockAIMessage(int index) {
    final messages = [
      '设计有深度的角色需要考虑以下几点：\n\n1. 明确角色的动机和目标\n2. 设计内在冲突\n3. 创造复杂的背景故事\n4. 赋予角色独特的声音和表达方式\n5. 让角色有成长空间\n\n您可以先从这些方面入手，逐步丰富角色的层次。',
      '构思引人入胜的情节可以从以下几个方面考虑：\n\n1. 设置明确的冲突\n2. 创造意外转折\n3. 提高情节的紧张感\n4. 设计情感共鸣点\n5. 确保逻辑自洽\n\n您想要我帮您具体分析哪个方面？',
      '描写古老城市的场景时，可以注重以下几点：\n\n1. 利用多种感官描写（视觉、听觉、嗅觉等）\n2. 融入历史元素和文化细节\n3. 通过人物的视角展现城市的不同面貌\n4. 使用对比手法突出城市的特点\n\n您需要我提供一个具体的例子吗？',
      '写好角色对话的关键在于：\n\n1. 确保每个角色有独特的说话方式\n2. 对话要推动情节发展\n3. 避免冗长的对话标签\n4. 通过对话展现角色关系\n5. 保持自然流畅\n\n您想看一个好的对话示例吗？',
      '以下是一些实用的写作技巧：\n\n1. 每天坚持写作，培养习惯\n2. 先完成初稿，再进行修改\n3. 阅读优秀作品，学习技巧\n4. 寻求反馈，不断改进\n5. 使用具体细节，避免抽象描述\n\n希望这些建议对您有所帮助！',
    ];
    
    return messages[index % messages.length];
  }
  
  // 生成模拟操作
  List<MessageAction> _generateMockActions(int index) {
    final actions = <MessageAction>[];
    
    // 根据索引生成不同的操作
    if (index % 3 == 0) {
      actions.add(MessageAction(
        id: 'action-1',
        label: '创建角色',
        type: ActionType.createCharacter,
        data: {'suggestion': '根据对话创建新角色'},
      ));
    } else if (index % 3 == 1) {
      actions.add(MessageAction(
        id: 'action-2',
        label: '生成情节',
        type: ActionType.generatePlot,
        data: {'suggestion': '根据当前内容生成情节'},
      ));
    } else {
      actions.add(MessageAction(
        id: 'action-3',
        label: '扩展场景',
        type: ActionType.expandScene,
        data: {'suggestion': '扩展当前场景描写'},
      ));
    }
    
    // 始终添加一个应用到编辑器的操作
    actions.add(MessageAction(
      id: 'action-apply',
      label: '应用到编辑器',
      type: ActionType.applyToEditor,
      data: {'suggestion': '将AI回复应用到编辑器'},
    ));
    
    return actions;
  }
  
  /// 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/novels/$novelId/chapters/$chapterId/content'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return EditorContent.fromJson(data);
      } else {
        throw Exception('Failed to fetch editor content: ${response.statusCode}');
      }
    } catch (e) {
      // 在实际应用中，这里应该有更好的错误处理
      print('Error fetching editor content: $e');
      
      // 返回模拟数据
      final novel = await fetchNovel(novelId);
      
      // 查找对应的章节和场景
      String content = '{"ops":[{"insert":"\\n"}]}';
      final Map<String, SceneContent> scenes = {};
      
      for (final act in novel.acts) {
        for (final chapter in act.chapters) {
          if (chapter.id == chapterId) {
            content = chapter.scene.content;
          }
          
          // 为所有场景创建SceneContent
          final sceneId = '${act.id}_${chapter.id}';
          scenes[sceneId] = SceneContent(
            content: chapter.scene.content,
            summary: chapter.scene.summary.content,
            title: chapter.title,
            subtitle: '',
          );
        }
      }
      
      return EditorContent(
        id: chapterId,
        content: content,
        lastSaved: DateTime.now(),
        scenes: scenes,
      );
    }
  }
  
  // 保存编辑器内容
  Future<void> saveEditorContent(EditorContent content) async {
    // 在实际应用中，这里应该是一个真实的API调用
    // 现在我们只是模拟一个延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 模拟成功响应
    return;
  }
  
  // 关闭客户端
  void dispose() {
    _client.close();
  }
} 