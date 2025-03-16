import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/chat_models.dart';

/// 编辑器仓库接口
/// 
/// 定义与编辑器相关的所有API操作
abstract class EditorRepository {
  /// 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId, String sceneId);
  
  /// 保存编辑器内容
  Future<void> saveEditorContent(EditorContent content);
  
  /// 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId);
  
  /// 创建修订版本
  Future<Revision> createRevision(String novelId, String chapterId, Revision revision);
  
  /// 应用修订版本
  Future<void> applyRevision(String novelId, String chapterId, String revisionId);
} 