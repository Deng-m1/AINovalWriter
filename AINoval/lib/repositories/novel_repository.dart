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
      return novels.where((novel) => 
        novel.title.toLowerCase().contains(query.toLowerCase()) ||
        novel.seriesName.toLowerCase().contains(query.toLowerCase())
      ).toList();
    } catch (e) {
      throw Exception('搜索小说失败: $e');
    }
  }
  
  // 创建新小说
  Future<NovelSummary> createNovel(String title, {String? seriesName}) async {
    try {
      // 在第一迭代中，使用mock数据创建
      final newNovel = MockData.createNovel(title, seriesName: seriesName);
      
      // 添加到本地存储
      final novels = await getNovels();
      novels.add(newNovel);
      await localStorageService.saveNovelSummaries(novels);
      
      return newNovel;
    } catch (e) {
      throw Exception('创建小说失败: $e');
    }
  }
  
  // 删除小说
  Future<void> deleteNovel(String id) async {
    try {
      // 从本地存储中删除
      final novels = await getNovels();
      final updatedNovels = novels.where((novel) => novel.id != id).toList();
      await localStorageService.saveNovelSummaries(updatedNovels);
      
      // 在实际应用中，还需发送删除请求到服务器
      // await apiService.deleteNovel(id);
    } catch (e) {
      throw Exception('删除小说失败: $e');
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
  
  // 获取小说详情
  Future<Novel> getNovelById(String novelId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 返回模拟数据
    return Novel(
      id: novelId,
      title: novelId == 'novel-1' ? '冒险之旅' : '神秘世界',
      description: '这是一部精彩的小说，讲述了主角的冒险故事。',
      wordCount: novelId == 'novel-1' ? 15000 : 25000,
      chapterCount: novelId == 'novel-1' ? 5 : 8,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
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