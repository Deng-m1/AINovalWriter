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
    this.author,
  });
  
  /// 从JSON创建Novel实例
  factory Novel.fromJson(Map<String, dynamic> json) {
    // 检查是否为NovelWithScenesDto格式
    bool isNovelWithScenesDto = json.containsKey('novel') && json.containsKey('scenesByChapter');
    
    // 如果是NovelWithScenesDto格式，提取novel部分
    Map<String, dynamic> novelData = isNovelWithScenesDto ? json['novel'] as Map<String, dynamic> : json;
    Map<String, List<dynamic>>? scenesByChapter = isNovelWithScenesDto 
        ? (json['scenesByChapter'] as Map<String, dynamic>).map((key, value) => 
            MapEntry(key, value as List<dynamic>))
        : null;
    
    // 提取作者信息
    Map<String, dynamic>? authorData;
    if (novelData.containsKey('author') && novelData['author'] is Map) {
      authorData = novelData['author'] as Map<String, dynamic>;
    }
    
    // 提取所有act和chapter信息
    List<Act> acts = [];
    if (novelData.containsKey('structure') && 
        novelData['structure'] is Map && 
        (novelData['structure'] as Map).containsKey('acts')) {
      acts = ((novelData['structure'] as Map)['acts'] as List)
        .map((actJson) {
          final Map<String, dynamic> act = actJson as Map<String, dynamic>;
          
          // 处理chapters
          List<Chapter> chapters = [];
          if (act.containsKey('chapters') && act['chapters'] is List) {
            chapters = (act['chapters'] as List).map((chapterJson) {
              final Map<String, dynamic> chapter = chapterJson as Map<String, dynamic>;
              final String chapterId = chapter['id'];
              
              // 如果是NovelWithScenesDto格式且有该章节的场景数据，添加场景
              List<Scene> scenes = [];
              if (isNovelWithScenesDto && scenesByChapter != null && scenesByChapter.containsKey(chapterId)) {
                scenes = scenesByChapter[chapterId]!
                    .map((sceneJson) => Scene.fromJson(sceneJson as Map<String, dynamic>))
                    .toList();
              }
              
              return Chapter(
                id: chapterId,
                title: chapter['title'],
                order: chapter['order'],
                scenes: scenes,
              );
            }).toList();
          }
          
          return Act(
            id: act['id'],
            title: act['title'],
            order: act['order'],
            chapters: chapters,
          );
        }).toList();
    }
    
    // 解析创建时间和更新时间
    DateTime createdAt;
    DateTime updatedAt;
    
    try {
      createdAt = novelData.containsKey('createdAt') 
          ? DateTime.parse(novelData['createdAt']) 
          : DateTime.now();
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    try {
      updatedAt = novelData.containsKey('updatedAt') 
          ? DateTime.parse(novelData['updatedAt']) 
          : DateTime.now();
    } catch (e) {
      updatedAt = DateTime.now();
    }
    
    return Novel(
      id: novelData['id'],
      title: novelData['title'] ?? '无标题',
      coverImagePath: novelData['coverImage'] ?? novelData['coverImagePath'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      acts: acts,
      lastEditedChapterId: novelData['lastEditedChapterId'],
      author: authorData != null ? Author.fromJson(authorData) : null,
    );
  }
  final String id;
  final String title;
  final String coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Act> acts;
  final String? lastEditedChapterId; // 上次编辑的章节ID
  final Author? author; // 作者信息
  
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
      'author': author?.toJson(),
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
    Author? author,
  }) {
    return Novel(
      id: id ?? this.id,
      title: title ?? this.title,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acts: acts ?? this.acts,
      lastEditedChapterId: lastEditedChapterId ?? this.lastEditedChapterId,
      author: author ?? this.author,
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
  void addScene(Scene newScene) {
    scenes.add(newScene);
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
    required this.wordCount,
    required this.summary,
    required this.lastEdited,
    this.version = 1,
    this.history = const [],
  });
  
  /// 从JSON创建Scene实例
  factory Scene.fromJson(Map<String, dynamic> json) {
    // 处理summary，后端可能直接包含content字段
    final summary = json.containsKey('summary')
        ? Summary.fromJson(json['summary'])
        : Summary(
            id: '${json['id']}_summary',
            content: '',
          );

    // 解析历史记录
    List<HistoryEntry> history = [];
    if (json.containsKey('history') && json['history'] is List) {
      history = (json['history'] as List)
          .map((historyJson) => HistoryEntry.fromJson(historyJson))
          .toList();
    }

    // 解析lastEdited字段
    DateTime lastEdited;
    if (json.containsKey('lastEdited')) {
      try {
        lastEdited = DateTime.parse(json['lastEdited']);
      } catch (e) {
        lastEdited = json.containsKey('updatedAt')
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now();
      }
    } else if (json.containsKey('updatedAt')) {
      lastEdited = DateTime.parse(json['updatedAt']);
    } else {
      lastEdited = DateTime.now();
    }

    return Scene(
      id: json['id'],
      content: json['content'] ?? '',
      wordCount: json['wordCount'] ?? 0,
      summary: summary,
      lastEdited: lastEdited,
      version: json['version'] ?? 1,
      history: history,
    );
  }
  final String id;
  final String content;
  final int wordCount;
  final Summary summary;
  final DateTime lastEdited;
  final int version;
  final List<HistoryEntry> history;
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'wordCount': wordCount,
      'summary': summary.toJson(),
      'lastEdited': lastEdited.toIso8601String(),
      'version': version,
      'history': history.map((entry) => entry.toJson()).toList(),
    };
  }
  
  /// 创建Scene的副本
  Scene copyWith({
    String? id,
    String? content,
    int? wordCount,
    Summary? summary,
    DateTime? lastEdited,
    int? version,
    List<HistoryEntry>? history,
  }) {
    return Scene(
      id: id ?? this.id,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      summary: summary ?? this.summary,
      lastEdited: lastEdited ?? this.lastEdited,
      version: version ?? this.version,
      history: history ?? this.history,
    );
  }
  
  /// 创建一个空的场景
  static Scene createEmpty() {
    final now = DateTime.now();
    return Scene(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: '',
      wordCount: 0,
      summary: Summary(
        id: '${DateTime.now().millisecondsSinceEpoch}_summary',
        content: '',
      ),
      lastEdited: now,
      version: 1,
      history: [],
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
    // 检查json是否为null
    if (json == null) {
      return Summary.createEmpty();
    }
    
    return Summary(
      id: json['id'] ?? 'summary_${DateTime.now().millisecondsSinceEpoch}',
      content: json['content'] ?? '',
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

class HistoryEntry {

  HistoryEntry({
    this.content,
    required this.updatedAt,
    required this.updatedBy,
    required this.reason,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime updatedAt;
    try {
      updatedAt = DateTime.parse(json['updatedAt']);
    } catch (e) {
      updatedAt = DateTime.now();
    }

    return HistoryEntry(
      content: json['content'],
      updatedAt: updatedAt,
      updatedBy: json['updatedBy'] ?? 'unknown',
      reason: json['reason'] ?? '',
    );
  }
  final String? content;
  final DateTime updatedAt;
  final String updatedBy;
  final String reason;

  Map<String, dynamic> toJson() => {
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'updatedBy': updatedBy,
    'reason': reason,
  };
}

/// 作者信息模型
class Author {
  Author({
    required this.id,
    required this.username,
  });
  
  /// 从JSON创建Author实例
  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'] ?? '',
      username: json['username'] ?? '未知作者',
    );
  }
  
  final String id;
  final String username;
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
  
  /// 创建Author的副本
  Author copyWith({
    String? id,
    String? username,
  }) {
    return Author(
      id: id ?? this.id,
      username: username ?? this.username,
    );
  }
} 