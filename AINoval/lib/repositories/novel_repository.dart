import 'dart:io';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/mock_data.dart';

class NovelRepository {
  
  NovelRepository({
    required this.apiService,
    required this.localStorageService,
  });
  final ApiService apiService;
  final LocalStorageService localStorageService;
  
  // 获取所有小说
  Future<List<NovelSummary>> getNovels() async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));
    
    // 返回模拟数据
    return [
      NovelSummary(
        id: 'novel-1',
        title: '冒险之旅',
        lastEditTime: DateTime.now().subtract(const Duration(hours: 2)),
        wordCount: 15000,
        completionPercentage: 0.3,
      ),
      NovelSummary(
        id: 'novel-2',
        title: '神秘世界',
        lastEditTime: DateTime.now().subtract(const Duration(days: 1)),
        wordCount: 25000,
        completionPercentage: 0.5,
      ),
    ];
  }
  
  // 搜索小说
  Future<List<NovelSummary>> searchNovels(String query) async {
    if (query.isEmpty) {
      return getNovels();
    }
    
    try {
      // 从本地获取所有小说
      final novels = await getNovels();
      
      // 本地过滤
      return novels
          .where((novel) => novel.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      print('搜索小说失败: $e');
      return [];
    }
  }
  
  // 创建新小说
  Future<NovelSummary> createNovel(String title) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));
    
    // 创建新小说
    final newNovel = NovelSummary(
      id: 'novel-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      lastEditTime: DateTime.now(),
      wordCount: 0,
      completionPercentage: 0.0,
    );
    
    // 模拟保存到服务器
    try {
      // 实际项目中，这里应该调用API服务保存到服务器
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 返回新创建的小说
      return newNovel;
    } catch (e) {
      print('创建小说失败: $e');
      throw Exception('创建小说失败: $e');
    }
  }
  
  // 删除小说
  Future<void> deleteNovel(String novelId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));
    
    // 模拟删除操作
    try {
      // 实际项目中，这里应该调用API服务从服务器删除
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 删除成功
      return;
    } catch (e) {
      print('删除小说失败: $e');
      throw Exception('删除小说失败: $e');
    }
  }
  
  // 更新小说
  Future<void> updateNovel(String novelId, String title) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));
    
    // 模拟更新操作
    try {
      // 实际项目中，这里应该调用API服务更新服务器数据
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 更新成功
      return;
    } catch (e) {
      print('更新小说失败: $e');
      throw Exception('更新小说失败: $e');
    }
  }
  
  // 获取小说详情
  Future<NovelSummary> getNovelDetail(String novelId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));
    
    try {
      // 从本地获取所有小说
      final novels = await getNovels();
      
      // 查找指定ID的小说
      final novel = novels.firstWhere(
        (novel) => novel.id == novelId,
        orElse: () => throw Exception('小说不存在'),
      );
      
      return novel;
    } catch (e) {
      print('获取小说详情失败: $e');
      throw Exception('获取小说详情失败: $e');
    }
  }
  
  // 导入小说
  Future<NovelSummary> importNovel(File novelFile) async {
    try {
      // 模拟导入操作
      final importedNovel = MockData.importNovel(novelFile.path);
      
      // 添加到本地存储
      final novels = await getNovels();
      novels.add(importedNovel);
      await localStorageService.saveNovelSummaries(novels);
      
      return importedNovel;
    } catch (e) {
      throw Exception('导入小说失败: $e');
    }
  }
  
  // 获取章节详情
  Future<Chapter> getChapterById(String novelId, String chapterId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 返回模拟数据
    return Chapter(
      id: chapterId,
      title: '第一章',
      order: 1,
      wordCount: 3000,
      summary: '主角开始了他的冒险之旅。',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    );
  }
  
  // 获取前一章节
  Future<Chapter?> getPreviousChapter(String novelId, int currentOrder) async {
    if (currentOrder <= 1) {
      return null;
    }
    
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 返回模拟数据
    return Chapter(
      id: 'chapter-${currentOrder - 1}',
      title: '第${currentOrder - 1}章',
      order: currentOrder - 1,
      wordCount: 2800,
      summary: '前一章的内容摘要。',
      createdAt: DateTime.now().subtract(const Duration(days: 26)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
  }
}

// 小说模型
class Novel {
  
  Novel({
    required this.id,
    required this.title,
    required this.description,
    required this.wordCount,
    required this.chapterCount,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final String description;
  final int wordCount;
  final int chapterCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

// 章节模型
class Chapter {
  
  Chapter({
    required this.id,
    required this.title,
    required this.order,
    required this.wordCount,
    this.summary,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final int order;
  final int wordCount;
  final String? summary;
  final DateTime createdAt;
  final DateTime updatedAt;
} 