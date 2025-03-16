import 'package:ainoval/services/api_service/repositories/novel_repository.dart';

import '../models/chat_models.dart';
import '../repositories/codex_repository.dart';

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

class CodexRepository {
  // 获取角色列表
  Future<List<CodexEntry>> getCharacters(String novelId, {int limit = 10}) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 返回模拟数据
    return [
      CodexEntry(
        id: 'char-1',
        title: '主角',
        type: 'character',
        content: '主角是一个年轻的冒险家，勇敢、正直，但有时过于冲动。',
        tags: ['主角', '冒险家'],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      CodexEntry(
        id: 'char-2',
        title: '配角',
        type: 'character',
        content: '配角是主角的好友，聪明、谨慎，经常帮助主角解决问题。',
        tags: ['配角', '智者'],
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ].take(limit).toList();
  }
  
  // 获取地点列表
  Future<List<CodexEntry>> getLocations(String novelId, {int limit = 10}) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 返回模拟数据
    return [
      CodexEntry(
        id: 'loc-1',
        title: '古老城市',
        type: 'location',
        content: '故事主要发生在一个古老的城市，有着悠久的历史和神秘的传说。',
        tags: ['城市', '古老'],
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      CodexEntry(
        id: 'loc-2',
        title: '神秘森林',
        type: 'location',
        content: '城市附近的森林，传说中有神秘的生物和魔法。',
        tags: ['森林', '神秘'],
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ].take(limit).toList();
  }
  
  // 获取情节列表
  Future<List<CodexEntry>> getPlots(String novelId, {int limit = 10}) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 返回模拟数据
    return [
      CodexEntry(
        id: 'plot-1',
        title: '主要情节',
        type: 'subplot',
        content: '主角发现了一个古老的秘密，开始了一段冒险之旅。',
        tags: ['主线', '冒险'],
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      CodexEntry(
        id: 'plot-2',
        title: '支线情节',
        type: 'subplot',
        content: '主角与配角之间的友情发展。',
        tags: ['支线', '友情'],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ].take(limit).toList();
  }
  
  // 语义搜索
  Future<List<SearchResult>> semanticSearch(String novelId, String query) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 700));
    
    // 根据查询词返回不同的结果
    if (query.contains('角色')) {
      return [
        SearchResult(
          id: 'char-1',
          title: '主角',
          type: 'character',
          content: '主角是一个年轻的冒险家，勇敢、正直，但有时过于冲动。',
          score: 0.95,
        ),
        SearchResult(
          id: 'char-2',
          title: '配角',
          type: 'character',
          content: '配角是主角的好友，聪明、谨慎，经常帮助主角解决问题。',
          score: 0.85,
        ),
      ];
    } else if (query.contains('地点') || query.contains('场景')) {
      return [
        SearchResult(
          id: 'loc-1',
          title: '古老城市',
          type: 'location',
          content: '故事主要发生在一个古老的城市，有着悠久的历史和神秘的传说。',
          score: 0.9,
        ),
        SearchResult(
          id: 'loc-2',
          title: '神秘森林',
          type: 'location',
          content: '城市附近的森林，传说中有神秘的生物和魔法。',
          score: 0.8,
        ),
      ];
    } else if (query.contains('情节') || query.contains('剧情')) {
      return [
        SearchResult(
          id: 'plot-1',
          title: '主要情节',
          type: 'subplot',
          content: '主角发现了一个古老的秘密，开始了一段冒险之旅。',
          score: 0.9,
        ),
        SearchResult(
          id: 'plot-2',
          title: '支线情节',
          type: 'subplot',
          content: '主角与配角之间的友情发展。',
          score: 0.8,
        ),
      ];
    } else {
      // 默认返回一些通用结果
      return [
        SearchResult(
          id: 'char-1',
          title: '主角',
          type: 'character',
          content: '主角是一个年轻的冒险家，勇敢、正直，但有时过于冲动。',
          score: 0.7,
        ),
        SearchResult(
          id: 'loc-1',
          title: '古老城市',
          type: 'location',
          content: '故事主要发生在一个古老的城市，有着悠久的历史和神秘的传说。',
          score: 0.6,
        ),
      ];
    }
  }
}

// Codex条目
class CodexEntry {
  
  CodexEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final String type;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
}

// 搜索结果
class SearchResult {
  
  SearchResult({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.score,
  });
  final String id;
  final String title;
  final String type;
  final String content;
  final double score;
} 