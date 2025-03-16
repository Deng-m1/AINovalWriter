import 'dart:convert';

import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

/// 本地存储服务，用于缓存和获取小说数据
class LocalStorageService {
  SharedPreferences? _prefs;
  
  // 初始化
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  // 确保已初始化
  Future<SharedPreferences> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }
  
  // 存储键
  static const String _novelsKey = 'novels';
  static const String _currentNovelKey = 'current_novel';
  static const String _editorContentPrefix = 'editor_content_';
  static const String _editorSettingsKey = 'editor_settings';
  
  // 获取所有小说
  Future<List<novel_models.Novel>> getNovels() async {
    final prefs = await _ensureInitialized();
    final novelsJson = prefs.getStringList(_novelsKey) ?? [];
    
    return novelsJson
        .map((json) => novel_models.Novel.fromJson(jsonDecode(json)))
        .toList();
  }
  
  // 保存所有小说
  Future<void> saveNovels(List<novel_models.Novel> novels) async {
    final prefs = await _ensureInitialized();
    final novelsJson = novels
        .map((novel) => jsonEncode(novel.toJson()))
        .toList();
    
    await prefs.setStringList(_novelsKey, novelsJson);
  }
  
  // 保存小说摘要列表
  Future<void> saveNovelSummaries(List<NovelSummary> novels) async {
    final prefs = await _ensureInitialized();
    final novelsJson = novels
        .map((novel) => jsonEncode(novel.toJson()))
        .toList();
    
    await prefs.setStringList('novel_summaries', novelsJson);
  }
  
  // 获取单个小说
  Future<novel_models.Novel?> getNovel(String id) async {
    final novels = await getNovels();
    try {
      return novels.firstWhere(
        (novel) => novel.id == id,
      );
    } catch (e) {
      return null;
    }
  }
  
  // 保存单个小说
  Future<void> saveNovel(novel_models.Novel novel) async {
    final novels = await getNovels();
    final index = novels.indexWhere((n) => n.id == novel.id);
    
    if (index >= 0) {
      novels[index] = novel;
    } else {
      novels.add(novel);
    }
    
    await saveNovels(novels);
  }
  
  // 删除小说
  Future<void> deleteNovel(String id) async {
    final novels = await getNovels();
    novels.removeWhere((novel) => novel.id == id);
    await saveNovels(novels);
  }
  
  // 获取当前正在编辑的小说ID
  Future<String?> getCurrentNovelId() async {
    final prefs = await _ensureInitialized();
    return prefs.getString(_currentNovelKey);
  }
  
  // 设置当前正在编辑的小说ID
  Future<void> setCurrentNovelId(String id) async {
    final prefs = await _ensureInitialized();
    await prefs.setString(_currentNovelKey, id);
  }
  
  // 获取章节内容
  Future<EditorContent?> getChapterContent(String novelId, String chapterId) async {
    final prefs = await _ensureInitialized();
    final key = _getContentKey(novelId, chapterId);
    final jsonString = prefs.getString(key);
    
    if (jsonString == null) {
      return null;
    }
    
    try {
      final json = jsonDecode(jsonString);
      return EditorContent.fromJson(json);
    } catch (e) {
      print('解析章节内容失败: $e');
      return null;
    }
  }
  
  // 保存章节内容
  Future<void> saveChapterContent(String novelId, String chapterId, EditorContent content) async {
    final prefs = await _ensureInitialized();
    final key = _getContentKey(novelId, chapterId);
    final jsonString = jsonEncode(content.toJson());
    
    await prefs.setString(key, jsonString);
  }
  
  // 获取编辑器内容
  Future<EditorContent?> getEditorContent(String novelId, String chapterId, String sceneId) async {
    return getChapterContent(novelId, chapterId);
  }
  
  // 保存编辑器内容
  Future<void> saveEditorContent(EditorContent content) async {
    final parts = content.id.split('-');
    if (parts.length == 3) {
      final novelId = parts[0];
      final chapterId = parts[1];
      final sceneId = parts[2];
      await saveChapterContent(novelId, chapterId, content);
    } else if (parts.length == 2) {
      // 兼容旧格式
      final novelId = parts[0];
      final chapterId = parts[1];
      await saveChapterContent(novelId, chapterId, content);
    }
  }
  
  // 获取编辑器设置
  Future<Map<String, dynamic>> getEditorSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('editor_settings');
      
      if (settingsJson != null) {
        return jsonDecode(settingsJson) as Map<String, dynamic>;
      }
      
      // 返回默认设置
      return {
        'fontSize': 16.0,
        'lineHeight': 1.5,
        'fontFamily': 'Roboto',
        'theme': 'light',
        'autoSave': true,
      };
    } catch (e) {
      print('获取编辑器设置失败: $e');
      // 返回默认设置
      return {
        'fontSize': 16.0,
        'lineHeight': 1.5,
        'fontFamily': 'Roboto',
        'theme': 'light',
        'autoSave': true,
      };
    }
  }
  
  // 保存编辑器设置
  Future<void> saveEditorSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('editor_settings', jsonEncode(settings));
    } catch (e) {
      print('保存编辑器设置失败: $e');
      throw Exception('保存编辑器设置失败: $e');
    }
  }
  
  // 生成内容存储键
  String _getContentKey(String novelId, String chapterId) {
    return '$_editorContentPrefix${novelId}_$chapterId';
  }
  
  /// 获取场景内容
  Future<novel_models.Scene?> getSceneContent(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId
  ) async {
    try {
      final novel = await getNovel(novelId);
      if (novel == null) return null;
      
      final act = novel.acts.firstWhere((a) => a.id == actId);
      final chapter = act.chapters.firstWhere((c) => c.id == chapterId);
      
      if (chapter.scenes.isEmpty) return null;
      
      // 查找特定场景
      try {
        return chapter.scenes.firstWhere((s) => s.id == sceneId);
      } catch (e) {
        // 如果找不到特定场景，返回第一个场景
        return chapter.scenes.first;
      }
    } catch (e) {
      return null;
    }
  }
  
  /// 保存场景内容
  Future<void> saveSceneContent(
    String novelId, 
    String actId, 
    String chapterId, 
    String sceneId,
    novel_models.Scene scene
  ) async {
    try {
      final novel = await getNovel(novelId);
      if (novel == null) return;
      
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
                updatedScenes[sceneIndex] = scene;
              } else {
                // 添加新场景
                updatedScenes = List.from(chapter.scenes)..add(scene);
              }
              
              return chapter.copyWith(scenes: updatedScenes);
            }
            return chapter;
          }).toList();
          
          return act.copyWith(chapters: chapters);
        }
        return act;
      }).toList();
      
      final updatedNovel = novel.copyWith(
        acts: acts,
        updatedAt: DateTime.now(),
      );
      
      await saveNovel(updatedNovel);
    } catch (e) {
      print('保存场景内容失败: $e');
    }
  }
  
  /// 保存摘要内容
  Future<void> saveSummary(
    String novelId, 
    String actId, 
    String chapterId, 
    String sceneId,
    novel_models.Summary summary
  ) async {
    try {
      final novel = await getNovel(novelId);
      if (novel == null) return;
      
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
      
      final updatedNovel = novel.copyWith(
        acts: acts,
        updatedAt: DateTime.now(),
      );
      
      await saveNovel(updatedNovel);
    } catch (e) {
      print('保存摘要内容失败: $e');
    }
  }
  
  // 标记需要同步的内容（按类型）
  Future<void> markForSyncByType(String id, String type) async {
    try {
      final prefs = await _ensureInitialized();
      final syncKey = 'syncList_$type';
      final syncList = prefs.getStringList(syncKey) ?? [];
      
      if (!syncList.contains(id)) {
        syncList.add(id);
        await prefs.setStringList(syncKey, syncList);
        print('已标记 $type: $id 需要同步');
      }
    } catch (e) {
      print('标记同步失败: $e');
    }
  }
  
  // 获取需要同步的内容列表（按类型）
  Future<List<String>> getSyncList(String type) async {
    try {
      final prefs = await _ensureInitialized();
      final syncKey = 'syncList_$type';
      return prefs.getStringList(syncKey) ?? [];
    } catch (e) {
      print('获取同步列表失败: $e');
      return [];
    }
  }
  
  // 清除同步标记
  Future<void> clearSyncFlag(String sessionId) async {
    final syncList = await _getSyncList();
    syncList.remove(sessionId);
    await _saveSyncList(syncList);
  }
  
  // 清除同步标记（按类型和ID）
  Future<void> clearSyncFlagByType(String type, String id) async {
    try {
      final prefs = await _ensureInitialized();
      final syncKey = 'syncList_$type';
      final syncList = prefs.getStringList(syncKey) ?? [];
      
      if (syncList.contains(id)) {
        syncList.remove(id);
        await prefs.setStringList(syncKey, syncList);
      }
    } catch (e) {
      print('清除同步标记失败: $e');
    }
  }
  
  // 标记需要同步的内容
  Future<void> markForSync(String novelId, String chapterId) async {
    try {
      final prefs = await _ensureInitialized();
      final syncList = prefs.getStringList('syncList') ?? [];
      
      if (!syncList.contains('${novelId}_$chapterId')) {
        syncList.add('${novelId}_$chapterId');
        await prefs.setStringList('syncList', syncList);
      }
    } catch (e) {
      print('标记同步失败: $e');
    }
  }
  
  // 保存聊天会话列表
  Future<void> saveChatSessions(String novelId, List<ChatSession> sessions) async {
    final key = 'chat_sessions_$novelId';
    final jsonList = sessions.map((session) => jsonEncode(session.toJson())).toList();
    final prefs = await _ensureInitialized();
    await prefs.setStringList(key, jsonList);
  }
  
  // 获取聊天会话列表
  Future<List<ChatSession>> getChatSessions(String novelId) async {
    final key = 'chat_sessions_$novelId';
    final prefs = await _ensureInitialized();
    final jsonList = prefs.getStringList(key) ?? [];
    
    return jsonList
        .map((json) => ChatSession.fromJson(jsonDecode(json)))
        .toList();
  }
  
  // 添加聊天会话
  Future<void> addChatSession(String novelId, ChatSession session, {bool needsSync = false}) async {
    final sessions = await getChatSessions(novelId);
    sessions.add(session);
    
    await saveChatSessions(novelId, sessions);
    
    if (needsSync) {
      await _markSessionForSync(session.id);
    }
  }
  
  // 获取特定会话
  Future<ChatSession?> getChatSession(String sessionId) async {
    final key = 'chat_session_$sessionId';
    final prefs = await _ensureInitialized();
    final json = prefs.getString(key);
    
    if (json == null) {
      return null;
    }
    
    return ChatSession.fromJson(jsonDecode(json));
  }
  
  // 更新会话
  Future<void> updateChatSession(ChatSession session, {bool needsSync = false}) async {
    final key = 'chat_session_${session.id}';
    final prefs = await _ensureInitialized();
    await prefs.setString(key, jsonEncode(session.toJson()));
    
    if (needsSync) {
      await _markSessionForSync(session.id);
    }
  }
  
  // 删除会话
  Future<void> deleteChatSession(String sessionId) async {
    final key = 'chat_session_$sessionId';
    final prefs = await _ensureInitialized();
    await prefs.remove(key);
    
    // 同时从需要同步的列表中移除
    final syncList = await _getSyncList();
    syncList.remove(sessionId);
    await _saveSyncList(syncList);
  }
  
  // 标记会话需要同步
  Future<void> _markSessionForSync(String sessionId) async {
    final syncList = await _getSyncList();
    if (!syncList.contains(sessionId)) {
      syncList.add(sessionId);
      await _saveSyncList(syncList);
    }
  }
  
  // 获取需要同步的会话列表
  Future<List<String>> _getSyncList() async {
    final prefs = await _ensureInitialized();
    return prefs.getStringList('chat_sessions_to_sync') ?? [];
  }
  
  // 保存需要同步的会话列表
  Future<void> _saveSyncList(List<String> syncList) async {
    final prefs = await _ensureInitialized();
    await prefs.setStringList('chat_sessions_to_sync', syncList);
  }
  
  // 获取需要同步的所有会话
  Future<List<ChatSession>> getSessionsToSync() async {
    final syncList = await _getSyncList();
    final sessions = <ChatSession>[];
    
    for (final sessionId in syncList) {
      final session = await getChatSession(sessionId);
      if (session != null) {
        sessions.add(session);
      }
    }
    
    return sessions;
  }
  
  // 清除所有数据
  Future<void> clearAll() async {
    final prefs = await _ensureInitialized();
    await prefs.clear();
  }
} 