import 'dart:convert';

import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // Import uuid package
import 'package:hive/hive.dart';

import '../models/chat_models.dart';

/// 本地存储服务，用于缓存和获取小说数据
class LocalStorageService {
  SharedPreferences? _prefs;
  final Uuid _uuid = const Uuid(); // For generating unique local IDs

  // 添加小说缓存
  final Map<String, novel_models.Novel> _novelCache = {};
  final Map<String, DateTime> _novelCacheTimestamp = {};
  final Duration _cacheTTL = const Duration(minutes: 5); // 缓存有效期
  final Map<String, String> _wordCountCache = {}; // 场景字数缓存

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

  // --- New Key for Pending Messages ---
  static const String _pendingMessagesKey = 'pending_chat_messages';

  // 获取所有小说
  Future<List<novel_models.Novel>> getNovels() async {
    final prefs = await _ensureInitialized();
    final novelsJson = prefs.getStringList(_novelsKey) ?? [];
/*     AppLogger.d('LocalStorageService',
        'getNovels: Raw JSON list from prefs: $novelsJson');
 */
    try {
      final novels = novelsJson.map((json) {
        // AppLogger.v('LocalStorageService', 'getNovels: Parsing JSON: $json');
        final novel = novel_models.Novel.fromJson(jsonDecode(json));
        AppLogger.v('LocalStorageService',
            'getNovels: Parsed Novel: ID=${novel.id}, Title=${novel.title}, Acts=${novel.acts.length}');
        return novel;
      }).toList();
      AppLogger.i('LocalStorageService',
          'getNovels: Successfully parsed ${novels.length} novels.');
      return novels;
    } catch (e, stackTrace) {
      AppLogger.e('LocalStorageService',
          'getNovels: Failed to parse novels JSON.', e, stackTrace);
      return [];
    }
  }

  // 保存所有小说
  Future<void> saveNovels(List<novel_models.Novel> novels) async {
    final prefs = await _ensureInitialized();
    try {
      final novelsJson = novels.map((novel) {
        final jsonMap = novel.toJson();
        final jsonString = jsonEncode(jsonMap);
        AppLogger.v('LocalStorageService',
            'saveNovels: Serializing Novel ID=${novel.id}, Title=${novel.title}, Acts=${novel.acts.length}');
        return jsonString;
      }).toList();

/*       AppLogger.d('LocalStorageService',
          'saveNovels: Saving JSON list to prefs: $novelsJson'); */
      await prefs.setStringList(_novelsKey, novelsJson);
      AppLogger.i('LocalStorageService',
          'saveNovels: Successfully saved ${novels.length} novels.');
    } catch (e, stackTrace) {
      AppLogger.e('LocalStorageService', 'saveNovels: Failed to save  novels.',
          e, stackTrace);
    }
  }

  // 保存小说摘要列表
  Future<void> saveNovelSummaries(List<NovelSummary> novels) async {
    final prefs = await _ensureInitialized();
    final novelsJson =
        novels.map((novel) => jsonEncode(novel.toJson())).toList();

    await prefs.setStringList('novel_summaries', novelsJson);
  }

  // 获取单个小说
  Future<novel_models.Novel?> getNovel(String id) async {
    AppLogger.d('LocalStorageService',
        'getNovel: Attempting to get novel with ID: $id');
    
    // 检查缓存是否存在且有效
    if (_novelCache.containsKey(id)) {
      final cacheTime = _novelCacheTimestamp[id];
      if (cacheTime != null && DateTime.now().difference(cacheTime) < _cacheTTL) {
        AppLogger.i('LocalStorageService',
            'getNovel: Using cached novel: ID=$id, Title=${_novelCache[id]!.title}, Acts=${_novelCache[id]!.acts.length}');
        return _novelCache[id];
      }
    }
    
    // 缓存不存在或已过期，从存储获取
    final novels = await getNovels();
    try {
      final novel = novels.firstWhere(
        (novel) => novel.id == id,
      );
      
      // 更新缓存
      _novelCache[id] = novel;
      _novelCacheTimestamp[id] = DateTime.now();
      
      AppLogger.i('LocalStorageService',
          'getNovel: Found novel: ID=${novel.id}, Title=${novel.title}, Acts=${novel.acts.length}');
      return novel;
    } catch (e) {
      AppLogger.w(
          'LocalStorageService', 'getNovel: Novel with ID $id not found.', e);
      return null;
    }
  }

