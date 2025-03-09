import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  // 存储键
  static const String _novelsKey = 'novels';
  
  // 获取所有小说
  Future<List<NovelSummary>> getNovels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final novelsJson = prefs.getStringList(_novelsKey);
      
      if (novelsJson == null) {
        return [];
      }
      
      return novelsJson
          .map((json) => NovelSummary.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('获取本地小说失败: $e');
      return [];
    }
  }
  
  // 保存所有小说
  Future<void> saveNovels(List<NovelSummary> novels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final novelsJson = novels
          .map((novel) => jsonEncode(novel.toJson()))
          .toList();
      
      await prefs.setStringList(_novelsKey, novelsJson);
    } catch (e) {
      print('保存小说到本地失败: $e');
    }
  }
  
  // 获取编辑器设置
  Future<Map<String, dynamic>> getEditorSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('editorSettings');
      
      if (settingsJson == null) {
        return {};
      }
      
      return jsonDecode(settingsJson) as Map<String, dynamic>;
    } catch (e) {
      print('获取编辑器设置失败: $e');
      return {};
    }
  }
  
  // 保存编辑器设置
  Future<void> saveEditorSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('editorSettings', jsonEncode(settings));
    } catch (e) {
      print('保存编辑器设置失败: $e');
    }
  }
  
  // 获取章节内容
  Future<Map<String, dynamic>?> getChapterContent(String novelId, String chapterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contentString = prefs.getString('chapter_${novelId}_$chapterId');
      if (contentString == null) {
        return null;
      }
      return jsonDecode(contentString) as Map<String, dynamic>;
    } catch (e) {
      print('获取章节内容失败: $e');
      return null;
    }
  }
  
  // 保存章节内容
  Future<void> saveChapterContent(String novelId, String chapterId, Map<String, dynamic> content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chapter_${novelId}_$chapterId', jsonEncode(content));
    } catch (e) {
      print('保存章节内容失败: $e');
    }
  }
  
  // 标记需要同步的内容
  Future<void> markForSync(String novelId, String chapterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncList = prefs.getStringList('syncList') ?? [];
      
      if (!syncList.contains('${novelId}_$chapterId')) {
        syncList.add('${novelId}_$chapterId');
        await prefs.setStringList('syncList', syncList);
      }
    } catch (e) {
      print('标记同步失败: $e');
    }
  }
} 