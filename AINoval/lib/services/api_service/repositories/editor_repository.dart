import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart';

/// 编辑器仓库接口
/// 
/// 定义与编辑器相关的所有API操作
abstract class EditorRepository {
  /// 获取小说
  Future<Novel?> getNovel(String novelId);
  
  /// 保存小说数据
  Future<bool> saveNovel(Novel novel);
  
  /// 获取场景内容
  Future<Scene?> getSceneContent(String novelId, String actId, String chapterId, String sceneId);
  
  /// 保存场景内容
  Future<Scene> saveSceneContent(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
    String content,
    String wordCount,
    Summary summary,
  );
  
  /// 保存摘要
  Future<Summary> saveSummary(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
    String content,
  );
  
  /// 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId, String sceneId);
  
  /// 保存编辑器内容
  Future<void> saveEditorContent(EditorContent content);
  
  /// 获取编辑器设置
  Future<Map<String, dynamic>> getEditorSettings();
  
  /// 保存编辑器设置
  Future<void> saveEditorSettings(Map<String, dynamic> settings);
  
  /// 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId);
  
  /// 创建修订版本
  Future<Revision> createRevision(String novelId, String chapterId, Revision revision);
  
  /// 应用修订版本
  Future<void> applyRevision(String novelId, String chapterId, String revisionId);
} 