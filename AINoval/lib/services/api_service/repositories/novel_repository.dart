import 'package:ainoval/models/import_status.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/scene_version.dart';

/// 小说仓库接口
///
/// 定义与小说相关的所有API操作
abstract class NovelRepository {
  /// 获取所有小说
  Future<List<Novel>> fetchNovels();

  /// 获取单个小说
  Future<Novel> fetchNovel(String id);

  /// 创建小说
  Future<Novel> createNovel(String title,
      {String? description, String? coverImage});

  /// 根据作者ID获取小说列表
  Future<List<Novel>> fetchNovelsByAuthor(String authorId);

  /// 搜索小说
  Future<List<Novel>> searchNovelsByTitle(String title);

  /// 删除小说
  Future<void> deleteNovel(String id);

  /// 获取场景内容
  Future<Scene> fetchSceneContent(
      String novelId, String actId, String chapterId, String sceneId);

  /// 更新场景内容
  Future<Scene> updateSceneContent(String novelId, String actId,
      String chapterId, String sceneId, Scene scene);

  /// 更新摘要内容
  Future<Summary> updateSummary(String novelId, String actId, String chapterId,
      String sceneId, Summary summary);

  /// 更新场景内容并保存历史版本
  Future<Scene> updateSceneContentWithHistory(String novelId, String chapterId,
      String sceneId, String content, String userId, String reason);

  /// 获取场景的历史版本列表
  Future<List<SceneHistoryEntry>> getSceneHistory(
      String novelId, String chapterId, String sceneId);

  /// 恢复场景到指定的历史版本
  Future<Scene> restoreSceneVersion(String novelId, String chapterId,
      String sceneId, int historyIndex, String userId, String reason);

  /// 对比两个场景版本
  Future<SceneVersionDiff> compareSceneVersions(String novelId,
      String chapterId, String sceneId, int versionIndex1, int versionIndex2);

  /// 导入小说文件
  ///
  /// 返回导入任务的ID
  Future<String> importNovel(List<int> fileBytes, String fileName);

  /// 获取导入任务状态流
  ///
  /// 返回导入状态的实时更新
  Stream<ImportStatus> getImportStatus(String jobId);

  /// 取消导入任务
  ///
  /// - [jobId]: 导入任务ID
  /// - 返回: 是否成功取消
  Future<bool> cancelImport(String jobId);
}
