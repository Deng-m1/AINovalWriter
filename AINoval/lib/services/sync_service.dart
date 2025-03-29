import 'dart:async';

import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';


/// 数据同步服务
/// 
/// 负责在本地数据和远程API之间同步数据，支持离线模式和冲突解决
class SyncService {
  
  SyncService({
    required this.apiService,
    required this.localStorageService,
  });
  
  final ApiService apiService;
  final LocalStorageService localStorageService;
  
  // 同步状态流
  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  
  // 当前同步状态
  SyncState _currentState = SyncState.idle();
  SyncState get currentState => _currentState;
  
  // 网络连接监听器
  StreamSubscription? _connectivitySubscription;
  
  // 自动同步定时器
  Timer? _autoSyncTimer;
  
  /// 初始化同步服务
  Future<void> init() async {
    AppLogger.i('SyncService', '初始化同步服务');
    
    // 监听网络连接状态
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      AppLogger.d('SyncService', '网络连接状态变化: ${isOnline ? "在线" : "离线"}');
      _handleConnectivityChange(isOnline);
    });
    
    // 检查当前网络状态
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    AppLogger.d('SyncService', '当前网络状态: ${isOnline ? "在线" : "离线"}');
    _handleConnectivityChange(isOnline);
    
    // 设置自动同步定时器
    _setupAutoSync();
  }
  
  /// 设置自动同步
  void _setupAutoSync() {
    AppLogger.i('SyncService', '设置自动同步定时器，每5分钟同步一次');
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_currentState.isOnline) {
        AppLogger.d('SyncService', '自动同步触发');
        syncAll();
      }
    });
  }
  
  /// 处理网络连接变化
  void _handleConnectivityChange(bool isOnline) {
    // Store the previous online state before updating
    final wasOffline = !_currentState.isOnline; 
    _updateSyncState(isOnline: isOnline);
    
    // Trigger sync only when coming back online
    if (isOnline && wasOffline) { 
      AppLogger.i('SyncService', '网络恢复，开始同步数据');
      syncAll(); // syncAll will now also handle pending messages
    }
  }
  
  /// 更新同步状态
  void _updateSyncState({
    bool? isOnline,
    bool? isSyncing,
    String? error,
    double? progress,
  }) {
    _currentState = SyncState(
      isOnline: isOnline ?? _currentState.isOnline,
      isSyncing: isSyncing ?? _currentState.isSyncing,
      error: error,
      progress: progress ?? _currentState.progress,
    );
    
    _syncStateController.add(_currentState);
    AppLogger.v('SyncService', '同步状态更新: $_currentState');
  }
  
  /// 同步所有数据
  Future<bool> syncAll() async {
    if (_currentState.isSyncing) {
      AppLogger.w('SyncService', '同步已在进行中，跳过本次同步');
      return false;
    }
    
    if (!_currentState.isOnline) {
      AppLogger.w('SyncService', '无网络连接，无法同步');
      _updateSyncState(error: '无网络连接，无法同步');
      return false;
    }
    
    try {
      AppLogger.i('SyncService', '开始全量数据同步');
      _updateSyncState(isSyncing: true, progress: 0.0, error: null); // Clear previous error

      // --- Sync Pending Messages First ---
      AppLogger.d('SyncService', '开始同步待发送消息');
      await _syncPendingMessages();
      _updateSyncState(progress: 0.1); // Adjust progress steps

      // --- Sync other data types ---
      AppLogger.d('SyncService', '开始同步小说数据');
      await _syncNovels();
      _updateSyncState(progress: 0.3);
      
      AppLogger.d('SyncService', '开始同步场景内容');
      await _syncScenes();
      _updateSyncState(progress: 0.5);
      
      AppLogger.d('SyncService', '开始同步编辑器内容');
      await _syncEditorContents();
      _updateSyncState(progress: 0.7);
      
      // Sync Chat Session METADATA (title, etc.)
      AppLogger.d('SyncService', '开始同步聊天会话元数据');
      await _syncChatSessions(); // This now only syncs metadata
      _updateSyncState(progress: 0.9); // Example progress
      
      // --- Final step, maybe sync user profile or other settings ---
       _updateSyncState(progress: 1.0); // Example finish
      
      AppLogger.i('SyncService', '全量数据同步完成');
      _updateSyncState(isSyncing: false, error: null); // Clear error on success
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('SyncService', '同步失败', e, stackTrace);
       // Preserve isOnline state, set error
      _updateSyncState(isSyncing: false, error: '同步失败: $e');
      return false;
    }
  }
  
  /// 同步小说数据
  Future<void> _syncNovels() async {
    try {
      final syncList = await localStorageService.getSyncList('novel');
      AppLogger.d('SyncService', '需要同步的小说数量: ${syncList.length}');
      
      for (final novelId in syncList) {
        final localNovel = await localStorageService.getNovel(novelId);
        if (localNovel == null) {
          AppLogger.w('SyncService', '本地小说不存在: $novelId');
          continue;
        }
        
        AppLogger.i('SyncService', '同步小说: ${localNovel.title}($novelId)');
        await apiService.updateNovel(localNovel);
        
        await localStorageService.clearSyncFlagByType('novel', novelId);
        AppLogger.d('SyncService', '小说同步完成: $novelId');
      }
    } catch (e, stackTrace) {
      AppLogger.e('SyncService', '同步小说数据失败', e, stackTrace);
      throw SyncException('同步小说数据失败: $e');
    }
  }
  
  /// 同步场景内容
  Future<void> _syncScenes() async {
    try {
      final syncList = await localStorageService.getSyncList('scene');
      AppLogger.d('SyncService', '需要同步的场景数量: ${syncList.length}');
      
      for (final sceneKey in syncList) {
        final parts = sceneKey.split('_');
        if (parts.length != 4) {
          AppLogger.w('SyncService', '无效的场景键格式: $sceneKey');
          continue;
        }
        
        final novelId = parts[0];
        final actId = parts[1];
        final chapterId = parts[2];
        final sceneId = parts[3];
        
        final localScene = await localStorageService.getSceneContent(
          novelId, actId, chapterId, sceneId);
        if (localScene == null) {
          AppLogger.w('SyncService', '本地场景不存在: $sceneKey');
          continue;
        }
        
        AppLogger.i('SyncService', '同步场景: $sceneKey');
        await apiService.updateSceneContent(
          novelId, actId, chapterId, sceneId, localScene);
        
        await localStorageService.clearSyncFlagByType('scene', sceneKey);
        AppLogger.d('SyncService', '场景同步完成: $sceneKey');
      }
    } catch (e, stackTrace) {
      AppLogger.e('SyncService', '同步场景内容失败', e, stackTrace);
      throw SyncException('同步场景内容失败: $e');
    }
  }
  
  /// 同步编辑器内容
  Future<void> _syncEditorContents() async {
    try {
      final syncList = await localStorageService.getSyncList('editor');
      AppLogger.d('SyncService', '需要同步的编辑器内容数量: ${syncList.length}');
      
      for (final contentKey in syncList) {
        final parts = contentKey.split('_');
        if (parts.length < 2) {
          AppLogger.w('SyncService', '无效的编辑器内容键格式: $contentKey');
          continue;
        }
        
        final novelId = parts[0];
        final chapterId = parts[1];
        final sceneId = parts.length > 2 ? parts[2] : '';
        
        final localContent = await localStorageService.getEditorContent(
          novelId, chapterId, sceneId);
        if (localContent == null) {
          AppLogger.w('SyncService', '本地编辑器内容不存在: $contentKey');
          continue;
        }
        
        AppLogger.i('SyncService', '同步编辑器内容: $contentKey');
        await apiService.saveEditorContent(localContent);
        
        await localStorageService.clearSyncFlagByType('editor', contentKey);
        AppLogger.d('SyncService', '编辑器内容同步完成: $contentKey');
      }
    } catch (e, stackTrace) {
      AppLogger.e('SyncService', '同步编辑器内容失败', e, stackTrace);
      throw SyncException('同步编辑器内容失败: $e');
    }
  }
  
  /// 同步聊天会话元数据 (No longer sends full message history)
  Future<void> _syncChatSessions() async {
    // This method now only syncs session metadata like title, updatedAt
    try {
      final sessions = await localStorageService.getSessionsToSync();
      AppLogger.d('SyncService', '需要同步的聊天会话元数据数量: ${sessions.length}');

      // No need for userId here if updateSession API only updates metadata
      // If updateSession *requires* userId, get it once:
      // final String currentUserId = await _getCurrentUserId(); 
      
      for (final session in sessions) {
        AppLogger.i('SyncService', '同步聊天会话元数据: ${session.id}');
        
        // Construct updates payload - only include fields managed locally
        // that need syncing (like title if user can rename offline)
        final Map<String, dynamic> updates = {
          'title': session.title,
          // Include lastUpdatedAt from local session to inform server?
          // 'updatedAt': session.lastUpdatedAt.toIso8601String(), 
          // Or maybe server handles updatedAt automatically on update?
        };

        // Only call update if there are actual updates to send
        if (updates.isNotEmpty) {
             // If updateSession requires userId, pass it: userId: currentUserId,
        await apiService.updateSession(
               userId: await _getCurrentUserId(), // Get userId if needed by API
          sessionId: session.id,
               updates: updates,
             );
        } // Else: Session might be marked for sync without local changes, skip API call?

        // REMOVED: Loop sending messages using getMessagesForSession

        await localStorageService.clearSyncFlagByType('chat_session', session.id); 
        AppLogger.d('SyncService', '聊天会话元数据同步完成: ${session.id}');
      }
    } catch (e, stackTrace) {
      // Don't throw - allow other sync tasks to proceed if possible
      AppLogger.e('SyncService', '同步聊天会话元数据失败', e, stackTrace);
      // Optionally update state with a non-fatal error?
      // _updateSyncState(error: '部分同步失败: 聊天会话元数据'); // Be careful not to overwrite fatal errors
    }
  }
  
  /// --- New Method: Sync Pending Chat Messages ---
  Future<void> _syncPendingMessages() async {
    try {
       final pendingMessages = await localStorageService.getPendingMessages();
       if (pendingMessages.isEmpty) {
          AppLogger.d('SyncService', '没有待发送的消息。');
          return;
       }
       
       AppLogger.i('SyncService', '开始处理 ${pendingMessages.length} 条待发送消息。');
       final String currentUserId = await _getCurrentUserId(); // Get User ID once

       for (final messageData in pendingMessages) {
          final localId = messageData['localId'] as String?;
          final sessionId = messageData['sessionId'] as String?;
          final content = messageData['content'] as String?;
          final metadata = messageData['metadata'] as Map<String, dynamic>?;
          // Important: Use the userId stored with the message if available,
          // otherwise use currentUserId. This handles cases where sync might
          // happen after user logout/login, though ideally pending messages
          // should be cleared on logout.
          final userIdToSend = messageData['userId'] as String? ?? currentUserId; 

          if (localId == null || sessionId == null || content == null) {
             AppLogger.e('SyncService', '待发送消息数据不完整，跳过: $messageData');
             // Optionally remove corrupted data
             // if (localId != null) await localStorageService.removePendingMessage(localId);
             continue;
          }

          try {
             AppLogger.d('SyncService', '尝试发送消息: localId=$localId, sessionId=$sessionId');
             // Call the actual API to send the message
             await apiService.sendMessage(
                userId: userIdToSend,
                sessionId: sessionId,
                content: content,
                metadata: metadata,
             );

             // If sendMessage succeeds, remove from local pending queue
             await localStorageService.removePendingMessage(localId);
             AppLogger.i('SyncService', '成功发送并移除待发送消息: localId=$localId');

             // OPTIONAL: Add the successfully sent message to the local history cache
             // This requires constructing a proper ChatMessage object from the response
             // or assuming success and creating one locally. This is complex.
             // It might be simpler to rely on fetching history later.

          } on ApiException catch (apiError, stack) { // Catch specific API errors
             AppLogger.e('SyncService', '发送待处理消息失败 (API Error $localId): ${apiError.message}', apiError, stack);
             // Decide if error is temporary or permanent.
             // For now, leave in queue and retry later.
             // If 4xx error, maybe remove from queue?
             if (apiError.statusCode >= 400 && apiError.statusCode < 500 && apiError.statusCode != 401 && apiError.statusCode != 429) {
                AppLogger.w('SyncService', '接收到客户端错误 (${apiError.statusCode})，可能移除待发送消息 $localId');
                 // Consider removing permanently failed message
                 // await localStorageService.removePendingMessage(localId);
             }
          } catch (e, stackTrace) { // Catch other errors
             AppLogger.e('SyncService', '发送待处理消息时发生未知错误 ($localId)', e, stackTrace);
             // Leave in queue for retry
          }
       }
       AppLogger.i('SyncService', '处理待发送消息完成。');

    } catch (e, stackTrace) {
        // Error fetching or processing the queue itself
       AppLogger.e('SyncService', '处理待发送消息队列时出错', e, stackTrace);
       // Don't throw, allow other sync tasks. Update state?
       // _updateSyncState(error: '部分同步失败: 待发送消息');
    }
  }
  
  /// 同步单个小说
  Future<bool> syncNovel(String novelId) async {
    if (!_currentState.isOnline) {
      _updateSyncState(error: '无网络连接，无法同步');
      return false;
    }
    
    try {
      // 获取本地小说
      final localNovel = await localStorageService.getNovel(novelId);
      if (localNovel == null) return false;
      
      // 上传到服务器
      await apiService.updateNovel(localNovel);
      
      // 标记为已同步
      await localStorageService.clearSyncFlagByType('novel', novelId);
      
      return true;
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步小说失败', e);
      _updateSyncState(error: '同步小说失败: $e');
      return false;
    }
  }
  
  /// 同步单个场景
  Future<bool> syncScene(
    String novelId, 
    String actId, 
    String chapterId, 
    String sceneId
  ) async {
    if (!_currentState.isOnline) {
      _updateSyncState(error: '无网络连接，无法同步');
      return false;
    }
    
    try {
      // 获取本地场景
      final localScene = await localStorageService.getSceneContent(
        novelId, actId, chapterId, sceneId);
      if (localScene == null) return false;
      
      // 上传到服务器
      await apiService.updateSceneContent(
        novelId, actId, chapterId, sceneId, localScene);
      
      // 标记为已同步
      final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
      await localStorageService.clearSyncFlagByType('scene', sceneKey);
      
      return true;
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步场景失败', e);
      _updateSyncState(error: '同步场景失败: $e');
      return false;
    }
  }
  
  /// 同步单个编辑器内容
  Future<bool> syncEditorContent(
    String novelId, 
    String chapterId, 
    String sceneId
  ) async {
    if (!_currentState.isOnline) {
      _updateSyncState(error: '无网络连接，无法同步');
      return false;
    }
    
    try {
      // 获取本地编辑器内容
      final localContent = await localStorageService.getEditorContent(
        novelId, chapterId, sceneId);
      if (localContent == null) return false;
      
      // 上传到服务器
      await apiService.saveEditorContent(localContent);
      
      // 标记为已同步
      final contentKey = '${novelId}_${chapterId}_$sceneId';
      await localStorageService.clearSyncFlagByType('editor', contentKey);
      
      return true;
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步编辑器内容失败', e);
      _updateSyncState(error: '同步编辑器内容失败: $e');
      return false;
    }
  }
  
  /// 同步单个聊天会话元数据 (不再发送消息历史)
  Future<bool> syncChatSession(String sessionId) async {
    // 此方法现在只应同步元数据，或触发特定会话的待发送消息同步（如果需要）
    // 当前实现仅基于本地状态同步元数据。
    if (!_currentState.isOnline) {
      _updateSyncState(error: '无网络连接，无法同步');
      return false;
    }
    
    try {
      final session = await localStorageService.getChatSession(sessionId);
      if (session == null) {
         AppLogger.w('SyncService', '尝试同步单个会话元数据，但本地未找到: $sessionId');
         await localStorageService.clearSyncFlagByType('chat_session', sessionId); // 清除无效标记
         return false; // 无法同步不存在的会话
      }

      // 同步元数据 (例如: title)
      final Map<String, dynamic> updates = {'title': session.title};

      if (updates.isNotEmpty) {
      await apiService.updateSession(
            userId: await _getCurrentUserId(), // 如果 API 需要，获取 userId
        sessionId: session.id,
            updates: updates,
         );
         AppLogger.d('SyncService', '单个聊天会话元数据 API 更新调用完成: $sessionId');
      } else {
         AppLogger.d('SyncService', '单个聊天会话 ${session.id} 没有需要同步的元数据更新');
      }

      // ======== 移除: 不再通过 getMessagesForSession 循环发送消息 ========

      // 清除此会话的元数据同步标记
      await localStorageService.clearSyncFlagByType('chat_session', sessionId);
      AppLogger.i('SyncService', '单个聊天会话元数据同步处理完成: $sessionId');
      return true;
    } catch (e, stackTrace) { // 捕获所有可能的错误
      AppLogger.e('SyncService', '同步单个聊天会话元数据失败 ($sessionId)', e, stackTrace);
      _updateSyncState(error: '同步单个聊天会话元数据失败: $e');
      // 同步失败，暂时不清除标记，留待下次重试
      return false;
    }
  }
  
  /// 解决冲突 (需要根据聊天数据的具体冲突场景来完善)
  Future<bool> resolveConflict(
    String type,
    String id,
    bool useLocal // true 表示保留本地版本，false 表示使用远程版本
  ) async {
    if (!_currentState.isOnline) {
       _updateSyncState(error: '无网络连接，无法解决冲突');
       return false;
    }
    AppLogger.i('SyncService', '开始解决冲突: 类型=$type, ID=$id, 使用本地版本=$useLocal');
    try {
      switch (type) {
        case 'novel':
          if (useLocal) {
            // 使用本地版本覆盖远程版本
            AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用本地版本。');
            return syncNovel(id);
          } else {
            // 使用远程版本覆盖本地版本
            AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用远程版本。');
            final remoteNovel = await apiService.fetchNovel(id);
            await localStorageService.saveNovel(remoteNovel); // 保存远程版本到本地
            await localStorageService.clearSyncFlagByType('novel', id); // 清除同步标记
            AppLogger.i('SyncService', '冲突解决 ($type/$id): 远程版本已覆盖本地。');
            return true;
          }
        
        case 'scene':
          final parts = id.split('_'); // sceneKey 格式: novelId_actId_chapterId_sceneId
          if (parts.length != 4) {
             AppLogger.e('SyncService', '冲突解决 ($type/$id): 无效的场景键格式');
             return false;
          }
          final novelId = parts[0], actId = parts[1], chapterId = parts[2], sceneId = parts[3];
          
          if (useLocal) {
            // 使用本地版本覆盖远程版本
             AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用本地版本。');
            return syncScene(novelId, actId, chapterId, sceneId);
          } else {
            // 使用远程版本覆盖本地版本
            AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用远程版本。');
            final remoteScene = await apiService.fetchSceneContent(
              novelId, actId, chapterId, sceneId);
            await localStorageService.saveSceneContent( // 保存远程版本到本地
              novelId, actId, chapterId, sceneId, remoteScene);
            await localStorageService.clearSyncFlagByType('scene', id); // 清除同步标记
            AppLogger.i('SyncService', '冲突解决 ($type/$id): 远程版本已覆盖本地。');
            return true;
          }
        
        case 'editor': // 假设编辑器内容冲突
           final parts = id.split('_'); // contentKey 格式: novelId_chapterId[_sceneId]
           if (parts.length < 2) {
              AppLogger.e('SyncService', '冲突解决 ($type/$id): 无效的编辑器内容键格式');
              return false;
           }
           final novelId = parts[0], chapterId = parts[1];
           final sceneId = parts.length > 2 ? parts[2] : ''; // 可能没有 sceneId

          if (useLocal) {
             // 使用本地版本覆盖远程版本
             AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用本地版本。');
             return syncEditorContent(novelId, chapterId, sceneId);
          } else {
             // 使用远程版本覆盖本地版本
             AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用远程版本。');
             // 注意：API 假定是 getEditorContent，需要确认是否有对应的 fetch 接口
             // 假设 getEditorContent 可以从 API 获取最新内容
             final remoteContent = await apiService.getEditorContent(novelId, chapterId, sceneId);
             await localStorageService.saveEditorContent(remoteContent); // 保存远程版本到本地
             await localStorageService.clearSyncFlagByType('editor', id); // 清除同步标记
             AppLogger.i('SyncService', '冲突解决 ($type/$id): 远程版本已覆盖本地。');
             return true;
          }

         case 'chat_session': // 聊天会话元数据冲突
           if (useLocal) {
              // 使用本地版本覆盖远程版本（仅元数据）
              AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用本地版本。');
              return syncChatSession(id); // syncChatSession 会上传本地元数据
           } else {
              // 使用远程版本覆盖本地版本（仅元数据）
              AppLogger.d('SyncService', '冲突解决 ($type/$id): 使用远程版本。');
              final remoteSession = await apiService.getSession(await _getCurrentUserId(), id); // 从 API 获取会话详情
              await localStorageService.updateChatSession(remoteSession, needsSync: false); // 保存远程版本，不标记再同步
              await localStorageService.clearSyncFlagByType('chat_session', id); // 清除同步标记
              AppLogger.i('SyncService', '冲突解决 ($type/$id): 远程版本已覆盖本地。');
              return true;
           }

        // 注意：待发送消息队列通常不涉及冲突解决，发送成功即移除。

        default:
          AppLogger.w('SyncService', '未知的冲突类型: $type');
          return false;
      }
    } catch (e, stackTrace) { // 捕获解决冲突过程中的所有错误
      AppLogger.e('SyncService', '解决冲突失败 ($type/$id)', e, stackTrace);
      _updateSyncState(error: '解决冲突失败: $e');
      return false;
    }
  }
  
  /// 关闭服务，释放资源
  void dispose() {
    _syncStateController.close(); // 关闭状态流
    _connectivitySubscription?.cancel(); // 取消网络监听
    _autoSyncTimer?.cancel(); // 取消定时器
    AppLogger.i('SyncService', '同步服务已关闭');
  }

  /// 获取当前用户ID (使用 AppConfig 实现)
  Future<String> _getCurrentUserId() async {
    final userId = AppConfig.userId; // 从 AppConfig 获取用户ID
    if (userId == null || userId.isEmpty) {
      AppLogger.e('SyncService', '无法获取当前用户ID，同步操作可能失败或无法执行。');
      // 根据需求，可以抛出异常或返回占位符/空字符串
      // 如果 userId 是必需的，抛出异常更安全
      throw SyncException('无法获取当前用户ID，无法执行需要用户ID的同步操作。');
    }
    return userId;
  }
}