  // 保存单个小说
  Future<void> saveNovel(novel_models.Novel novel) async {
    //AppLogger.d('LocalStorageService',
    //    'saveNovel: Attempting to save novel ID=${novel.id}, Title=${novel.title}, Acts=${novel.acts.length}');
    
    // 检查上次保存时间，如果短时间内多次保存同一个小说，可以合并为一次操作
    final cacheTime = _novelCacheTimestamp[novel.id];
    final now = DateTime.now();
    if (cacheTime != null && now.difference(cacheTime).inMilliseconds < 500) {
      // 如果500毫秒内有多次保存，只更新缓存，延迟实际的存储操作
      _novelCache[novel.id] = novel;
      _novelCacheTimestamp[novel.id] = now;
      //AppLogger.i('LocalStorageService',
      //    'saveNovel: Multiple saves detected within 500ms, delaying actual storage operation for novel ID=${novel.id}');
      return;
    }
    
    // 更新缓存
    _novelCache[novel.id] = novel;
    _novelCacheTimestamp[novel.id] = now;
    
    try {
      final novels = await getNovels();
      final index = novels.indexWhere((n) => n.id == novel.id);

      if (index >= 0) {
        AppLogger.d('LocalStorageService',
            'saveNovel: Updating existing novel at index $index.');
        novels[index] = novel;
      } else {
        AppLogger.d('LocalStorageService', 'saveNovel: Adding new novel.');
        novels.add(novel);
      }

      await saveNovels(novels);
      AppLogger.i('LocalStorageService',
          'saveNovel: Completed saving process for novel ID=${novel.id}.');
    } catch (e) {
      AppLogger.e('LocalStorageService', 'saveNovel: Failed to save novel', e);
      // 从缓存中移除，以便下次重新加载
      _novelCache.remove(novel.id);
      _novelCacheTimestamp.remove(novel.id);
      throw Exception('保存小说失败: $e');
    }
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
    final previousId = prefs.getString(_currentNovelKey);
    
    // 如果前一个小说ID存在且与新ID不同，清理前一个小说的同步标记
    if (previousId != null && previousId.isNotEmpty && previousId != id) {
      AppLogger.i('LocalStorageService', '小说ID切换: $previousId -> $id');
      
      // 如果是设置为空ID（特殊情况，如app关闭），不触发清理
      if (id.isNotEmpty) {
        await clearNovelSyncFlags(previousId);
      }
    }
    
    await prefs.setString(_currentNovelKey, id);
    AppLogger.i('LocalStorageService', '当前小说ID已设置为: $id');
  }

