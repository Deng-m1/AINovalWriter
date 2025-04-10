
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart';

/// 编辑器仓库接口
///
/// 定义与编辑器相关的所有API操作
abstract class EditorRepository {
  /// 获取小说
  Future<Novel?> getNovel(String novelId);

  /// 获取小说详情（分页加载场景）
  /// 基于上次编辑章节为中心，获取前后指定数量的章节及其场景内容
  Future<Novel?> getNovelWithPaginatedScenes(String novelId, String lastEditedChapterId, {int chaptersLimit = 5});

  /// 加载更多章节场景
  /// 根据方向（向上或向下）加载更多章节的场景内容
  Future<Map<String, List<Scene>>> loadMoreScenes(String novelId, String fromChapterId, String direction, {int chaptersLimit = 5});

  /// 保存小说数据
  Future<bool> saveNovel(Novel novel);

  /// 获取场景内容
  Future<Scene?> getSceneContent(
      String novelId, String actId, String chapterId, String sceneId);

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
  Future<EditorContent> getEditorContent(
      String novelId, String chapterId, String sceneId);

  /// 保存编辑器内容
  Future<void> saveEditorContent(EditorContent content);

  /// 获取编辑器设置
  Future<Map<String, dynamic>> getEditorSettings();

  /// 保存编辑器设置
  Future<void> saveEditorSettings(Map<String, dynamic> settings);

  /// 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId);

  /// 创建修订版本
  Future<Revision> createRevision(
      String novelId, String chapterId, Revision revision);

  /// 应用修订版本
  Future<void> applyRevision(
      String novelId, String chapterId, String revisionId);
      
  /// 更新小说元数据
  Future<void> updateNovelMetadata({
    required String novelId,
    required String title,
    String? author,
    String? series,
  });
  
  /// 获取封面上传凭证
  Future<Map<String, dynamic>> getCoverUploadCredential({
    required String novelId,
    required String fileName,
  });
  
  /// 更新小说封面
  Future<void> updateNovelCover({
    required String novelId,
    required String coverUrl,
  });
  
  /// 归档小说
  Future<void> archiveNovel({
    required String novelId,
  });
  
  /// 删除小说
  Future<void> deleteNovel({
    required String novelId,
  });
  
  /// 为指定场景生成摘要
  Future<String> summarizeScene(String sceneId, {String? styleInstructions});
  
  /// 根据摘要生成场景内容（流式）
  Stream<String> generateSceneFromSummaryStream(
    String novelId, 
    String summary, 
    {String? chapterId, String? styleInstructions}
  );
  
  /// 根据摘要生成场景内容（非流式）
  Future<String> generateSceneFromSummary(
    String novelId, 
    String summary, 
    {String? chapterId, String? styleInstructions}
  );
}