/// 同步状态类
class SyncState {
  
  SyncState({
    required this.isOnline, // 网络是否连接
    required this.isSyncing, // 是否正在同步中
    this.error,             // 同步错误信息，null表示无错误
    this.progress = 0.0,    // 同步进度 (0.0 到 1.0)
  });

  /// 空闲状态 (默认在线)
  factory SyncState.idle({bool online = true}) {
    return SyncState(
      isOnline: online,
      isSyncing: false,
    );
  }
  
  /// 同步中状态
  factory SyncState.syncing({double progress = 0.0}) {
    return SyncState(
      isOnline: true, // 同步时必须在线
      isSyncing: true,
      progress: progress,
    );
  }
  
  /// 离线状态
  factory SyncState.offline() {
    return SyncState(
      isOnline: false,
      isSyncing: false, // 离线时不能同步
    );
  }
  
  /// 错误状态 (允许指定当时的网络状态)
  factory SyncState.error(String errorMessage, {bool online = true}) {
    return SyncState(
      isOnline: online, // 错误可能在线或离线时发生
      isSyncing: false, // 出错时停止同步
      error: errorMessage,
    );
  }
  final bool isOnline;
  final bool isSyncing;
  final String? error;
  final double progress;

  @override
  String toString() {
     // 提供更清晰的状态描述
     return 'SyncState(在线: $isOnline, 同步中: $isSyncing, 进度: ${progress.toStringAsFixed(2)}, 错误: ${error ?? "无"})';
  }
}

/// 同步异常类
class SyncException implements Exception {
  
  SyncException(this.message);
  final String message; // 异常信息
  
  @override
  String toString() => 'SyncException: $message';
} 