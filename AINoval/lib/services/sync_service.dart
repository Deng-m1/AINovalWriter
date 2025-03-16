import 'dart:async';

import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


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
    // 监听网络连接状态
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      _handleConnectivityChange(isOnline);
    });
    
    // 检查当前网络状态
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    _handleConnectivityChange(isOnline);
    
    // 设置自动同步定时器
    _setupAutoSync();
  }
  
  /// 设置自动同步
  void _setupAutoSync() {
    // 每5分钟自动同步一次
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_currentState.isOnline) {
        syncAll();
      }
    });
  }
  
  /// 处理网络连接变化
  void _handleConnectivityChange(bool isOnline) {
    // 更新同步状态
    _updateSyncState(isOnline: isOnline);
    
    // 如果从离线变为在线，尝试同步
    if (isOnline && !_currentState.isOnline) {
      syncAll();
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
    
    // 发送同步状态更新
    _syncStateController.add(_currentState);
  }
  
  /// 同步所有数据
  Future<bool> syncAll() async {
    if (_currentState.isSyncing) {
      return false; // 已经在同步中
    }
    
    if (!_currentState.isOnline) {
      _updateSyncState(error: '无网络连接，无法同步');
      return false;
    }
    
    try {
      _updateSyncState(isSyncing: true, progress: 0.0);
      
      // 同步小说数据
      await _syncNovels();
      _updateSyncState(progress: 0.3);
      
      // 同步场景内容
      await _syncScenes();
      _updateSyncState(progress: 0.6);
      
      // 同步编辑器内容
      await _syncEditorContents();
      _updateSyncState(progress: 0.9);
      
      // 同步聊天会话
      await _syncChatSessions();
      _updateSyncState(progress: 1.0);
      
      _updateSyncState(isSyncing: false, error: null);
      return true;
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步失败', e);
      _updateSyncState(isSyncing: false, error: '同步失败: $e');
      return false;
    }
  }
  
  /// 同步小说数据
  Future<void> _syncNovels() async {
    try {
      // 获取需要同步的小说
      final syncList = await localStorageService.getSyncList('novel');
      
      for (final novelId in syncList) {
        // 获取本地小说
        final localNovel = await localStorageService.getNovel(novelId);
        if (localNovel == null) continue;
        
        // 上传到服务器
        if (!AppConfig.shouldUseMockData) {
          await apiService.updateNovel(localNovel);
        }
        
        // 标记为已同步
        await localStorageService.clearSyncFlagByType('novel', novelId);
      }
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步小说数据失败', e);
      throw SyncException('同步小说数据失败: $e');
    }
  }
  
  /// 同步场景内容
  Future<void> _syncScenes() async {
    try {
      // 获取需要同步的场景
      final syncList = await localStorageService.getSyncList('scene');
      
      for (final sceneKey in syncList) {
        // 解析场景键
        final parts = sceneKey.split('_');
        if (parts.length != 4) continue;
        
        final novelId = parts[0];
        final actId = parts[1];
        final chapterId = parts[2];
        final sceneId = parts[3];
        
        // 获取本地场景
        final localScene = await localStorageService.getSceneContent(
          novelId, actId, chapterId, sceneId);
        if (localScene == null) continue;
        
        // 上传到服务器
        if (!AppConfig.shouldUseMockData) {
          await apiService.updateSceneContent(
            novelId, actId, chapterId, sceneId, localScene);
        }
        
        // 标记为已同步
        await localStorageService.clearSyncFlagByType('scene', sceneKey);
      }
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步场景内容失败', e);
      throw SyncException('同步场景内容失败: $e');
    }
  }
  
  /// 同步编辑器内容
  Future<void> _syncEditorContents() async {
    try {
      // 获取需要同步的编辑器内容
      final syncList = await localStorageService.getSyncList('editor');
      
      for (final contentKey in syncList) {
        // 解析内容键
        final parts = contentKey.split('_');
        if (parts.length < 2) continue;
        
        final novelId = parts[0];
        final chapterId = parts[1];
        final sceneId = parts.length > 2 ? parts[2] : '';
        
        // 获取本地编辑器内容
        final localContent = await localStorageService.getEditorContent(
          novelId, chapterId, sceneId);
        if (localContent == null) continue;
        
        // 上传到服务器
        if (!AppConfig.shouldUseMockData) {
          await apiService.saveEditorContent(localContent);
        }
        
        // 标记为已同步
        await localStorageService.clearSyncFlagByType('editor', contentKey);
      }
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步编辑器内容失败', e);
      throw SyncException('同步编辑器内容失败: $e');
    }
  }
  
  /// 同步聊天会话
  Future<void> _syncChatSessions() async {
    try {
      // 获取需要同步的聊天会话
      final sessions = await localStorageService.getSessionsToSync();
      
      for (final session in sessions) {
        // 上传到服务器
        if (!AppConfig.shouldUseMockData) {
          await apiService.updateChatSession(session);
          
          // 同步消息
          await apiService.updateChatSessionMessages(
            session.id, session.messages);
        }
        
        // 标记为已同步
        await localStorageService.clearSyncFlag(session.id);
      }
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步聊天会话失败', e);
      throw SyncException('同步聊天会话失败: $e');
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
      if (!AppConfig.shouldUseMockData) {
        await apiService.updateNovel(localNovel);
      }
      
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
      if (!AppConfig.shouldUseMockData) {
        await apiService.updateSceneContent(
          novelId, actId, chapterId, sceneId, localScene);
      }
      
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
      if (!AppConfig.shouldUseMockData) {
        await apiService.saveEditorContent(localContent);
      }
      
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
  
  /// 同步单个聊天会话
  Future<bool> syncChatSession(String sessionId) async {
    if (!_currentState.isOnline) {
      _updateSyncState(error: '无网络连接，无法同步');
      return false;
    }
    
    try {
      // 获取本地聊天会话
      final session = await localStorageService.getChatSession(sessionId);
      if (session == null) return false;
      
      // 上传到服务器
      if (!AppConfig.shouldUseMockData) {
        await apiService.updateChatSession(session);
        
        // 同步消息
        await apiService.updateChatSessionMessages(
          session.id, session.messages);
      }
      
      // 标记为已同步
      await localStorageService.clearSyncFlag(sessionId);
      
      return true;
    } catch (e) {
      AppLogger.e('Services/sync_service', '同步聊天会话失败', e);
      _updateSyncState(error: '同步聊天会话失败: $e');
      return false;
    }
  }
  
  /// 解决冲突
  Future<bool> resolveConflict(
    String type,
    String id,
    bool useLocal
  ) async {
    try {
      switch (type) {
        case 'novel':
          if (useLocal) {
            // 使用本地版本
            return syncNovel(id);
          } else {
            // 使用远程版本
            final remoteNovel = await apiService.fetchNovel(id);
            await localStorageService.saveNovel(remoteNovel);
            await localStorageService.clearSyncFlagByType('novel', id);
            return true;
          }
        
        case 'scene':
          final parts = id.split('_');
          if (parts.length != 4) return false;
          
          final novelId = parts[0];
          final actId = parts[1];
          final chapterId = parts[2];
          final sceneId = parts[3];
          
          if (useLocal) {
            // 使用本地版本
            return syncScene(novelId, actId, chapterId, sceneId);
          } else {
            // 使用远程版本
            final remoteScene = await apiService.fetchSceneContent(
              novelId, actId, chapterId, sceneId);
            await localStorageService.saveSceneContent(
              novelId, actId, chapterId, sceneId, remoteScene);
            await localStorageService.clearSyncFlagByType('scene', id);
            return true;
          }
        
        default:
          return false;
      }
    } catch (e) {
      AppLogger.e('Services/sync_service', '解决冲突失败', e);
      _updateSyncState(error: '解决冲突失败: $e');
      return false;
    }
  }
  
  /// 关闭服务
  void dispose() {
    _syncStateController.close();
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
  }
}

/// 同步状态类
class SyncState {
  
  SyncState({
    required this.isOnline,
    required this.isSyncing,
    this.error,
    this.progress = 0.0,
  });
  
  /// 空闲状态
  factory SyncState.idle() {
    return SyncState(
      isOnline: true,
      isSyncing: false,
    );
  }
  
  /// 同步中状态
  factory SyncState.syncing({double progress = 0.0}) {
    return SyncState(
      isOnline: true,
      isSyncing: true,
      progress: progress,
    );
  }
  
  /// 离线状态
  factory SyncState.offline() {
    return SyncState(
      isOnline: false,
      isSyncing: false,
    );
  }
  
  /// 错误状态
  factory SyncState.error(String errorMessage) {
    return SyncState(
      isOnline: true,
      isSyncing: false,
      error: errorMessage,
    );
  }
  final bool isOnline;
  final bool isSyncing;
  final String? error;
  final double progress;
}

/// 同步异常类
class SyncException implements Exception {
  
  SyncException(this.message);
  final String message;
  
  @override
  String toString() => 'SyncException: $message';
} 