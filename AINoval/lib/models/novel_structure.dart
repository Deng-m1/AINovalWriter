import 'package:ainoval/utils/logger.dart';

/// 小说模型
class Novel {
  Novel({
    required this.id,
    required this.title,
    this.coverUrl= '',
    required this.createdAt,
    required this.updatedAt,
    this.acts = const [],
    this.lastEditedChapterId,
    this.author,
    this.wordCount = 0,
    this.readTime = 0,
    this.version = 1,
    this.contributors = const <String>[],
  });

  /// 从JSON创建Novel实例
  factory Novel.fromJson(Map<String, dynamic> json) {
    AppLogger.v(
        'NovelModel', 'Parsing Novel from JSON: ${json['id']}'); // 添加日志确认进入
    try {
      // --- 这是关键部分 ---
      List<Act> parsedActs = [];
      if (json['acts'] != null && json['acts'] is List) {
        // 检查 'acts' 是否存在且是一个列表
        AppLogger.v('NovelModel',
            'Found "acts" list with ${json['acts'].length} items.'); // 记录找到的 acts 数量
        parsedActs = (json['acts'] as List<dynamic>)
            .map((actJson) {
              if (actJson is Map<String, dynamic>) {
                // 对列表中的每个元素调用 Act.fromJson
                return Act.fromJson(actJson);
              } else {
                // 处理无效数据项
                AppLogger.w('NovelModel',
                    'Invalid item found in "acts" list: $actJson');
                return null; // 或者抛出错误，或者返回一个默认的 Act
              }
            })
            .whereType<Act>() // 过滤掉可能的 null 值
            .toList();
        AppLogger.v('NovelModel',
            'Successfully parsed ${parsedActs.length} acts.'); // 记录成功解析的数量
      } else {
        AppLogger.w('NovelModel',
            '"acts" field is missing, null, or not a list in JSON for Novel ${json['id']}'); // 记录 acts 字段问题
      }
      // --- 关键部分结束 ---

      // 解析元数据
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      final wordCount = metadata['wordCount'] as int? ?? 0;
      final readTime = metadata['readTime'] as int? ?? 0;
      final version = metadata['version'] as int? ?? 1;
      final contributors = (metadata['contributors'] as List?)?.cast<String>() ?? <String>[];

      return Novel(
        id: json['id'] as String,
        title: json['title'] as String,
        coverUrl: json['coverUrl'] as String? ?? '', // 处理可能的 null
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        acts: parsedActs, // 使用上面解析得到的列表
        lastEditedChapterId: json['lastEditedChapterId'] as String?, // 如果有这个字段
        author: json['author'] != null
            ? Author.fromJson(json['author'])
            : null, // 如果有 Author 字段
        wordCount: wordCount,
        readTime: readTime,
        version: version,
        contributors: contributors,
      );
    } catch (e, stackTrace) {
      AppLogger.e('NovelModel', 'Error parsing Novel from JSON: ${json['id']}',
          e, stackTrace);
      // 可以抛出错误，或者返回一个带有默认值的对象，取决于你的错误处理策略
      rethrow; // 重新抛出错误，让上层知道解析失败
      // 或者返回一个默认/错误状态的 Novel 对象
      // return Novel(id: json['id'] ?? 'error', title: 'Error Parsing', acts: [], /* ... 其他默认值 ... */);
    }
  }
  final String id;
  final String title;
  final String coverUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Act> acts;
  final String? lastEditedChapterId; // 上次编辑的章节ID
  final Author? author; // 作者信息
  final int wordCount; // 总字数（来自元数据）
  final int readTime; // 估计阅读时间（分钟）
  final int version; // 文档版本号
  final List<String> contributors; // 贡献者列表

