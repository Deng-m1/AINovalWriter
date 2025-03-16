import 'package:ainoval/models/chat_models.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/services/api_service/api_service_factory.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';

/// API服务类
/// 
/// 作为对外的统一接口，封装了所有与后端通信的操作
class ApiService {
  final ApiServiceFactory _factory;
  
  ApiService({ApiServiceFactory? factory}) 
      : _factory = factory ?? ApiServiceFactory();
  
  /// 获取小说仓库
  NovelRepository get _novelRepository => _factory.novelRepository;
  
  /// 获取聊天仓库
  ChatRepository get _chatRepository => _factory.chatRepository;
  
  /// 获取编辑器仓库
  EditorRepository get _editorRepository => _factory.editorRepository;
  
  // ==================== 小说相关操作 ====================
  
  /// 获取所有小说
  Future<List<Novel>> fetchNovels() {
    return _novelRepository.fetchNovels();
  }
  
  /// 获取单个小说
  Future<Novel> fetchNovel(String id) {
    return _novelRepository.fetchNovel(id);
  }
  
  /// 创建小说
  Future<Novel> createNovel(String title, {String? description, String? coverImage}) {
    return _novelRepository.createNovel(title, description: description, coverImage: coverImage);
  }
  
  /// 根据作者ID获取小说列表
  Future<List<Novel>> fetchNovelsByAuthor(String authorId) {
    return _novelRepository.fetchNovelsByAuthor(authorId);
  }
  
  /// 搜索小说
  Future<List<Novel>> searchNovelsByTitle(String title) {
    return _novelRepository.searchNovelsByTitle(title);
  }
  
  /// 更新小说
  Future<Novel> updateNovel(Novel novel) {
    return _novelRepository.updateNovel(novel);
  }
  
  /// 删除小说
  Future<void> deleteNovel(String id) {
    return _novelRepository.deleteNovel(id);
  }
  
  /// 获取场景内容
  Future<Scene> fetchSceneContent(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId
  ) {
    return _novelRepository.fetchSceneContent(novelId, actId, chapterId, sceneId);
  }
  
  /// 更新场景内容
  Future<Scene> updateSceneContent(
    String novelId, 
    String actId, 
    String chapterId, 
    String sceneId,
    Scene scene
  ) {
    return _novelRepository.updateSceneContent(novelId, actId, chapterId, sceneId, scene);
  }
  
  /// 更新摘要内容
  Future<Summary> updateSummary(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId,
    Summary summary
  ) {
    return _novelRepository.updateSummary(novelId, actId, chapterId, sceneId, summary);
  }
  
  // ==================== 聊天相关操作 ====================
  
  /// 获取聊天会话列表
  Future<List<ChatSession>> fetchChatSessions(String novelId) {
    return _chatRepository.fetchChatSessions(novelId);
  }
  
  /// 创建新的聊天会话
  Future<ChatSession> createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  }) {
    return _chatRepository.createChatSession(
      title: title,
      novelId: novelId,
      chapterId: chapterId,
    );
  }
  
  /// 获取特定会话
  Future<ChatSession> fetchChatSession(String sessionId) {
    return _chatRepository.fetchChatSession(sessionId);
  }
  
  /// 更新会话消息
  Future<void> updateChatSessionMessages(String sessionId, List<ChatMessage> messages) {
    return _chatRepository.updateChatSessionMessages(sessionId, messages);
  }
  
  /// 更新会话
  Future<void> updateChatSession(ChatSession session) {
    return _chatRepository.updateChatSession(session);
  }
  
  /// 删除会话
  Future<void> deleteChatSession(String sessionId) {
    return _chatRepository.deleteChatSession(sessionId);
  }
  
  // ==================== 编辑器相关操作 ====================
  
  /// 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId, String sceneId) {
    return _editorRepository.getEditorContent(novelId, chapterId, sceneId);
  }
  
  /// 保存编辑器内容
  Future<void> saveEditorContent(EditorContent content) {
    return _editorRepository.saveEditorContent(content);
  }
  
  /// 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId) {
    return _editorRepository.getRevisionHistory(novelId, chapterId);
  }
  
  /// 创建修订版本
  Future<Revision> createRevision(String novelId, String chapterId, Revision revision) {
    return _editorRepository.createRevision(novelId, chapterId, revision);
  }
  
  /// 应用修订版本
  Future<void> applyRevision(String novelId, String chapterId, String revisionId) {
    return _editorRepository.applyRevision(novelId, chapterId, revisionId);
  }
  
  /// 释放资源
  void dispose() {
    _factory.dispose();
  }
}

/// API异常类
/// 为了向后兼容，保留ApiException类的定义
/// 但实际上使用的是api_service/base/api_exception.dart中的ApiException
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  
  @override
  String toString() => 'ApiException: $statusCode - $message';
} 