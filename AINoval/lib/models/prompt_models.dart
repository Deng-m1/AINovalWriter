import 'package:json_annotation/json_annotation.dart';


/// AI功能类型枚举
enum AIFeatureType {
  /// 场景生成摘要
  sceneToSummary,
  
  /// 摘要生成场景
  summaryToScene
}

/// 提示词类型枚举
enum PromptType {
  /// 摘要提示词
  summary,
  
  /// 风格提示词
  style
}

/// 提示词优化风格
enum OptimizationStyle {
  /// 专业风格
  professional,
  
  /// 创意风格
  creative,
  
  /// 简洁风格
  concise
}

/// 提示词模板类型
enum TemplateType {
  /// 公共模板
  public,
  
  /// 私有模板
  private
}

/// 提示词项
class PromptItem {
  final String id;
  final String title;
  final String content;
  final PromptType type;
  
  PromptItem({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
  });
  
  factory PromptItem.fromJson(Map<String, dynamic> json) {
    return PromptItem(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      type: PromptType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => PromptType.summary,
      ),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.toString().split('.').last,
    };
  }
}

/// 提示词数据模型
class PromptData {
  /// 用户自定义提示词
  final String userPrompt;
  
  /// 系统默认提示词
  final String defaultPrompt;
  
  /// 是否为用户自定义
  final bool isCustomized;
  
  /// 提示词项列表
  final List<PromptItem> promptItems;

  PromptData({
    required this.userPrompt,
    required this.defaultPrompt,
    required this.isCustomized,
    this.promptItems = const [],
  });
  
  /// 获取当前生效的提示词（如果自定义则返回用户提示词，否则返回默认提示词）
  String get activePrompt => isCustomized ? userPrompt : defaultPrompt;
  
  /// 获取摘要类型的提示词列表
  List<PromptItem> get summaryPrompts => 
      promptItems.where((item) => item.type == PromptType.summary).toList();
      
  /// 获取风格类型的提示词列表
  List<PromptItem> get stylePrompts => 
      promptItems.where((item) => item.type == PromptType.style).toList();
}

/// 提示词模板模型
class PromptTemplate {
  /// 模板ID
  final String id;
  
  /// 模板名称
  final String name;
  
  /// 模板内容
  final String content;
  
  /// 功能类型
  final AIFeatureType featureType;
  
  /// 是否为公共模板
  final bool isPublic;
  
  /// 作者ID（公共模板可为null或系统ID）
  final String? authorId;
  
  /// 源模板ID（如果是从公共模板复制的）
  final String? sourceTemplateId;
  
  /// 是否为官方验证模板
  final bool isVerified;
  
  /// 用户是否收藏（仅对私有模板有效）
  final bool isFavorite;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 更新时间
  final DateTime updatedAt;

