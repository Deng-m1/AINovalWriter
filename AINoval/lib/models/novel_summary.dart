import 'package:equatable/equatable.dart';

class NovelSummary extends Equatable {
  
  const NovelSummary({
    required this.id,
    required this.title,
    this.coverUrl = '',
    required this.lastEditTime,
    this.wordCount = 0,
    this.readTime = 0,
    this.version = 1,
    this.seriesName = '',
    this.completionPercentage = 0.0,
    this.lastEditedChapterId,
    this.author,
    this.contributors = const [],
  });
  
  // 从JSON转换方法
  factory NovelSummary.fromJson(Map<String, dynamic> json) {
    return NovelSummary(
      id: json['id'],
      title: json['title'],
      coverUrl: json['coverUrl'] ?? '',
      lastEditTime: DateTime.parse(json['lastEditTime']),
      wordCount: json['wordCount'] ?? 0,
      readTime: json['readTime'] ?? 0,
      version: json['version'] ?? 1,
      seriesName: json['seriesName'] ?? '',
      completionPercentage: json['completionPercentage']?.toDouble() ?? 0.0,
      lastEditedChapterId: json['lastEditedChapterId'],
      author: json['author'],
      contributors: (json['contributors'] as List?)?.cast<String>() ?? const [],
    );
  }
  final String id;
  final String title;
  final String coverUrl;
  final DateTime lastEditTime;
  final int wordCount;
  final int readTime; // 估计阅读时间（分钟）
  final int version; // 文档版本号
  final String seriesName;
  final double completionPercentage;
  final String? lastEditedChapterId;
  final String? author;
  final List<String> contributors; // 贡献者列表
  
  @override
  List<Object?> get props => [
    id, 
    title, 
    coverUrl,
    lastEditTime, 
    wordCount, 
    readTime,
    version,
    seriesName, 
    completionPercentage,
    lastEditedChapterId,
    author,
    contributors,
  ];
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'lastEditTime': lastEditTime.toIso8601String(),
      'wordCount': wordCount,
      'readTime': readTime,
      'version': version,
      'seriesName': seriesName,
      'completionPercentage': completionPercentage,
      'lastEditedChapterId': lastEditedChapterId,
      'author': author,
      'contributors': contributors,
    };
  }
} 