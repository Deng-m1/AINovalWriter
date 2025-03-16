import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/mock_data_generator.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_models.dart';


/// 模拟数据服务，提供所有模拟数据
class MockDataService {
  factory MockDataService() => _instance;
  MockDataService._internal() {
    _initializeCache();
  }
  // 单例模式
  static final MockDataService _instance = MockDataService._internal();
  
  // 模拟数据缓存
  final Map<String, novel_models.Novel> _novelCache = {};
  bool _isInitialized = false;
  
  final Uuid _uuid = const Uuid();
  
  // 初始化缓存
  void _initializeCache() {
    if (!_isInitialized) {
      final novels = null;
      for (final novel in novels) {
        // 同时存储原始ID和带前缀的ID，确保两种形式都能匹配
        _novelCache[novel.id] = novel;
        if (!novel.id.startsWith('novel-')) {
          _novelCache['novel-${novel.id}'] = novel;
        }
      }
      _isInitialized = true;
      AppLogger.i('Services/mock_data_service', '模拟数据服务缓存已初始化，共${_novelCache.length}个条目');
    }
  }
  
  /// 获取所有模拟小说
  List<novel_models.Novel> getAllNovels() {
    return _novelCache.values.toList();
  }
  
  /// 获取单个模拟小说
  novel_models.Novel? getNovel(String id) {
    // 尝试不同形式的ID
    String normalizedId = id;
    if (id.startsWith('novel-')) {
      normalizedId = id.substring(6); // 移除'novel-'前缀
    }
    
    // 先尝试直接匹配
    if (_novelCache.containsKey(id)) {
      AppLogger.i('Services/mock_data_service', '从模拟数据中找到小说: $id');
      return _novelCache[id];
    } 
    // 再尝试匹配不带前缀的ID
    else if (_novelCache.containsKey(normalizedId)) {
      AppLogger.i('Services/mock_data_service', '从模拟数据中找到小说(无前缀): $normalizedId');
      return _novelCache[normalizedId];
    }
    // 最后尝试匹配带前缀的ID
    else if (_novelCache.containsKey('novel-$normalizedId')) {
      AppLogger.i('Services/mock_data_service', '从模拟数据中找到小说(带前缀): novel-$normalizedId');
      return _novelCache['novel-$normalizedId'];
    } 
    else if (_novelCache.isNotEmpty) {
      // 如果找不到匹配的小说，返回第一个
      AppLogger.i('Services/mock_data_service', '未找到匹配的小说，返回第一个模拟数据项');
      return _novelCache.values.first;
    }
    
    return null;
  }
  
  /// 更新模拟小说
  void updateNovel(novel_models.Novel novel) {
    _novelCache[novel.id] = novel;
    
    // 同时更新带前缀的版本
    if (!novel.id.startsWith('novel-')) {
      _novelCache['novel-${novel.id}'] = novel;
    }
    
    AppLogger.i('Services/mock_data_service', '已更新模拟数据中的小说: ${novel.id}');
  }
  
  /// 创建新的模拟小说
  novel_models.Novel createNovel(String title) {
    final now = DateTime.now();
    final id = 'new-${now.millisecondsSinceEpoch}';
    
    final novel = novel_models.Novel(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      acts: [],
    );
    
    _novelCache[id] = novel;
    return novel;
  }
  
  /// 获取场景内容
  novel_models.Scene? getSceneContent(String novelId, String actId, String chapterId, String sceneId) {
    final novel = getNovel(novelId);
    if (novel == null) return null;
    
    try {
      final act = novel.acts.firstWhere((act) => act.id == actId);
      final chapter = act.chapters.firstWhere((chapter) => chapter.id == chapterId);
      
      if (chapter.scenes.isEmpty) return null;
      
      // 查找特定场景
      try {
        return chapter.scenes.firstWhere((s) => s.id == sceneId);
      } catch (e) {
        // 如果找不到特定场景，返回第一个场景
        return chapter.scenes.first;
      }
    } catch (e) {
      AppLogger.e('Services/mock_data_service', '获取模拟场景内容失败', e);
      return null;
    }
  }
  
