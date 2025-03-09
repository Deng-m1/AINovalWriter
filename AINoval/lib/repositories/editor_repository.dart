import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/mock_data.dart';

class EditorRepository {
  
  EditorRepository({
    required this.apiService,
    required this.localStorageService,
  });
  final ApiService apiService;
  final LocalStorageService localStorageService;
  
  // 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId) async {
    try {
      // 先尝试从本地获取
      final contentJson = await localStorageService.getChapterContent(novelId, chapterId);
      
      if (contentJson != null) {
        return EditorContent.fromJson(contentJson);
      }
      
      // 在第一个迭代中，使用模拟数据
      final content = MockData.getEditorContent(novelId, chapterId);
      
      // 保存到本地
      await localStorageService.saveChapterContent(
        novelId, 
        chapterId, 
        content.toJson(),
      );
      
      return content;
    } catch (e) {
      // 如果获取失败，创建空内容
      return EditorContent(
        id: chapterId,
        content: '{"ops":[{"insert":"\\n"}]}',
        lastSaved: DateTime.now(),
      );
    }
  }
  
  // 保存编辑器内容
  Future<EditorContent> saveEditorContent(
    String novelId,
    String chapterId,
    String content,
  ) async {
    final now = DateTime.now();
    
    final editorContent = EditorContent(
      id: chapterId,
      content: content,
      lastSaved: now,
    );
    
    // 保存到本地
    await localStorageService.saveChapterContent(
      novelId,
      chapterId,
      editorContent.toJson(),
    );
    
    // 在实际应用中，还需向服务器保存
    // try {
    //   await apiService.saveChapterContent(novelId, chapterId, content);
    // } catch (e) {
    //   await localStorageService.markForSync(novelId, chapterId);
    // }
    
    return editorContent;
  }
  
  // 获取编辑器设置
  Future<EditorSettings> getEditorSettings() async {
    try {
      final settingsJson = await localStorageService.getEditorSettings();
      
      if (settingsJson.isNotEmpty) {
        return EditorSettings.fromJson(settingsJson);
      }
      
      return const EditorSettings();
    } catch (e) {
      return const EditorSettings();
    }
  }
  
  // 保存编辑器设置
  Future<void> saveEditorSettings(EditorSettings settings) async {
    await localStorageService.saveEditorSettings(settings.toJson());
  }
  
  // 获取本地草稿
  Future<String?> getLocalDraft(String novelId, String chapterId) async {
    try {
      final contentJson = await localStorageService.getChapterContent(novelId, chapterId);
      
      if (contentJson != null) {
        final content = EditorContent.fromJson(contentJson);
        return content.content;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId) async {
    // 在第一个迭代中，使用模拟数据
    return MockData.getRevisionHistory(novelId, chapterId);
  }
  
  // 恢复到特定修订版本
  Future<EditorContent> restoreRevision(
    String novelId,
    String chapterId,
    String revisionId,
  ) async {
    try {
      // 获取修订历史
      final revisions = await getRevisionHistory(novelId, chapterId);
      
      // 查找指定的修订版本
      final revision = revisions.firstWhere(
        (rev) => rev.id == revisionId,
        orElse: () => throw Exception('未找到修订版本'),
      );
      
      // 创建新的编辑器内容
      final restoredContent = EditorContent(
        id: chapterId,
        content: revision.content,
        lastSaved: DateTime.now(),
        revisions: revisions,
      );
      
      return restoredContent;
    } catch (e) {
      throw Exception('恢复修订版本失败: $e');
    }
  }
} 