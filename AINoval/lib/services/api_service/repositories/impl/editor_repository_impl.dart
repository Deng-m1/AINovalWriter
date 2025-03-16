import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/chat_models.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/mock_data_service.dart';

/// 编辑器仓库实现
class EditorRepositoryImpl implements EditorRepository {
  final ApiClient _apiClient;
  final MockDataService _mockService;
  
  EditorRepositoryImpl({
    ApiClient? apiClient,
    MockDataService? mockService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _mockService = mockService ?? MockDataService();
  
  /// 获取编辑器内容
  @override
  Future<EditorContent> getEditorContent(String novelId, String chapterId, String sceneId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getEditorContent(novelId, chapterId, sceneId);
    }
    
    try {
      final data = await _apiClient.get('/novels/$novelId/chapters/$chapterId/scenes/$sceneId/content');
      return EditorContent.fromJson(data);
    } catch (e) {
      print('获取编辑器内容失败: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getEditorContent(novelId, chapterId, sceneId);
    }
  }
  
  /// 保存编辑器内容
  @override
  Future<void> saveEditorContent(EditorContent content) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }
    
    try {
      final parts = content.id.split('-');
      if (parts.length < 2) {
        throw ApiException(-1, '无效的内容ID格式');
      }
      
      final novelId = parts[0];
      final chapterId = parts[1];
      
      await _apiClient.put('/novels/$novelId/chapters/$chapterId/content', data: content.toJson());
    } catch (e) {
      print('保存编辑器内容失败: $e');
      throw ApiException(-1, '保存编辑器内容失败: $e');
    }
  }
  
  /// 获取修订历史
  @override
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      return _mockService.getRevisionHistory(novelId, chapterId);
    }
    
    try {
      final data = await _apiClient.get('/novels/$novelId/chapters/$chapterId/revisions');
      if (data is List) {
        return data.map((json) => Revision.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('获取修订历史失败: $e');
      // 如果API请求失败，回退到模拟数据
      return _mockService.getRevisionHistory(novelId, chapterId);
    }
  }
  
  /// 创建修订版本
  @override
  Future<Revision> createRevision(String novelId, String chapterId, Revision revision) async {
    // 如果使用模拟数据，直接返回
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return revision;
    }
    
    try {
      final data = await _apiClient.post('/novels/$novelId/chapters/$chapterId/revisions', 
          data: revision.toJson());
      return Revision.fromJson(data);
    } catch (e) {
      print('创建修订版本失败: $e');
      throw ApiException(-1, '创建修订版本失败: $e');
    }
  }
  
  /// 应用修订版本
  @override
  Future<void> applyRevision(String novelId, String chapterId, String revisionId) async {
    // 如果使用模拟数据，不执行任何操作
    if (AppConfig.shouldUseMockData) {
      // 添加延迟模拟网络请求
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }
    
    try {
      await _apiClient.post('/novels/$novelId/chapters/$chapterId/revisions/$revisionId/apply');
    } catch (e) {
      print('应用修订版本失败: $e');
      throw ApiException(-1, '应用修订版本失败: $e');
    }
  }
}