  /// 计算小说总字数（如果需要动态计算）
  int calculateWordCount() {
    int totalWordCount = 0;
    for (final act in acts) {
      for (final chapter in act.chapters) {
        for (final scene in chapter.scenes) {
          totalWordCount += scene.wordCount;
        }
      }
    }
    return totalWordCount;
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'acts': acts.map((act) => act.toJson()).toList(),
      'lastEditedChapterId': lastEditedChapterId,
      'author': author?.toJson(),
      'metadata': {
        'wordCount': wordCount,
        'readTime': readTime,
        'version': version,
        'contributors': contributors,
      },
    };
  }

  /// 创建Novel的副本
  Novel copyWith({
    String? id,
    String? title,
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Act>? acts,
    String? lastEditedChapterId,
    Author? author,
    int? wordCount,
    int? readTime,
    int? version,
    List<String>? contributors,
  }) {
    return Novel(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acts: acts ?? this.acts,
      lastEditedChapterId: lastEditedChapterId ?? this.lastEditedChapterId,
      author: author ?? this.author,
      wordCount: wordCount ?? this.wordCount,
      readTime: readTime ?? this.readTime,
      version: version ?? this.version,
      contributors: contributors ?? this.contributors,
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
        final chapter =
            act.chapters.firstWhere((chapter) => chapter.id == chapterId);
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
    int currentIndex =
        allChapters.indexWhere((chapter) => chapter.id == chapterId);
    if (currentIndex == -1) {
      // 如果找不到当前章节，返回前n章
      return allChapters.take(n).toList();
    }

    // 计算前后n章的范围
    int startIndex = (currentIndex - n) < 0 ? 0 : (currentIndex - n);
    int endIndex = (currentIndex + n) >= allChapters.length
        ? allChapters.length - 1
        : (currentIndex + n);

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
    List<Chapter> parsedChapters = [];
    if (json['chapters'] != null && json['chapters'] is List) {
      parsedChapters = (json['chapters'] as List<dynamic>)
          .map((chapterJson) =>
              Chapter.fromJson(chapterJson as Map<String, dynamic>))
          .toList();
    }
    return Act(
      id: json['id'] as String,
      title: json['title'] as String,
      order: json['order'] as int,
      chapters: parsedChapters, // 使用解析后的列表
    );
  }
  final String id;
  final String title;
  final int order;
  final List<Chapter> chapters;

  /// 计算Act的总字数
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
    this.scenes = const [],
  });

  /// 从JSON创建Chapter实例
  factory Chapter.fromJson(Map<String, dynamic> json) {
    List<Scene> parsedScenes = [];
    if (json['scenes'] != null && json['scenes'] is List) {
      parsedScenes = (json['scenes'] as List<dynamic>)
          .map((sceneJson) => Scene.fromJson(sceneJson as Map<String, dynamic>))
          .toList();
    }
    return Chapter(
      id: json['id'] as String,
      title: json['title'] as String,
      order: json['order'] as int,
      scenes: parsedScenes, // 使用解析后的列表
    );
  }
  final String id;
  final String title;
  final int order;
  final List<Scene> scenes;

  /// 计算章节的总字数
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
    return Scene(
      id: json['id'],
      content: json['content'] ?? '',
      wordCount: json['wordCount'] ?? 0,
      summary: Summary.fromJson(json['summary'] as Map<String, dynamic>),
      lastEdited: DateTime.parse(json['lastEdited'] as String),
      version: json['version'] ?? 1,
      history: [],
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
    const defaultContent = '{"ops":[{"insert":"\\n"}]}'; // <-- 确保是这个值
    final now = DateTime.now();
    return Scene(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: defaultContent,
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

  /// 创建一个默认的场景
  static Scene createDefault(String sceneIdBase) {
    const defaultContent = '{"ops":[{"insert":"\\n"}]}'; // <-- 确保是这个值
    final now = DateTime.now();
    return Scene(
      id: sceneIdBase,
      content: defaultContent,
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
    return Summary(
      id: json['id'] as String,
      content: json['content'] as String,
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
