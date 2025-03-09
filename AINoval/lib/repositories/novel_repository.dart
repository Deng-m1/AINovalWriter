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
    try {
      // 先尝试从本地加载
      final localNovels = await localStorageService.getNovels();
      
      // 如果本地有缓存数据，先返回本地数据
      if (localNovels.isNotEmpty) {
        return localNovels;
      }

      // 尝试从服务器获取最新数据
      // 在第一迭代中，使用mock数据
      final remoteNovels = MockData.getNovels();
      
      // 更新本地存储
      await localStorageService.saveNovels(remoteNovels);
      
      return remoteNovels;
    } catch (e) {
      // 出现异常时使用mock数据
      final mockNovels = MockData.getNovels();
      return mockNovels;
    }
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
      await localStorageService.saveNovels(novels);
      
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
      await localStorageService.saveNovels(updatedNovels);
      
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
      await localStorageService.saveNovels(novels);
      
      return importedNovel;
    } catch (e) {
      throw Exception('导入小说失败: $e');
    }
  }
} 