  /// 更新场景内容
  void updateSceneContent(String novelId, String actId, String chapterId, String sceneId, novel_models.Scene scene) {
    final novel = getNovel(novelId);
    if (novel == null) {
      AppLogger.e('Services/mock_data_service', '更新场景内容失败：找不到小说 $novelId');
      return;
    }
    
    // 查找对应的Act
    final actIndex = novel.acts.indexWhere((a) => a.id == actId);
    if (actIndex == -1) {
      AppLogger.e('Services/mock_data_service', '更新场景内容失败：找不到Act $actId');
      return;
    }
    
    final act = novel.acts[actIndex];
    
    // 查找对应的Chapter
    final chapterIndex = act.chapters.indexWhere((c) => c.id == chapterId);
    if (chapterIndex == -1) {
      AppLogger.e('Services/mock_data_service', '更新场景内容失败：找不到Chapter $chapterId');
      return;
    }
    
    final chapter = act.chapters[chapterIndex];
    
    // 查找对应的Scene
    final sceneIndex = chapter.scenes.indexWhere((s) => s.id == sceneId);
    List<novel_models.Scene> updatedScenes;
    
    if (sceneIndex == -1) {
      // 如果找不到Scene，则添加新Scene
      AppLogger.i('Services/mock_data_service', '找不到Scene $sceneId，添加新Scene');
      updatedScenes = [...chapter.scenes, scene];
    } else {
      // 更新现有Scene
      updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
      updatedScenes[sceneIndex] = scene;
    }
    
    // 更新Chapter的Scenes
    final updatedChapter = chapter.copyWith(scenes: updatedScenes);
    
    // 更新Act的Chapters
    final updatedChapters = List<novel_models.Chapter>.from(act.chapters);
    updatedChapters[chapterIndex] = updatedChapter;
    final updatedAct = act.copyWith(chapters: updatedChapters);
    
    // 更新Novel的Acts
    final updatedActs = List<novel_models.Act>.from(novel.acts);
    updatedActs[actIndex] = updatedAct;
    final updatedNovel = novel.copyWith(
      acts: updatedActs,
      updatedAt: DateTime.now(),
    );
    
    // 更新缓存
    _novelCache[novel.id] = updatedNovel;
    
    // 同时更新带前缀的版本
    if (!novel.id.startsWith('novel-')) {
      _novelCache['novel-${novel.id}'] = updatedNovel;
    }
    
    AppLogger.i('Services/mock_data_service', '已更新模拟数据中的场景');
  }
  
  /// 更新摘要内容
  void updateSummary(String novelId, String actId, String chapterId, String sceneId, novel_models.Summary summary) {
    if (_novelCache.containsKey(novelId)) {
      final novel = _novelCache[novelId]!;
      final acts = novel.acts.map((act) {
        if (act.id == actId) {
          final chapters = act.chapters.map((chapter) {
            if (chapter.id == chapterId) {
              // 查找特定场景
              final sceneIndex = chapter.scenes.indexWhere((s) => s.id == sceneId);
              List<novel_models.Scene> updatedScenes;
              
              if (sceneIndex >= 0) {
                // 更新现有场景
                updatedScenes = List.from(chapter.scenes);
                updatedScenes[sceneIndex] = updatedScenes[sceneIndex].copyWith(summary: summary);
              } else {
                // 如果场景不存在，不做任何操作
                updatedScenes = chapter.scenes;
              }
              
              return chapter.copyWith(scenes: updatedScenes);
            }
            return chapter;
          }).toList();
          return act.copyWith(chapters: chapters);
        }
        return act;
      }).toList();
      
      _novelCache[novelId] = novel.copyWith(
        acts: acts,
        updatedAt: DateTime.now(),
      );
      
      // 同时更新带前缀的版本
      if (!novelId.startsWith('novel-')) {
        _novelCache['novel-$novelId'] = _novelCache[novelId]!;
      }
      
      AppLogger.i('Services/mock_data_service', '已更新模拟数据中的摘要');
    }
  }
  
  /// 获取编辑器内容
  EditorContent getEditorContent(String novelId, String chapterId, String sceneId) {
    final novel = getNovel(novelId);
    if (novel == null) {
      return EditorContent(
        id: '$novelId-$chapterId-$sceneId',
        content: '{"ops":[{"insert":"\\n"}]}',
        lastSaved: DateTime.now(),
      );
    }
    
    // 查找对应的章节和场景
    String content = '{"ops":[{"insert":"\\n"}]}';
    final Map<String, SceneContent> scenes = {};
    
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        if (chapter.id == chapterId) {
          // 查找特定场景
          try {
            final scene = chapter.scenes.firstWhere((s) => s.id == sceneId);
            content = scene.content;
          } catch (e) {
            // 如果找不到特定场景，使用第一个场景（如果有）
            if (chapter.scenes.isNotEmpty) {
              content = chapter.scenes.first.content;
            }
          }
        }
        
        // 为所有场景创建SceneContent
        for (final scene in chapter.scenes) {
          final sceneKey = '${act.id}_${chapter.id}_${scene.id}';
          scenes[sceneKey] = SceneContent(
            content: scene.content,
            summary: scene.summary.content,
            title: chapter.title,
            subtitle: '',
          );
        }
      }
    }
    
    return EditorContent(
      id: chapterId,
      content: content,
      lastSaved: DateTime.now(),
      scenes: scenes,
    );
  }
  

  

} 