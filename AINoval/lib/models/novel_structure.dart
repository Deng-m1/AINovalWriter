/// 小说模型
class Novel {
  
  Novel({
    required this.id,
    required this.title,
    this.coverImagePath = '',
    required this.createdAt,
    required this.updatedAt,
    this.acts = const [],
    this.lastEditedChapterId,
  });
  
  /// 从JSON创建Novel实例
  factory Novel.fromJson(Map<String, dynamic> json) {
    return Novel(
      id: json['id'],
      title: json['title'],
      coverImagePath: json['coverImagePath'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      acts: (json['acts'] as List?)
          ?.map((actJson) => Act.fromJson(actJson))
          .toList() ?? [],
      lastEditedChapterId: json['lastEditedChapterId'],
    );
  }
  final String id;
  final String title;
  final String coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Act> acts;
  final String? lastEditedChapterId; // 上次编辑的章节ID
  
  /// 计算小说总字数
  int get wordCount {
    return acts.fold(0, (sum, act) => sum + act.wordCount);
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverImagePath': coverImagePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'acts': acts.map((act) => act.toJson()).toList(),
      'lastEditedChapterId': lastEditedChapterId,
    };
  }
  
  /// 创建Novel的副本
  Novel copyWith({
    String? id,
    String? title,
    String? coverImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Act>? acts,
    String? lastEditedChapterId,
  }) {
    return Novel(
      id: id ?? this.id,
      title: title ?? this.title,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acts: acts ?? this.acts,
      lastEditedChapterId: lastEditedChapterId ?? this.lastEditedChapterId,
    );
  }
  
  /// 创建一个空的小说结构
  static Novel createEmpty(String id, String title) {
    final now = DateTime.now();
    return Novel(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      acts: [],
    );
  }
  
  /// 添加一个新的Act
  Novel addAct(String title) {
    final newAct = Act(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      order: acts.length + 1,
      chapters: [],
    );
    
    return copyWith(
      acts: [...acts, newAct],
      updatedAt: DateTime.now(),
    );
  }
  
  /// 获取指定Act
  Act? getAct(String actId) {
    try {
      return acts.firstWhere((act) => act.id == actId);
    } catch (e) {
      return null;
    }
  }
  
  /// 获取指定Chapter
  Chapter? getChapter(String actId, String chapterId) {
    final act = getAct(actId);
    if (act == null) return null;
    
    try {
      return act.chapters.firstWhere((chapter) => chapter.id == chapterId);
    } catch (e) {
      return null;
    }
  }
  
  /// 根据章节ID直接获取章节，不需要知道Act ID
  Chapter? getChapterById(String chapterId) {
    for (final act in acts) {
      try {
        final chapter = act.chapters.firstWhere((chapter) => chapter.id == chapterId);
        return chapter;
      } catch (e) {
        // 继续查找下一个act
      }
    }
    return null;
  }
  
  /// 获取指定Scene
  Scene? getScene(String actId, String chapterId, {String? sceneId}) {
    final chapter = getChapter(actId, chapterId);
    if (chapter == null) return null;
    
    if (sceneId != null) {
      // 如果提供了sceneId，则获取特定Scene
      return chapter.getScene(sceneId);
    } else if (chapter.scenes.isNotEmpty) {
      // 否则返回第一个Scene
      return chapter.scenes.first;
    }
    
    return null;
  }
  
  /// 获取上下文章节（前后n章）
  List<Chapter> getContextChapters(String chapterId, int n) {
    // 提取所有章节
    List<Chapter> allChapters = [];
    for (final act in acts) {
      allChapters.addAll(act.chapters);
    }
    
    // 按order排序
    allChapters.sort((a, b) => a.order.compareTo(b.order));
    
    // 找到当前章节的索引
    int currentIndex = allChapters.indexWhere((chapter) => chapter.id == chapterId);
    if (currentIndex == -1) {
      // 如果找不到当前章节，返回前n章
      return allChapters.take(n).toList();
    }
    
    // 计算前后n章的范围
    int startIndex = (currentIndex - n) < 0 ? 0 : (currentIndex - n);
    int endIndex = (currentIndex + n) >= allChapters.length ? allChapters.length - 1 : (currentIndex + n);
    
    // 提取前后n章
    return allChapters.sublist(startIndex, endIndex + 1);
  }
  
  /// 更新最后编辑的章节ID
  Novel updateLastEditedChapter(String chapterId) {
    return copyWith(
      lastEditedChapterId: chapterId,
      updatedAt: DateTime.now(),
    );
  }
}

/// 幕模型（如Act 1, Act 2等）
class Act {
  
  Act({
    required this.id,
    required this.title,
    required this.order,
    this.chapters = const [],
  });
  
  /// 从JSON创建Act实例
  factory Act.fromJson(Map<String, dynamic> json) {
    return Act(
      id: json['id'],
      title: json['title'],
      order: json['order'],
      chapters: (json['chapters'] as List?)
          ?.map((chapterJson) => Chapter.fromJson(chapterJson))
          .toList() ?? [],
    );
  }
  final String id;
  final String title;
  final int order;
  final List<Chapter> chapters;
  
