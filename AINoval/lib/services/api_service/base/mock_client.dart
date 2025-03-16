import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/mock_data_service.dart';

/// 模拟API客户端
/// 
/// 用于开发和测试环境，模拟API响应
class MockClient {
  
  MockClient({MockDataService? mockService}) 
      : _mockService = mockService ?? MockDataService();
  final MockDataService _mockService;
  
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));
    
    // 根据路径返回不同的模拟数据
    if (path.contains('/novels') && !path.contains('/chapters')) {
      if (path.contains('/search')) {
        final title = queryParameters?['title'] as String? ?? '';
        return _mockService.getAllNovels()
            .where((novel) => novel.title.toLowerCase().contains(title.toLowerCase()))
            .map((novel) => _novelToJson(novel))
            .toList();
      } else if (path.contains('/author/')) {
        return _mockService.getAllNovels()
            .map((novel) => _novelToJson(novel))
            .toList();
      } else if (path.split('/').length > 2) {
        // 获取单个小说
        final id = path.split('/').last;
        final novel = _mockService.getNovel(id);
        if (novel == null) {
          throw _createApiException(404, '小说不存在');
        }
        return _novelToJson(novel);
      } else {
        // 获取所有小说
        return _mockService.getAllNovels()
            .map((novel) => _novelToJson(novel))
            .toList();
      }
    } else if (path.contains('/chapters') && path.contains('/scenes')) {
      // 处理场景相关请求
      final segments = path.split('/');
      final novelId = segments[segments.indexOf('novels') + 1];
      final chapterId = segments[segments.indexOf('chapters') + 1];
      
      if (segments.contains('scenes') && segments.length > segments.indexOf('scenes') + 1) {
        final sceneId = segments[segments.indexOf('scenes') + 1];
        final scene = _mockService.getSceneContent(novelId, '', chapterId, sceneId);
        if (scene == null) {
          throw _createApiException(404, '场景不存在');
        }
        return _sceneToJson(scene);
      }
    } else if (path.contains('/chats')) {
      if (path.split('/').length > 2) {
        // 获取单个聊天会话
        final id = path.split('/').last;
        final session = _mockService.getChatSession(id);
        return session.toJson();
      } else {
        // 获取所有聊天会话
        final novelId = path.split('/')[2];
        return _mockService.getChatSessions(novelId)
            .map((session) => session.toJson())
            .toList();
      }
    }
    
    throw _createApiException(404, '未找到资源');
  }
  
  Future<dynamic> post(String path, {dynamic data}) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (path.contains('/novels') && !path.contains('/chapters')) {
      // 创建小说
      if (data is Map<String, dynamic> && data.containsKey('title')) {
        final novel = _mockService.createNovel(data['title']);
        return _novelToJson(novel);
      }
    } else if (path.contains('/chats')) {
      // 创建聊天会话
      if (data is Map<String, dynamic> && data.containsKey('title')) {
        final novelId = path.split('/')[2];
        final session = _mockService.createChatSession(
          title: data['title'],
          novelId: novelId,
          chapterId: data['chapterId'],
        );
        return session.toJson();
      }
    }
    
    throw _createApiException(400, '无效的请求');
  }
  
  Future<dynamic> put(String path, {dynamic data}) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 400));
    
    return {'success': true, 'message': '更新成功'};
  }
  
  Future<dynamic> delete(String path) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {'success': true, 'message': '删除成功'};
  }
  
  void dispose() {
    // 不需要实际关闭任何连接
  }
  
  /// 创建API异常
  ApiException _createApiException(int statusCode, String message) {
    return ApiException(statusCode, message);
  }
  
  /// 将Novel模型转换为JSON
  Map<String, dynamic> _novelToJson(dynamic novel) {
    return {
      'id': novel.id,
      'title': novel.title,
      'coverImage': novel.coverImagePath,
      'createdAt': novel.createdAt.toIso8601String(),
      'updatedAt': novel.updatedAt.toIso8601String(),
      'structure': {
        'acts': novel.acts.map((act) => {
          'id': act.id,
          'title': act.title,
          'order': act.order,
          'chapters': act.chapters.map((chapter) => {
            'id': chapter.id,
            'title': chapter.title,
            'order': chapter.order,
          }).toList(),
        }).toList(),
      },
    };
  }
  
  /// 将Scene模型转换为JSON
  Map<String, dynamic> _sceneToJson(dynamic scene) {
    return {
      'id': scene.id,
      'content': scene.content,
      'summary': scene.summary.content,
      'wordCount': scene.wordCount,
      'updatedAt': scene.lastEdited.toIso8601String(),
    };
  }
} 