import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/mock_data_generator.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_models.dart';


/// 模拟数据服务，提供所有模拟数据
class MockDataService {
  factory MockDataService() => _instance;
  MockDataService._internal() {
    _initializeCache();
  }
  // 单例模式
  static final MockDataService _instance = MockDataService._internal();
  
  // 模拟数据缓存
  final Map<String, novel_models.Novel> _novelCache = {};
  bool _isInitialized = false;
  
  final Uuid _uuid = const Uuid();
  
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
      AppLogger.i('Services/mock_data_service', '模拟数据服务缓存已初始化，共${_novelCache.length}个条目');
    }
  }
  
  /// 获取所有模拟小说
  List<novel_models.Novel> getAllNovels() {
    return _novelCache.values.toList();
  }
  
  /// 获取单个模拟小说
  novel_models.Novel? getNovel(String id) {
    // 尝试不同形式的ID
    String normalizedId = id;
    if (id.startsWith('novel-')) {
      normalizedId = id.substring(6); // 移除'novel-'前缀
    }
    
    // 先尝试直接匹配
    if (_novelCache.containsKey(id)) {
      AppLogger.i('Services/mock_data_service', '从模拟数据中找到小说: $id');
      return _novelCache[id];
    } 
    // 再尝试匹配不带前缀的ID
    else if (_novelCache.containsKey(normalizedId)) {
      AppLogger.i('Services/mock_data_service', '从模拟数据中找到小说(无前缀): $normalizedId');
      return _novelCache[normalizedId];
    }
    // 最后尝试匹配带前缀的ID
    else if (_novelCache.containsKey('novel-$normalizedId')) {
      AppLogger.i('Services/mock_data_service', '从模拟数据中找到小说(带前缀): novel-$normalizedId');
      return _novelCache['novel-$normalizedId'];
    } 
    else if (_novelCache.isNotEmpty) {
      // 如果找不到匹配的小说，返回第一个
      AppLogger.i('Services/mock_data_service', '未找到匹配的小说，返回第一个模拟数据项');
      return _novelCache.values.first;
    }
    
    return null;
  }
  
  /// 更新模拟小说
  void updateNovel(novel_models.Novel novel) {
    _novelCache[novel.id] = novel;
    
    // 同时更新带前缀的版本
    if (!novel.id.startsWith('novel-')) {
      _novelCache['novel-${novel.id}'] = novel;
    }
    
    AppLogger.i('Services/mock_data_service', '已更新模拟数据中的小说: ${novel.id}');
  }
  
  /// 创建新的模拟小说
  novel_models.Novel createNovel(String title) {
    final now = DateTime.now();
    final id = 'new-${now.millisecondsSinceEpoch}';
    
    final novel = novel_models.Novel(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      acts: [],
    );
    
    _novelCache[id] = novel;
    return novel;
  }
  
  /// 获取场景内容
  novel_models.Scene? getSceneContent(String novelId, String actId, String chapterId, String sceneId) {
    final novel = getNovel(novelId);
    if (novel == null) return null;
    
    try {
      final act = novel.acts.firstWhere((act) => act.id == actId);
      final chapter = act.chapters.firstWhere((chapter) => chapter.id == chapterId);
      
      if (chapter.scenes.isEmpty) return null;
      
      // 查找特定场景
      try {
        return chapter.scenes.firstWhere((s) => s.id == sceneId);
      } catch (e) {
        // 如果找不到特定场景，返回第一个场景
        return chapter.scenes.first;
      }
    } catch (e) {
      AppLogger.e('Services/mock_data_service', '获取模拟场景内容失败', e);
      return null;
    }
  }
  
  /// 更新场景内容
  void updateSceneContent(String novelId, String actId, String chapterId, String sceneId, novel_models.Scene scene) {
    final novel = getNovel(novelId);
    if (novel == null) {
      AppLogger.e('Services/mock_data_service', '更新场景内容失败：找不到小说 $novelId');
      return;
    }
    
    // 查找对应的Act
    final actIndex = novel.acts.indexWhere((a) => a.id == actId);
    if (actIndex == -1) {
      AppLogger.e('Services/mock_data_service', '更新场景内容失败：找不到Act $actId');
      return;
    }
    
    final act = novel.acts[actIndex];
    
    // 查找对应的Chapter
    final chapterIndex = act.chapters.indexWhere((c) => c.id == chapterId);
    if (chapterIndex == -1) {
      AppLogger.e('Services/mock_data_service', '更新场景内容失败：找不到Chapter $chapterId');
      return;
    }
    
    final chapter = act.chapters[chapterIndex];
    
    // 查找对应的Scene
    final sceneIndex = chapter.scenes.indexWhere((s) => s.id == sceneId);
    List<novel_models.Scene> updatedScenes;
    
    if (sceneIndex == -1) {
      // 如果找不到Scene，则添加新Scene
      AppLogger.i('Services/mock_data_service', '找不到Scene $sceneId，添加新Scene');
      updatedScenes = [...chapter.scenes, scene];
    } else {
      // 更新现有Scene
      updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
      updatedScenes[sceneIndex] = scene;
    }
    
    // 更新Chapter的Scenes
    final updatedChapter = chapter.copyWith(scenes: updatedScenes);
    
    // 更新Act的Chapters
    final updatedChapters = List<novel_models.Chapter>.from(act.chapters);
    updatedChapters[chapterIndex] = updatedChapter;
    final updatedAct = act.copyWith(chapters: updatedChapters);
    
    // 更新Novel的Acts
    final updatedActs = List<novel_models.Act>.from(novel.acts);
    updatedActs[actIndex] = updatedAct;
    final updatedNovel = novel.copyWith(
      acts: updatedActs,
      updatedAt: DateTime.now(),
    );
    
    // 更新缓存
    _novelCache[novel.id] = updatedNovel;
    
    // 同时更新带前缀的版本
    if (!novel.id.startsWith('novel-')) {
      _novelCache['novel-${novel.id}'] = updatedNovel;
    }
    
    AppLogger.i('Services/mock_data_service', '已更新模拟数据中的场景');
  }
  
  /// 更新摘要内容
  void updateSummary(String novelId, String actId, String chapterId, String sceneId, novel_models.Summary summary) {
    if (_novelCache.containsKey(novelId)) {
      final novel = _novelCache[novelId]!;
      final acts = novel.acts.map((act) {
        if (act.id == actId) {
          final chapters = act.chapters.map((chapter) {
            if (chapter.id == chapterId) {
              // 查找特定场景
              final sceneIndex = chapter.scenes.indexWhere((s) => s.id == sceneId);
              List<novel_models.Scene> updatedScenes;
              
              if (sceneIndex >= 0) {
                // 更新现有场景
                updatedScenes = List.from(chapter.scenes);
                updatedScenes[sceneIndex] = updatedScenes[sceneIndex].copyWith(summary: summary);
              } else {
                // 如果场景不存在，不做任何操作
                updatedScenes = chapter.scenes;
              }
              
              return chapter.copyWith(scenes: updatedScenes);
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
      
      // 同时更新带前缀的版本
      if (!novelId.startsWith('novel-')) {
        _novelCache['novel-$novelId'] = _novelCache[novelId]!;
      }
      
      AppLogger.i('Services/mock_data_service', '已更新模拟数据中的摘要');
    }
  }
  
  /// 获取编辑器内容
  EditorContent getEditorContent(String novelId, String chapterId, String sceneId) {
    final novel = getNovel(novelId);
    if (novel == null) {
      return EditorContent(
        id: '$novelId-$chapterId-$sceneId',
        content: '{"ops":[{"insert":"\\n"}]}',
        lastSaved: DateTime.now(),
      );
    }
    
    // 查找对应的章节和场景
    String content = '{"ops":[{"insert":"\\n"}]}';
    final Map<String, SceneContent> scenes = {};
    
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        if (chapter.id == chapterId) {
          // 查找特定场景
          try {
            final scene = chapter.scenes.firstWhere((s) => s.id == sceneId);
            content = scene.content;
          } catch (e) {
            // 如果找不到特定场景，使用第一个场景（如果有）
            if (chapter.scenes.isNotEmpty) {
              content = chapter.scenes.first.content;
            }
          }
        }
        
        // 为所有场景创建SceneContent
        for (final scene in chapter.scenes) {
          final sceneKey = '${act.id}_${chapter.id}_${scene.id}';
          scenes[sceneKey] = SceneContent(
            content: scene.content,
            summary: scene.summary.content,
            title: chapter.title,
            subtitle: '',
          );
        }
      }
    }
    
    return EditorContent(
      id: chapterId,
      content: content,
      lastSaved: DateTime.now(),
      scenes: scenes,
    );
  }
  
  /// 获取聊天会话列表
  List<ChatSession> getChatSessions(String novelId) {
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
  
  /// 创建新的聊天会话
  ChatSession createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  }) {
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
  
  /// 获取特定会话
  ChatSession getChatSession(String sessionId) {
    return ChatSession(
      id: sessionId,
      title: '模拟会话',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      messages: _generateMockMessages(5),
      novelId: 'novel-1',
    );
  }
  
  /// 获取修订历史
  List<Revision> getRevisionHistory(String novelId, String chapterId) {
    final now = DateTime.now();
    return [
      Revision(
        id: 'rev-1',
        timestamp: now.subtract(const Duration(days: 3)),
        authorId: 'user-1',
        content: '{"ops":[{"insert":"这是初始版本的内容。\\n"}]}',
        comment: '初始版本',
      ),
      Revision(
        id: 'rev-2',
        timestamp: now.subtract(const Duration(days: 2)),
        authorId: 'user-1',
        content: '{"ops":[{"insert":"这是第一次修改后的内容。\\n"}]}',
        comment: '第一次修改',
      ),
      Revision(
        id: 'rev-3',
        timestamp: now.subtract(const Duration(days: 1)),
        authorId: 'user-1',
        content: '{"ops":[{"insert":"这是第二次修改后的内容。\\n"}]}',
        comment: '第二次修改',
      ),
    ];
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
  
  /// 根据场景ID获取场景
  novel_models.Scene? getSceneById(String sceneId) {
    for (final novel in _novelCache.values) {
      for (final act in novel.acts) {
        for (final chapter in act.chapters) {
          for (final scene in chapter.scenes) {
            if (scene.id == sceneId) {
              return scene;
            }
          }
        }
      }
    }
    return null;
  }
} 