  // 获取章节内容
  Future<EditorContent?> getChapterContent(
      String novelId, String chapterId) async {
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
      AppLogger.e('LocalStorageService', '解析章节内容失败', e);
      return null;
    }
  }

  // 保存章节内容
  Future<void> saveChapterContent(
      String novelId, String chapterId, EditorContent content) async {
    final prefs = await _ensureInitialized();
    final key = _getContentKey(novelId, chapterId);
    final jsonString = jsonEncode(content.toJson());

    await prefs.setString(key, jsonString);
  }

  // 获取编辑器内容
  Future<EditorContent?> getEditorContent(
      String novelId, String chapterId, String sceneId) async {
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
      final prefs = await _ensureInitialized();
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
      AppLogger.e('LocalStorageService', '获取编辑器设置失败', e);
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
      final prefs = await _ensureInitialized();
      await prefs.setString('editor_settings', jsonEncode(settings));
    } catch (e) {
      AppLogger.e('LocalStorageService', '保存编辑器设置失败', e);
      throw Exception('保存编辑器设置失败: $e');
    }
  }

  // 生成内容存储键
  String _getContentKey(String novelId, String chapterId) {
    return '$_editorContentPrefix${novelId}_$chapterId';
  }

  /// 获取场景内容
  Future<novel_models.Scene?> getSceneContent(
      String novelId, String actId, String chapterId, String sceneId) async {
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
  Future<void> saveSceneContent(String novelId, String actId, String chapterId,
      String sceneId, novel_models.Scene scene) async {
    try {
      // 生成场景缓存键
      final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
      
      // 如果缓存中有小说，则直接更新缓存中的场景内容
      if (_novelCache.containsKey(novelId)) {
        final novel = _novelCache[novelId]!;
        bool sceneUpdated = false;
        
        // 查找并更新缓存中的场景
        final updatedActs = novel.acts.map((act) {
          if (act.id == actId) {
            final updatedChapters = act.chapters.map((chapter) {
              if (chapter.id == chapterId) {
                final sceneIndex = chapter.scenes.indexWhere((s) => s.id == sceneId);
                if (sceneIndex >= 0) {
                  // 更新现有场景
                  final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
                  updatedScenes[sceneIndex] = scene;
                  sceneUpdated = true;
                  return chapter.copyWith(scenes: updatedScenes);
                } else {
                  // 添加新场景
                  sceneUpdated = true;
                  return chapter.copyWith(
                    scenes: [...chapter.scenes, scene],
                  );
                }
              }
              return chapter;
            }).toList();
            
            if (sceneUpdated) {
              return act.copyWith(chapters: updatedChapters);
            }
          }
          return act;
        }).toList();
        
        if (sceneUpdated) {
          // 更新缓存中的小说
          final updatedNovel = novel.copyWith(
            acts: updatedActs,
            updatedAt: DateTime.now(),
          );
          
          _novelCache[novelId] = updatedNovel;
          _novelCacheTimestamp[novelId] = DateTime.now();
          
          // 更新字数缓存
          _updateWordCountCache(sceneKey, scene.content, scene.wordCount);
          
          AppLogger.i('LocalStorageService',
              'saveSceneContent: Updated scene in cached novel: $sceneKey');
        }
      }

      // 正常保存场景到存储
      final novel = await getNovel(novelId);
      if (novel == null) return;

      final acts = novel.acts.map((act) {
        if (act.id == actId) {
          final chapters = act.chapters.map((chapter) {
            if (chapter.id == chapterId) {
              // 查找特定场景
              final sceneIndex =
                  chapter.scenes.indexWhere((s) => s.id == sceneId);
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
      
      // 更新字数缓存
      _updateWordCountCache(sceneKey, scene.content, scene.wordCount);
    } catch (e) {
      AppLogger.e('LocalStorageService', '保存场景内容失败', e);
    }
  }

  /// 保存摘要内容
  Future<void> saveSummary(String novelId, String actId, String chapterId,
      String sceneId, novel_models.Summary summary) async {
    try {
      final novel = await getNovel(novelId);
      if (novel == null) return;

      final acts = novel.acts.map((act) {
        if (act.id == actId) {
          final chapters = act.chapters.map((chapter) {
            if (chapter.id == chapterId) {
              // 查找特定场景
              final sceneIndex =
                  chapter.scenes.indexWhere((s) => s.id == sceneId);
              List<novel_models.Scene> updatedScenes;

              if (sceneIndex >= 0) {
                // 更新现有场景
                updatedScenes = List.from(chapter.scenes);
                updatedScenes[sceneIndex] =
                    updatedScenes[sceneIndex].copyWith(summary: summary);
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
      AppLogger.e('LocalStorageService', '保存摘要内容失败', e);
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
        AppLogger.i('LocalStorageService', '已标记 $type: $id 需要同步');
      }
    } catch (e) {
      AppLogger.e('LocalStorageService', '标记同步失败', e);
    }
  }

  // 获取需要同步的内容列表（按类型）
  Future<List<String>> getSyncList(String type) async {
    try {
      final prefs = await _ensureInitialized();
      final syncKey = 'syncList_$type';
      return prefs.getStringList(syncKey) ?? [];
    } catch (e) {
      AppLogger.e('LocalStorageService', '获取同步列表失败', e);
      return [];
    }
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
        AppLogger.i('LocalStorageService', '已清除 $type: $id 的同步标记');
      }
    } catch (e) {
      AppLogger.e('LocalStorageService', '清除同步标记失败', e);
    }
  }

  // 保存聊天会话列表
  Future<void> saveChatSessions(
      String novelId, List<ChatSession> sessions) async {
    final key = 'chat_sessions_$novelId';
    final jsonList =
        sessions.map((session) => jsonEncode(session.toJson())).toList();
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
  Future<void> addChatSession(String novelId, ChatSession session,
      {bool needsSync = false}) async {
    final sessions = await getChatSessions(novelId);
    sessions.add(session);

    await saveChatSessions(novelId, sessions);

    await updateChatSession(session, needsSync: needsSync);
  }

  // 获取特定会话
  Future<ChatSession?> getChatSession(String sessionId) async {
    final key = 'chat_session_detail_$sessionId';
    final prefs = await _ensureInitialized();
    final json = prefs.getString(key);

    if (json == null) {
      return null;
    }

    return ChatSession.fromJson(jsonDecode(json));
  }

  // 更新会话 - 同时处理标记同步
  Future<void> updateChatSession(ChatSession session,
      {bool needsSync = false}) async {
    final key = 'chat_session_detail_${session.id}';
    final prefs = await _ensureInitialized();
    await prefs.setString(key, jsonEncode(session.toJson()));

    if (needsSync) {
      await markForSyncByType(session.id, 'chat_session');
    }
  }

  // 删除会话
  Future<void> deleteChatSession(String sessionId) async {
    final key = 'chat_session_detail_$sessionId';
    final prefs = await _ensureInitialized();
    await prefs.remove(key);

    await clearSyncFlagByType('chat_session', sessionId);
  }

  // 获取需要同步的所有会话
  Future<List<ChatSession>> getSessionsToSync() async {
    final syncList = await getSyncList('chat_session');
    final sessions = <ChatSession>[];

    for (final sessionId in syncList) {
      final session = await getChatSession(sessionId);
      if (session != null) {
        sessions.add(session);
      } else {
        AppLogger.w('LocalStorageService',
            'getSessionsToSync: 未找到标记为同步的会话详情: $sessionId。考虑清除此标记。');
      }
    }

    return sessions;
  }

  // 清除所有数据
  Future<void> clearAll() async {
    final prefs = await _ensureInitialized();
    await prefs.clear();
  }

  /// 获取会话的消息列表（用于显示历史记录）
  Future<List<ChatMessage>?> getMessagesForSession(String sessionId) async {
    final prefs = await _ensureInitialized();
    final key = 'chat_messages_$sessionId'; // Key for storing full history
    final jsonList = prefs.getStringList(key);
    if (jsonList == null) return null;
    try {
      // Sort messages by timestamp after parsing
      final messages = jsonList
          .map((json) => ChatMessage.fromJson(jsonDecode(json)))
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e, stackTrace) {
      AppLogger.e(
          'LocalStorageService', '解析会话 $sessionId 的消息失败', e, stackTrace);
      return null;
    }
  }

  /// 保存会话的消息列表（用于缓存历史记录）
  Future<void> saveMessagesForSession(
      String sessionId, List<ChatMessage> messages) async {
    final prefs = await _ensureInitialized();
    final key = 'chat_messages_$sessionId'; // Key for storing full history
    // Sort messages by timestamp before saving
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final jsonList = messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await prefs.setStringList(key, jsonList);
  }

  /// 添加单条消息到会话历史（例如，收到新消息或发送成功后）
  Future<void> addMessageToSessionHistory(
      String sessionId, ChatMessage message) async {
    final messages = await getMessagesForSession(sessionId) ?? [];
    // Avoid duplicates if message already exists
    if (!messages.any((m) => m.id == message.id)) {
      messages.add(message);
      await saveMessagesForSession(sessionId, messages);
    }
  }

  /// 添加待发送消息到队列
  Future<String> addPendingMessage({
    required String userId,
    required String sessionId,
    required String content,
    required Map<String, dynamic>? metadata,
  }) async {
    final prefs = await _ensureInitialized();
    final pendingList = prefs.getStringList(_pendingMessagesKey) ?? [];
    final localId = _uuid.v4(); // Generate unique local ID

    final pendingMessageData = {
      'localId': localId, // Unique ID for removal later
      'userId': userId,
      'sessionId': sessionId,
      'content': content,
      'metadata': metadata,
      'timestamp':
          DateTime.now().toIso8601String(), // Store time added to queue
    };

    pendingList.add(jsonEncode(pendingMessageData));
    await prefs.setStringList(_pendingMessagesKey, pendingList);
    AppLogger.i('LocalStorageService',
        '添加待发送消息到队列: sessionId=$sessionId, localId=$localId');
    return localId; // Return localId in case UI needs it
  }

  /// 获取所有待发送消息
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final prefs = await _ensureInitialized();
    final jsonList = prefs.getStringList(_pendingMessagesKey) ?? [];
    try {
      return jsonList
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e('LocalStorageService', '解析待发送消息队列失败', e, stackTrace);
      // Optionally clear the corrupted queue
      // await prefs.remove(_pendingMessagesKey);
      return [];
    }
  }

  /// 从队列中移除已发送的消息 (通过 localId)
  Future<void> removePendingMessage(String localId) async {
    final prefs = await _ensureInitialized();
    final pendingList = prefs.getStringList(_pendingMessagesKey) ?? [];
    final updatedList = <String>[];
    bool removed = false;

    for (final jsonString in pendingList) {
      try {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        if (data['localId'] != localId) {
          updatedList.add(jsonString);
        } else {
          removed = true;
        }
      } catch (e) {
        // Skip corrupted entry
        AppLogger.w('LocalStorageService', '移除待发送消息时跳过损坏条目: $e');
      }
    }

    if (removed) {
      await prefs.setStringList(_pendingMessagesKey, updatedList);
      AppLogger.i('LocalStorageService', '从队列移除待发送消息: localId=$localId');
    } else {
      AppLogger.w('LocalStorageService', '尝试移除待发送消息，但未找到: localId=$localId');
    }
  }

  // 清理所有同步标记
  Future<void> clearAllSyncFlags() async {
    final prefs = await _ensureInitialized();
    final syncTypes = ['novel', 'scene', 'editor', 'chat_session'];
    
    for (final type in syncTypes) {
      final syncKey = 'syncList_$type';
      await prefs.remove(syncKey);
    }
    
    AppLogger.i('LocalStorageService', '已清理所有同步标记');
  }
  
  // 清理指定小说的同步标记
  Future<void> clearNovelSyncFlags(String novelId) async {
    if (novelId.isEmpty) return;
    
    final prefs = await _ensureInitialized();
    
    // 清理小说本身的同步标记
    const novelSyncKey = 'syncList_novel';
    final novelSyncList = prefs.getStringList(novelSyncKey) ?? [];
    if (novelSyncList.contains(novelId)) {
      novelSyncList.remove(novelId);
      await prefs.setStringList(novelSyncKey, novelSyncList);
      AppLogger.i('LocalStorageService', '已清理小说同步标记: $novelId');
    }
    
    // 清理场景同步标记
    const sceneSyncKey = 'syncList_scene';
    final sceneSyncList = prefs.getStringList(sceneSyncKey) ?? [];
    final updatedSceneSyncList = sceneSyncList.where((sceneKey) {
      final parts = sceneKey.split('_');
      return parts.isEmpty || parts[0] != novelId;
    }).toList();
    
    if (updatedSceneSyncList.length != sceneSyncList.length) {
      await prefs.setStringList(sceneSyncKey, updatedSceneSyncList);
      AppLogger.i('LocalStorageService', 
        '已清理场景同步标记: ${sceneSyncList.length - updatedSceneSyncList.length} 个场景，小说ID: $novelId');
    }
    
    // 清理编辑器内容同步标记
    const editorSyncKey = 'syncList_editor';
    final editorSyncList = prefs.getStringList(editorSyncKey) ?? [];
    final updatedEditorSyncList = editorSyncList.where((contentKey) {
      final parts = contentKey.split('_');
      return parts.isEmpty || parts[0] != novelId;
    }).toList();
    
    if (updatedEditorSyncList.length != editorSyncList.length) {
      await prefs.setStringList(editorSyncKey, updatedEditorSyncList);
      AppLogger.i('LocalStorageService', 
        '已清理编辑器内容同步标记: ${editorSyncList.length - updatedEditorSyncList.length} 个内容，小说ID: $novelId');
    }
    
    // 清理聊天会话同步标记
    // 注意：这需要先获取所有会话，然后检查它们的metadata中的novelId
    final sessions = await getSessionsToSync();
    final sessionsToRemove = sessions.where((session) => 
      session.metadata != null && session.metadata!['novelId'] == novelId).toList();
    
    for (final session in sessionsToRemove) {
      await clearSyncFlagByType('chat_session', session.id);
      AppLogger.i('LocalStorageService', '已清理聊天会话同步标记: ${session.id}，小说ID: $novelId');
    }
  }

  /// 获取指定章节的所有场景键
  Future<List<String>> getSceneKeysForChapter(
    String novelId,
    String actId,
    String chapterId,
  ) async {
    try {
      final box = await Hive.openBox('scenes');
      final prefix = '${novelId}_${actId}_${chapterId}_';
      
      // 过滤出所有属于该章节的场景键
      final List<String> sceneKeys = [];
      for (final key in box.keys) {
        if (key is String && key.startsWith(prefix)) {
          // 从键中提取场景ID
          final sceneId = key.substring(prefix.length);
          sceneKeys.add(sceneId);
        }
      }
      
      return sceneKeys;
    } catch (e) {
      AppLogger.e('LocalStorageService', '获取章节场景键失败', e);
      return [];
    }
  }

  /// 删除场景内容
  Future<void> deleteSceneContent(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
  ) async {
    final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
    try {
      // 使用SharedPreferences删除场景内容
      final prefs = await _ensureInitialized();
      await prefs.remove('scene_$sceneKey');
      
      // 从场景索引中移除
      final indexKey = 'scenes_index_${novelId}_${actId}_$chapterId';
      final sceneIds = prefs.getStringList(indexKey) ?? [];
      if (sceneIds.contains(sceneId)) {
        sceneIds.remove(sceneId);
        await prefs.setStringList(indexKey, sceneIds);
      }
      
      AppLogger.i('LocalStorageService', '本地场景内容已删除: $sceneKey');
    } catch (e) {
      AppLogger.e('LocalStorageService', '删除场景内容失败: $sceneKey', e);
      throw Exception('删除场景内容失败: $e');
    }
  }

  // 优化的字数统计缓存
  void _updateWordCountCache(String sceneKey, String content, int wordCount) {
    final contentHash = content.hashCode.toString();
    final cacheKey = '${sceneKey}_$contentHash';
    _wordCountCache[cacheKey] = wordCount.toString();
  }
  
  // 从缓存获取字数统计
  int? getWordCountFromCache(String sceneKey, String content) {
    final contentHash = content.hashCode.toString();
    final cacheKey = '${sceneKey}_$contentHash';
    final cachedCount = _wordCountCache[cacheKey];
    if (cachedCount != null) {
      return int.tryParse(cachedCount);
    }
    return null;
  }
  
  // 清除指定小说的缓存
  Future<void> clearNovelCache(String novelId) async {
    AppLogger.i('LocalStorageService', '清除小说缓存: $novelId');
    _novelCache.remove(novelId);
    _novelCacheTimestamp.remove(novelId);
  }

  // 清除所有小说缓存
  Future<void> clearAllNovelCache() async {
    AppLogger.i('LocalStorageService', '清除所有小说缓存');
    _novelCache.clear();
    _novelCacheTimestamp.clear();
  }
}
