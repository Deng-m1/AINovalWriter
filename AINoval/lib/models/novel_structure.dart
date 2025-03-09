import 'dart:convert';

/// 小说模型
class Novel {
  
  Novel({
    required this.id,
    required this.title,
    this.coverImagePath = '',
    required this.createdAt,
    required this.updatedAt,
    this.acts = const [],
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
    );
  }
  final String id;
  final String title;
  final String coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Act> acts;
  
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
  }) {
    return Novel(
      id: id ?? this.id,
      title: title ?? this.title,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acts: acts ?? this.acts,
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
  
  /// 获取指定Scene
  Scene? getScene(String actId, String chapterId) {
    final chapter = getChapter(actId, chapterId);
    return chapter?.scene;
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
    final newChapter = Chapter(
      id: 'chapter_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      order: chapters.length + 1,
      scene: Scene.createEmpty(),
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
    required this.scene,
  });
  
  /// 从JSON创建Chapter实例
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      title: json['title'],
      order: json['order'],
      scene: Scene.fromJson(json['scene']),
    );
  }
  final String id;
  final String title;
  final int order;
  final Scene scene;
  
  /// 获取章节字数
  int get wordCount => scene.wordCount;
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'order': order,
      'scene': scene.toJson(),
    };
  }
  
  /// 创建Chapter的副本
  Chapter copyWith({
    String? id,
    String? title,
    int? order,
    Scene? scene,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      scene: scene ?? this.scene,
    );
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