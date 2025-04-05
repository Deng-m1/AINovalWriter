import 'package:equatable/equatable.dart';

class NovelSummary extends Equatable {
  
  const NovelSummary({
    required this.id,
    required this.title,
    this.coverImagePath = '',
    required this.lastEditTime,
    this.wordCount = 0,
    this.seriesName = '',
    this.completionPercentage = 0.0,
    this.lastEditedChapterId,
  });
  
  // 从JSON转换方法
  factory NovelSummary.fromJson(Map<String, dynamic> json) {
    return NovelSummary(
      id: json['id'],
      title: json['title'],
      coverImagePath: json['coverImagePath'] ?? '',
      lastEditTime: DateTime.parse(json['lastEditTime']),
      wordCount: json['wordCount'] ?? 0,
      seriesName: json['seriesName'] ?? '',
      completionPercentage: json['completionPercentage']?.toDouble() ?? 0.0,
      lastEditedChapterId: json['lastEditedChapterId'],
    );
  }
  final String id;
  final String title;
  final String coverImagePath;
  final DateTime lastEditTime;
  final int wordCount;
  final String seriesName;
  final double completionPercentage;
  final String? lastEditedChapterId;
  
  @override
  List<Object?> get props => [
    id, 
    title, 
    coverImagePath, 
    lastEditTime, 
    wordCount, 
    seriesName, 
    completionPercentage,
    lastEditedChapterId
  ];
  
  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverImagePath': coverImagePath,
      'lastEditTime': lastEditTime.toIso8601String(),
      'wordCount': wordCount,
      'seriesName': seriesName,
      'completionPercentage': completionPercentage,
      'lastEditedChapterId': lastEditedChapterId,
    };
  }
} 