  /// 计算幕的总字数
  int get wordCount {
    return chapters.fold(0, (sum, chapter) => sum + chapter.wordCount);
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'order': order,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
  }
  
  /// 创建Act的副本
  Act copyWith({
    String? id,
    String? title,
    int? order,
    List<Chapter>? chapters,
  }) {
    return Act(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      chapters: chapters ?? this.chapters,
    );
  }
  
  /// 添加一个新的Chapter
  Act addChapter(String title) {
    // 创建一个默认的Scene
    final defaultScene = Scene.createEmpty();
    
    final newChapter = Chapter(
      id: 'chapter_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      order: chapters.length + 1,
      scenes: [defaultScene], // 包含一个默认的Scene
    );
    
    return copyWith(
      chapters: [...chapters, newChapter],
    );
  }
  
  /// 获取指定Chapter
  Chapter? getChapter(String chapterId) {
    try {
      return chapters.firstWhere((chapter) => chapter.id == chapterId);
    } catch (e) {
      return null;
    }
  }
}

/// 章节模型
class Chapter {
  
  Chapter({
    required this.id,
    required this.title,
    required this.order,
    required this.scenes,
  });
  
  /// 从JSON创建Chapter实例
  factory Chapter.fromJson(Map<String, dynamic> json) {
    // 兼容旧版本数据，如果是单个scene，则转换为scenes列表
    List<Scene> parseScenes() {
      if (json.containsKey('scene')) {
        // 旧版本数据，单个scene
        return [Scene.fromJson(json['scene'])];
      } else if (json.containsKey('scenes') && json['scenes'] is List) {
        // 新版本数据，scenes列表
        return (json['scenes'] as List)
            .map((sceneJson) => Scene.fromJson(sceneJson))
            .toList();
      } else {
        // 默认返回空列表
        return [];
      }
    }
    
    return Chapter(
      id: json['id'],
      title: json['title'],
      order: json['order'],
      scenes: parseScenes(),
    );
  }
  final String id;
  final String title;
  final int order;
  final List<Scene> scenes;
  
  /// 获取章节字数
  int get wordCount {
    return scenes.fold(0, (sum, scene) => sum + scene.wordCount);
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'order': order,
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
    };
  }
  
  /// 创建Chapter的副本
  Chapter copyWith({
    String? id,
    String? title,
    int? order,
    List<Scene>? scenes,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      scenes: scenes ?? this.scenes,
    );
  }
  
  /// 添加一个新的Scene
  Chapter addScene() {
    final newScene = Scene.createEmpty();
    return copyWith(
      scenes: [...scenes, newScene],
    );
  }
  
  /// 获取指定Scene
  Scene? getScene(String sceneId) {
    try {
      return scenes.firstWhere((scene) => scene.id == sceneId);
    } catch (e) {
      return null;
    }
  }
  
  /// 更新指定Scene
  Chapter updateScene(String sceneId, Scene updatedScene) {
    final updatedScenes = scenes.map((scene) {
      if (scene.id == sceneId) {
        return updatedScene;
      }
      return scene;
    }).toList();
    
    return copyWith(scenes: updatedScenes);
  }
}

/// 场景模型
class Scene {
  
  Scene({
    required this.id,
    required this.content,
    this.wordCount = 0,
    required this.summary,
    required this.lastEdited,
  });
  
  /// 从JSON创建Scene实例
  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'],
      content: json['content'],
      wordCount: json['wordCount'] ?? 0,
      summary: Summary.fromJson(json['summary']),
      lastEdited: DateTime.parse(json['lastEdited']),
    );
  }
  final String id;
  final String content;
  final int wordCount;
  final Summary summary;
  final DateTime lastEdited;
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'wordCount': wordCount,
      'summary': summary.toJson(),
      'lastEdited': lastEdited.toIso8601String(),
    };
  }
  
  /// 创建Scene的副本
  Scene copyWith({
    String? id,
    String? content,
    int? wordCount,
    Summary? summary,
    DateTime? lastEdited,
  }) {
    return Scene(
      id: id ?? this.id,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      summary: summary ?? this.summary,
      lastEdited: lastEdited ?? this.lastEdited,
    );
  }
  
  /// 创建一个空的场景
  static Scene createEmpty() {
    final now = DateTime.now();
    return Scene(
      id: 'scene_${now.millisecondsSinceEpoch}',
      content: '{"ops":[{"insert":"\\n"}]}',
      wordCount: 0,
      summary: Summary.createEmpty(),
      lastEdited: now,
    );
  }
}

/// 摘要模型
class Summary {
  
  Summary({
    required this.id,
    required this.content,
  });
  
  /// 从JSON创建Summary实例
  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      id: json['id'],
      content: json['content'],
    );
  }
  final String id;
  final String content;
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
    };
  }
  
  /// 创建Summary的副本
  Summary copyWith({
    String? id,
    String? content,
  }) {
    return Summary(
      id: id ?? this.id,
      content: content ?? this.content,
    );
  }
  
  /// 创建一个空的摘要
  static Summary createEmpty() {
    return Summary(
      id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
      content: '',
    );
  }
} 