import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/chat_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/novel_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';

/// API服务工厂类
/// 
/// 负责创建和管理仓库实例，采用单例模式
class ApiServiceFactory {
  
  factory ApiServiceFactory() {
    return _instance;
  }
  
  ApiServiceFactory._internal();
  static final ApiServiceFactory _instance = ApiServiceFactory._internal();
  
  // 客户端实例
  ApiClient? _apiClient;
  
  // 仓库实例
  NovelRepository? _novelRepository;
  ChatRepository? _chatRepository;
  EditorRepository? _editorRepository;
  
  /// 获取API客户端
  ApiClient get apiClient {
    _apiClient ??= ApiClient();
    return _apiClient!;
  }
  
  /// 获取小说仓库
  NovelRepository get novelRepository {
    _novelRepository ??= NovelRepositoryImpl();
    return _novelRepository!;
  }
  
  /// 获取聊天仓库
  ChatRepository get chatRepository {
    _chatRepository ??= ChatRepositoryImpl(apiClient: apiClient);
    return _chatRepository!;
  }
  
  /// 获取编辑器仓库
  EditorRepository get editorRepository {
    _editorRepository ??= EditorRepositoryImpl(apiClient: apiClient);
    return _editorRepository!;
  }
  
  /// 释放所有资源
  void dispose() {
    _apiClient?.dispose();
    _apiClient = null;
    _novelRepository = null;
    _chatRepository = null;
    _editorRepository = null;
  }
} 