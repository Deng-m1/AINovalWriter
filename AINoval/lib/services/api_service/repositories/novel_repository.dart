import 'package:ainoval/models/novel_structure.dart';

/// 小说仓库接口
/// 
/// 定义与小说相关的所有API操作
abstract class NovelRepository {
  /// 获取所有小说
  Future<List<Novel>> fetchNovels();
  
  /// 获取单个小说
  Future<Novel> fetchNovel(String id);
  
  /// 创建小说
  Future<Novel> createNovel(String title, {String? description, String? coverImage});
  
  /// 根据作者ID获取小说列表
  Future<List<Novel>> fetchNovelsByAuthor(String authorId);
  
  /// 搜索小说
  Future<List<Novel>> searchNovelsByTitle(String title);
  
  /// 更新小说
  Future<Novel> updateNovel(Novel novel);
  
  /// 删除小说
  Future<void> deleteNovel(String id);
  
  /// 获取场景内容
  Future<Scene> fetchSceneContent(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId
  );
  
  /// 更新场景内容
  Future<Scene> updateSceneContent(
    String novelId, 
    String actId, 
    String chapterId, 
    String sceneId,
    Scene scene
  );
  
  /// 更新摘要内容
  Future<Summary> updateSummary(
    String novelId, 
    String actId, 
    String chapterId,
    String sceneId,
    Summary summary
  );
} 