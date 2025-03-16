import 'dart:io';

import 'package:ainoval/config/app_config.dart';
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
    try {
      // 从API获取小说列表（现在会自动根据用户ID获取）
      final novels = await apiService.fetchNovels();
      
      // 转换为NovelSummary列表
      return novels.map((novel) => NovelSummary(
        id: novel.id,
        title: novel.title,
        coverImagePath: novel.coverImagePath,
        lastEditTime: novel.updatedAt,
        wordCount: novel.wordCount,
        completionPercentage: 0.0, // 需要计算或从后端获取
      )).toList();
    } catch (e) {
      print('获取小说列表失败: $e');
      
      // 如果使用模拟数据，返回模拟数据
      if (AppConfig.shouldUseMockData) {
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
      
      throw Exception('获取小说列表失败: $e');
    }
  }
  
  // 搜索小说
  Future<List<NovelSummary>> searchNovels(String query) async {
    if (query.isEmpty) {
      return getNovels();
    }
    
    try {
      // 使用API搜索小说
      final novels = await apiService.searchNovelsByTitle(query);
      
      // 转换为NovelSummary列表
      return novels.map((novel) => NovelSummary(
        id: novel.id,
        title: novel.title,
        coverImagePath: novel.coverImagePath,
        lastEditTime: novel.updatedAt,
        wordCount: novel.wordCount,
        completionPercentage: 0.0, // 需要计算或从后端获取
      )).toList();
    } catch (e) {
      // 如果API搜索失败，尝试本地搜索
      final novels = await getNovels();
      
      // 本地过滤
      return novels.where((novel) => 
        novel.title.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
  }
  
  // 创建新小说
  Future<NovelSummary> createNovel(String title, {String? seriesName}) async {
    try {
      // 创建新小说
      final newNovel = await apiService.createNovel(title, description: '');
      
      // 转换为NovelSummary
      return NovelSummary(
        id: newNovel.id,
        title: newNovel.title,
        coverImagePath: newNovel.coverImagePath,
        lastEditTime: newNovel.updatedAt,
        wordCount: newNovel.wordCount,
        seriesName: seriesName ?? '',
        completionPercentage: 0.0,
      );
    } catch (e) {
      print('创建小说失败: $e');
      
      // 如果使用模拟数据，使用mock数据创建
      if (AppConfig.shouldUseMockData) {
        final newNovel = MockData.createNovel(title, seriesName: seriesName);
        
        // 添加到本地存储
        final novels = await getNovels();
        novels.add(newNovel);
        await localStorageService.saveNovelSummaries(novels);
        
        return newNovel;
      }
      
      throw Exception('创建小说失败: $e');
    }
  }
  
  // 删除小说
  Future<void> deleteNovel(String id) async {
    try {
      // 从API删除
      await apiService.deleteNovel(id);
      
      // 从本地存储中删除
      final novels = await getNovels();
      final updatedNovels = novels.where((novel) => novel.id != id).toList();
      await localStorageService.saveNovelSummaries(updatedNovels);
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
    try {
      // 从API获取小说详情
      final novel = await apiService.fetchNovel(novelId);
      
      // 转换为Novel模型
      return Novel(
        id: novel.id,
        title: novel.title,
        description: '', // 需要从后端获取
        wordCount: novel.wordCount,
        chapterCount: novel.acts.fold(0, (sum, act) => sum + act.chapters.length),
        createdAt: novel.createdAt,
        updatedAt: novel.updatedAt,
      );
    } catch (e) {
      print('获取小说详情失败: $e');
      
      // 如果使用模拟数据，返回模拟数据
      if (AppConfig.shouldUseMockData) {
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
      
      throw Exception('获取小说详情失败: $e');
    }
  }
  
  // 获取章节详情
  Future<Chapter> getChapterById(String novelId, String chapterId) async {
    try {
      // 从API获取小说详情
      final novel = await apiService.fetchNovel(novelId);
      
      // 查找章节
      Chapter? chapter;
      for (final act in novel.acts) {
        for (final ch in act.chapters) {
          if (ch.id == chapterId) {
            // 找到章节，获取场景内容
            final scenes = await Future.wait(ch.scenes.map((scene) async {
              try {
                return await apiService.fetchSceneContent(novelId, act.id, ch.id, scene.id);
              } catch (e) {
                print('获取场景内容失败: $e');
                return scene;
              }
            }));
            
            // 创建章节对象
            chapter = Chapter(
              id: ch.id,
              title: ch.title,
              order: ch.order,
              wordCount: scenes.fold(0, (sum, scene) => sum + scene.wordCount),
              summary: '章节摘要', // 需要从后端获取
              createdAt: novel.createdAt,
              updatedAt: novel.updatedAt,
            );
            break;
          }
        }
        if (chapter != null) break;
      }
      
      if (chapter != null) {
        return chapter;
      }
      
      throw Exception('章节不存在');
    } catch (e) {
      print('获取章节详情失败: $e');
      
      // 如果使用模拟数据，返回模拟数据
      if (AppConfig.shouldUseMockData) {
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
      
      throw Exception('获取章节详情失败: $e');
    }
  }
  
  // 获取前一章节
  Future<Chapter?> getPreviousChapter(String novelId, int currentOrder) async {
    if (currentOrder <= 1) {
      return null;
    }
    
    try {
      // 从API获取小说详情
      final novel = await apiService.fetchNovel(novelId);
      
      // 查找前一章节
      Chapter? previousChapter;
      for (final act in novel.acts) {
        for (final ch in act.chapters) {
          if (ch.order == currentOrder - 1) {
            previousChapter = Chapter(
              id: ch.id,
              title: ch.title,
              order: ch.order,
              wordCount: 0, // 需要计算或从后端获取
              summary: '章节摘要', // 需要从后端获取
              createdAt: novel.createdAt,
              updatedAt: novel.updatedAt,
            );
            break;
          }
        }
        if (previousChapter != null) break;
      }
      
      return previousChapter;
    } catch (e) {
      print('获取前一章节失败: $e');
      
      // 如果使用模拟数据，返回模拟数据
      if (AppConfig.shouldUseMockData) {
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
      
      return null;
    }
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