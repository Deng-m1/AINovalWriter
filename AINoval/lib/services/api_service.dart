import 'dart:convert';

import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/services/mock_data_service.dart';
import 'package:http/http.dart' as http;

import '../models/chat_models.dart';

/// API服务，用于与后端通信
class ApiService {
  
  ApiService({
    String? baseUrl,
    http.Client? client,
    MockDataService? mockService,
  }) : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _client = client ?? http.Client(),
       _mockService = mockService ?? MockDataService();
  
  final String _baseUrl;
  final http.Client _client;
  final MockDataService _mockService;
  
  /// 获取所有小说
  Future<List<novel_models.Novel>> fetchNovels() async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getAllNovels();
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/novels'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => novel_models.Novel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch novels: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching novels: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getAllNovels();
    }
  }
  
  /// 获取单个小说
  Future<novel_models.Novel> fetchNovel(String id) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      final novel = _mockService.getNovel(id);
      if (novel != null) {
        return novel;
      }
      throw Exception('Novel not found in mock data');
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/novels/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Novel.fromJson(data);
      } else {
        throw Exception('Failed to fetch novel: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching novel: $e');
      // 如果API请求失败，回退到模拟数据
      final novel = _mockService.getNovel(id);
      if (novel != null) {
        return novel;
      }
      throw Exception('Novel not found');
    }
  }
  
  /// 创建小说
  Future<novel_models.Novel> createNovel(String title) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.createNovel(title);
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/novels'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title}),
      );
      
      if (response.statusCode == 201) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Novel.fromJson(data);
      } else {
        throw Exception('Failed to create novel: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating novel: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.createNovel(title);
    }
  }
  
  /// 更新小说
  Future<novel_models.Novel> updateNovel(novel_models.Novel novel) async {
    // 如果使用模拟数据，直接更新
    if (AppConfig.shouldUseMockData) {
      _mockService.updateNovel(novel);
      return novel;
    }
    
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/novels/${novel.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(novel.toJson()),
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Novel.fromJson(data);
      } else {
        throw Exception('Failed to update novel: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating novel: $e');
      // 如果API请求失败，更新模拟数据
      _mockService.updateNovel(novel);
      return novel;
    }
  }
  
  /// 删除小说
  Future<void> deleteNovel(String id) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      return;
    }
    
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/novels/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode != 204) {
        throw Exception('Failed to delete novel: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting novel: $e');
    }
  }
  
  /// 获取场景内容
  Future<novel_models.Scene> fetchSceneContent(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId
  ) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      final scene = _mockService.getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene != null) {
        return scene;
      }
      return novel_models.Scene.createEmpty();
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/novels/$novelId/acts/$actId/chapters/$chapterId/scenes/$sceneId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Scene.fromJson(data);
      } else {
        throw Exception('Failed to fetch scene: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching scene: $e');
      // 如果API请求失败，回退到模拟数据
      final scene = _mockService.getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene != null) {
        return scene;
      }
      return novel_models.Scene.createEmpty();
    }
  }
  
  /// 更新场景内容
  Future<novel_models.Scene> updateSceneContent(
    String novelId, 
    String actId, 
    String chapterId, 
    String sceneId,
    novel_models.Scene scene
  ) async {
    // 如果使用模拟数据，直接更新
    if (AppConfig.shouldUseMockData) {
      _mockService.updateSceneContent(novelId, actId, chapterId, sceneId, scene);
      return scene;
    }
    
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/novels/$novelId/acts/$actId/chapters/$chapterId/scenes/$sceneId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(scene.toJson()),
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Scene.fromJson(data);
      } else {
        throw Exception('Failed to update scene: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating scene: $e');
      // 如果API请求失败，更新模拟数据
      _mockService.updateSceneContent(novelId, actId, chapterId, sceneId, scene);
      return scene;
    }
  }
  
  /// 更新摘要内容
  Future<novel_models.Summary> updateSummary(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId,
    novel_models.Summary summary
  ) async {
    // 如果使用模拟数据，直接更新
    if (AppConfig.shouldUseMockData) {
      _mockService.updateSummary(novelId, actId, chapterId, sceneId, summary);
      return summary;
    }
    
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/novels/$novelId/acts/$actId/chapters/$chapterId/scenes/$sceneId/summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(summary.toJson()),
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return novel_models.Summary.fromJson(data);
      } else {
        throw Exception('Failed to update summary: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating summary: $e');
      // 如果API请求失败，更新模拟数据
      _mockService.updateSummary(novelId, actId, chapterId, sceneId, summary);
      return summary;
    }
  }
  
  /// 获取聊天会话列表
  Future<List<ChatSession>> fetchChatSessions(String novelId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockService.getChatSessions(novelId);
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/novels/$novelId/chats'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ChatSession.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch chat sessions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching chat sessions: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getChatSessions(novelId);
    }
  }
  
  /// 创建新的聊天会话
  Future<ChatSession> createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  }) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockService.createChatSession(
        title: title,
        novelId: novelId,
        chapterId: chapterId,
      );
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/novels/$novelId/chats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'chapterId': chapterId,
        }),
      );
      
      if (response.statusCode == 201) {
        final dynamic data = jsonDecode(response.body);
        return ChatSession.fromJson(data);
      } else {
        throw Exception('Failed to create chat session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating chat session: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.createChatSession(
        title: title,
        novelId: novelId,
        chapterId: chapterId,
      );
    }
  }
  
  /// 获取特定会话
  Future<ChatSession> fetchChatSession(String sessionId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockService.getChatSession(sessionId);
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/chats/$sessionId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return ChatSession.fromJson(data);
      } else {
        throw Exception('Failed to fetch chat session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching chat session: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getChatSession(sessionId);
    }
  }
  
  /// 更新会话消息
  Future<void> updateChatSessionMessages(String sessionId, List<ChatMessage> messages) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/chats/$sessionId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(messages.map((m) => m.toJson()).toList()),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update chat messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating chat messages: $e');
    }
  }
  
  /// 更新会话
  Future<void> updateChatSession(ChatSession session) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/chats/${session.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(session.toJson()),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update chat session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating chat session: $e');
    }
  }
  
  /// 删除会话
  Future<void> deleteChatSession(String sessionId) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/chats/$sessionId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode != 204) {
        throw Exception('Failed to delete chat session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting chat session: $e');
    }
  }
  
  /// 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId, String sceneId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getEditorContent(novelId, chapterId, sceneId);
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/novels/$novelId/chapters/$chapterId/scenes/$sceneId/content'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return EditorContent.fromJson(data);
      } else {
        throw Exception('Failed to fetch editor content: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching editor content: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getEditorContent(novelId, chapterId, sceneId);
    }
  }
  
  /// 保存编辑器内容
  Future<void> saveEditorContent(EditorContent content) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }
    
    try {
      final parts = content.id.split('-');
      if (parts.length != 2) {
        throw Exception('Invalid content ID format');
      }
      
      final novelId = parts[0];
      final chapterId = parts[1];
      
      final response = await _client.put(
        Uri.parse('$_baseUrl/novels/$novelId/chapters/$chapterId/content'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(content.toJson()),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to save editor content: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving editor content: $e');
    }
  }
  
  /// 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getRevisionHistory(novelId, chapterId);
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/novels/$novelId/chapters/$chapterId/revisions'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Revision.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch revision history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching revision history: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getRevisionHistory(novelId, chapterId);
    }
  }
  
  /// 关闭客户端
  void dispose() {
    _client.close();
  }
} 