  PromptTemplate({
    required this.id,
    required this.name,
    required this.content,
    required this.featureType,
    required this.isPublic,
    this.authorId,
    this.sourceTemplateId,
    this.isVerified = false,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// 创建私有模板
  factory PromptTemplate.createPrivate({
    required String id,
    required String name,
    required String content,
    required AIFeatureType featureType,
    required String authorId,
    String? sourceTemplateId,
    bool isFavorite = false,
  }) {
    final now = DateTime.now();
    return PromptTemplate(
      id: id,
      name: name,
      content: content,
      featureType: featureType,
      isPublic: false,
      authorId: authorId,
      sourceTemplateId: sourceTemplateId,
      isVerified: false,
      isFavorite: isFavorite,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// 从公共模板复制创建私有模板
  factory PromptTemplate.copyFromPublic({
    required PromptTemplate publicTemplate,
    required String newId,
    required String authorId,
    String? newName,
  }) {
    final now = DateTime.now();
    return PromptTemplate(
      id: newId,
      name: newName ?? '${publicTemplate.name} (复制)',
      content: publicTemplate.content,
      featureType: publicTemplate.featureType,
      isPublic: false,
      authorId: authorId,
      sourceTemplateId: publicTemplate.id,
      isVerified: false,
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      content: json['content'] as String,
      featureType: _parseFeatureType(json['featureType'] as String),
      isPublic: json['isPublic'] as bool,
      authorId: json['authorId'] as String?,
      sourceTemplateId: json['sourceTemplateId'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'featureType': _featureTypeToString(featureType),
      'isPublic': isPublic,
      'authorId': authorId,
      'sourceTemplateId': sourceTemplateId,
      'isVerified': isVerified,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  /// 克隆并更新模板
  PromptTemplate copyWith({
    String? id,
    String? name,
    String? content,
    AIFeatureType? featureType,
    bool? isPublic,
    String? authorId,
    String? sourceTemplateId,
    bool? isVerified,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromptTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      featureType: featureType ?? this.featureType,
      isPublic: isPublic ?? this.isPublic,
      authorId: authorId ?? this.authorId,
      sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
      isVerified: isVerified ?? this.isVerified,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// 标记为收藏
  PromptTemplate toggleFavorite() {
    return copyWith(isFavorite: !isFavorite, updatedAt: DateTime.now());
  }
  
  /// 判断模板是否可编辑（只有私有模板可编辑）
  bool get isEditable => !isPublic;
  
  /// 从字符串解析功能类型
  static AIFeatureType _parseFeatureType(String featureTypeStr) {
    switch (featureTypeStr) {
      case 'SCENE_TO_SUMMARY':
        return AIFeatureType.sceneToSummary;
      case 'SUMMARY_TO_SCENE':
        return AIFeatureType.summaryToScene;
      default:
        // 尝试直接匹配枚举的名称
        try {
          return AIFeatureType.values.firstWhere(
            (t) => t.toString().split('.').last.toUpperCase() == featureTypeStr.toUpperCase()
          );
        } catch (e) {
          throw ArgumentError('未知的功能类型: $featureTypeStr');
        }
    }
  }
  
  /// 将功能类型转换为字符串
  static String _featureTypeToString(AIFeatureType featureType) {
    switch (featureType) {
      case AIFeatureType.sceneToSummary:
        return 'SCENE_TO_SUMMARY';
      case AIFeatureType.summaryToScene:
        return 'SUMMARY_TO_SCENE';
    }
  }
}

/// 用户提示词模板DTO
class UserPromptTemplateDto {
  /// 功能类型
  final AIFeatureType featureType;
  
  /// 提示词文本
  final String promptText;

  UserPromptTemplateDto({
    required this.featureType,
    required this.promptText,
  });

  factory UserPromptTemplateDto.fromJson(Map<String, dynamic> json) {
    String featureTypeStr = json['featureType'] as String;
    AIFeatureType type;
    
    // 根据字符串解析枚举
    switch (featureTypeStr) {
      case 'SCENE_TO_SUMMARY':
        type = AIFeatureType.sceneToSummary;
        break;
      case 'SUMMARY_TO_SCENE':
        type = AIFeatureType.summaryToScene;
        break;
      default:
        // 尝试直接匹配枚举的名称
        try {
          type = AIFeatureType.values.firstWhere(
            (t) => t.toString().split('.').last.toUpperCase() == featureTypeStr.toUpperCase()
          );
        } catch (e) {
          throw ArgumentError('未知的功能类型: $featureTypeStr');
        }
    }
    
    return UserPromptTemplateDto(
      featureType: type,
      promptText: json['promptText'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    String featureTypeStr;
    
    // 将枚举转换为字符串
    switch (featureType) {
      case AIFeatureType.sceneToSummary:
        featureTypeStr = 'SCENE_TO_SUMMARY';
        break;
      case AIFeatureType.summaryToScene:
        featureTypeStr = 'SUMMARY_TO_SCENE';
        break;
    }
    
    return {
      'featureType': featureTypeStr,
      'promptText': promptText,
    };
  }
}

/// 更新提示词请求DTO
class UpdatePromptRequest {
  /// 提示词文本
  final String promptText;

  UpdatePromptRequest({
    required this.promptText,
  });

  factory UpdatePromptRequest.fromJson(Map<String, dynamic> json) {
    return UpdatePromptRequest(
      promptText: json['promptText'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'promptText': promptText,
    };
  }
}

/// 优化提示词请求
class OptimizePromptRequest {
  final String content;
  final OptimizationStyle style;
  final double preserveRatio; // 0.0-1.0 保留原文比例
  
  OptimizePromptRequest({
    required this.content,
    required this.style,
    this.preserveRatio = 0.5,
  });
  
  factory OptimizePromptRequest.fromJson(Map<String, dynamic> json) {
    return OptimizePromptRequest(
      content: json['content'] as String,
      style: _parseOptimizationStyle(json['style'] as String),
      preserveRatio: json['preserveRatio'] as double? ?? 0.5,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'style': _optimizationStyleToString(style),
      'preserveRatio': preserveRatio,
    };
  }
}

/// 解析优化风格
OptimizationStyle _parseOptimizationStyle(String value) {
  return OptimizationStyle.values.firstWhere(
    (e) => e.toString().split('.').last == value,
    orElse: () => OptimizationStyle.professional,
  );
}

/// 优化风格转字符串
String _optimizationStyleToString(OptimizationStyle style) {
  return style.toString().split('.').last;
}

/// 优化区块
class OptimizationSection {
  final String title;
  final String content;
  final String? original;
  final String type;
  
  OptimizationSection({
    required this.title,
    required this.content,
    this.original,
    required this.type,
  });
  
  /// 是否为未更改的区块
  bool get isUnchanged => type == 'unchanged';
  
  /// 是否为修改过的区块
  bool get isModified => type == 'modified';
  
  factory OptimizationSection.fromJson(Map<String, dynamic> json) {
    return OptimizationSection(
      title: json['title'] as String,
      content: json['content'] as String,
      original: json['original'] as String?,
      type: json['type'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'original': original,
      'type': type,
    };
  }
}

/// 优化统计数据
class OptimizationStatistics {
  final int originalTokens;
  final int optimizedTokens;
  final int originalLength;
  final int optimizedLength;
  final double efficiency;
  
  // 兼容旧版API的属性
  int get originalWordCount => originalLength;
  int get optimizedWordCount => optimizedLength;
  double get changeRatio => efficiency;
  
  OptimizationStatistics({
    required this.originalTokens,
    required this.optimizedTokens,
    required this.originalLength,
    required this.optimizedLength,
    required this.efficiency,
  });
  
  factory OptimizationStatistics.fromJson(Map<String, dynamic> json) {
    return OptimizationStatistics(
      originalTokens: json['originalTokens'] as int,
      optimizedTokens: json['optimizedTokens'] as int,
      originalLength: json['originalLength'] as int,
      optimizedLength: json['optimizedLength'] as int,
      efficiency: json['efficiency'] as double,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'originalTokens': originalTokens,
      'optimizedTokens': optimizedTokens,
      'originalLength': originalLength,
      'optimizedLength': optimizedLength,
      'efficiency': efficiency,
    };
  }
}

/// 优化结果
class OptimizationResult {
  final String optimizedContent;
  final List<OptimizationSection> sections;
  final OptimizationStatistics statistics;
  
  OptimizationResult({
    required this.optimizedContent,
    required this.sections,
    required this.statistics,
  });
  
  factory OptimizationResult.fromJson(Map<String, dynamic> json) {
    return OptimizationResult(
      optimizedContent: json['optimizedContent'] as String,
      sections: (json['sections'] as List)
          .map((e) => OptimizationSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      statistics: OptimizationStatistics.fromJson(
          json['statistics'] as Map<String, dynamic>),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'optimizedContent': optimizedContent,
      'sections': sections.map((e) => e.toJson()).toList(),
      'statistics': statistics.toJson(),
    };
  }
}

// 字符串构建器类
class StringBuilder {
  final StringBuffer _buffer = StringBuffer();
  
  void append(String str) {
    _buffer.write(str);
  }
  
  void appendLine(String str) {
    _buffer.writeln(str);
  }
  
  @override
  String toString() {
    return _buffer.toString();
  }
  
  void clear() {
    _buffer.clear();
  }
  
  int get length => _buffer.length;
  
  bool get isEmpty => _buffer.isEmpty;
  
  bool get isNotEmpty => _buffer.isNotEmpty;
} 