import '../models/chat_models.dart';

// 在第二周迭代中，我们使用模拟数据
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