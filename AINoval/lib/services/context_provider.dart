import '../models/chat_models.dart';
import '../repositories/codex_repository.dart';
import '../repositories/novel_repository.dart';

class ContextProvider {
  
  ContextProvider({
    required this.novelRepository,
    required this.codexRepository,
  });
  final NovelRepository novelRepository;
  final CodexRepository codexRepository;
  
  // 获取会话的上下文
  Future<ChatContext> getContextForSession(ChatSession session) async {
    final novelId = session.novelId;
    final chapterId = session.chapterId;
    
    // 收集相关的上下文项目
    List<ContextItem> relevantItems = [];
    
    // 在第二周迭代中，我们使用模拟数据
    // 添加模拟的上下文项目
    
    // 1. 添加小说的基本信息
    relevantItems.add(ContextItem(
      id: 'novel-$novelId',
      type: ContextItemType.note,
      title: '小说信息',
      content: '这是一部正在创作中的小说，ID为$novelId。',
      relevanceScore: 1.0,
    ));
    
    // 2. 如果有指定章节，添加章节信息
    if (chapterId != null) {
      relevantItems.add(ContextItem(
        id: 'chapter-$chapterId',
        type: ContextItemType.chapter,
        title: '当前章节',
        content: '当前正在编辑的章节ID为$chapterId。',
        relevanceScore: 1.0,
      ));
    }
    
    // 3. 添加一些模拟的角色信息
    relevantItems.add(ContextItem(
      id: 'character-1',
      type: ContextItemType.character,
      title: '主角',
      content: '主角是一个年轻的冒险家，勇敢、正直，但有时过于冲动。',
      relevanceScore: 0.9,
    ));
    
    relevantItems.add(ContextItem(
      id: 'character-2',
      type: ContextItemType.character,
      title: '配角',
      content: '配角是主角的好友，聪明、谨慎，经常帮助主角解决问题。',
      relevanceScore: 0.8,
    ));
    
    // 4. 添加一些模拟的地点信息
    relevantItems.add(ContextItem(
      id: 'location-1',
      type: ContextItemType.location,
      title: '主要场景',
      content: '故事主要发生在一个古老的城市，有着悠久的历史和神秘的传说。',
      relevanceScore: 0.7,
    ));
    
    // 5. 添加一些模拟的情节信息
    relevantItems.add(ContextItem(
      id: 'plot-1',
      type: ContextItemType.plot,
      title: '主要情节',
      content: '主角发现了一个古老的秘密，开始了一段冒险之旅。',
      relevanceScore: 0.85,
    ));
    
    return ChatContext(
      novelId: novelId,
      chapterId: chapterId,
      relevantItems: relevantItems,
    );
  }
  
  // 基于当前内容扩展上下文
  Future<ChatContext> expandContextWithCurrentContent(
    ChatContext baseContext,
    String currentContent,
  ) async {
    // 复制现有的上下文项
    final items = List<ContextItem>.from(baseContext.relevantItems);
    
    // 添加当前正在编辑的内容摘要
    items.add(ContextItem(
      id: 'current_content',
      type: ContextItemType.scene,
      title: '当前编辑的内容',
      content: currentContent.length > 1000 
          ? '${currentContent.substring(0, 997)}...' 
          : currentContent,
      relevanceScore: 1.0,
    ));
    
    return baseContext.copyWith(
      selectedText: currentContent,
      relevantItems: items,
    );
  }
  
  // 基于特定的检索词获取相关上下文
  Future<List<ContextItem>> searchRelevantContext(String novelId, String query) async {
    // 在第二周迭代中，我们使用模拟数据
    // 返回一些与查询相关的模拟上下文项
    
    final results = <ContextItem>[];
    
    if (query.contains('角色')) {
      results.add(ContextItem(
        id: 'character-search-1',
        type: ContextItemType.character,
        title: '搜索结果：主角',
        content: '主角是一个年轻的冒险家，勇敢、正直，但有时过于冲动。',
        relevanceScore: 0.95,
      ));
      
      results.add(ContextItem(
        id: 'character-search-2',
        type: ContextItemType.character,
        title: '搜索结果：配角',
        content: '配角是主角的好友，聪明、谨慎，经常帮助主角解决问题。',
        relevanceScore: 0.85,
      ));
    }
    
    if (query.contains('地点') || query.contains('场景')) {
      results.add(ContextItem(
        id: 'location-search-1',
        type: ContextItemType.location,
        title: '搜索结果：主要场景',
        content: '故事主要发生在一个古老的城市，有着悠久的历史和神秘的传说。',
        relevanceScore: 0.9,
      ));
    }
    
    if (query.contains('情节') || query.contains('剧情')) {
      results.add(ContextItem(
        id: 'plot-search-1',
        type: ContextItemType.plot,
        title: '搜索结果：主要情节',
        content: '主角发现了一个古老的秘密，开始了一段冒险之旅。',
        relevanceScore: 0.9,
      ));
    }
    
    // 如果没有特定的查询词，返回一些通用的上下文项
    if (results.isEmpty) {
      results.add(ContextItem(
        id: 'general-search-1',
        type: ContextItemType.note,
        title: '搜索结果：写作提示',
        content: '尝试使用更具体的描述和感官细节来丰富您的场景。',
        relevanceScore: 0.7,
      ));
    }
    
    return results;
  }
} 