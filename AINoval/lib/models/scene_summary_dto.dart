import 'package:ainoval/utils/logger.dart';

/// 场景摘要DTO
/// 用于服务器返回的场景摘要数据，仅包含场景的基本信息和摘要，不包含完整内容
class SceneSummaryDto {
  final String id;
  final String novelId;
  final String chapterId;
  final String title;
  final String summary;
  final int sequence;
  final int wordCount;
  final DateTime updatedAt;

  SceneSummaryDto({
    required this.id,
    required this.novelId,
    required this.chapterId,
    required this.title,
    required this.summary,
    required this.sequence,
    required this.wordCount,
    required this.updatedAt,
  });

  /// 从JSON创建SceneSummaryDto实例
  factory SceneSummaryDto.fromJson(Map<String, dynamic> json) {
    try {
      // 确保必要字段存在，并提供默认值
      final String id = json['id'] as String? ?? '';
      if (id.isEmpty) {
        AppLogger.w('SceneSummaryDto', '场景摘要缺少ID字段');
      }

      // 解析日期，如果无法解析则使用当前时间
      DateTime parsedUpdatedAt;
      if (json.containsKey('updatedAt') && json['updatedAt'] is String) {
        try {
          parsedUpdatedAt = DateTime.parse(json['updatedAt'] as String);
        } catch (e) {
          AppLogger.w('SceneSummaryDto', '解析updatedAt失败: ${json['updatedAt']}，使用当前时间');
          parsedUpdatedAt = DateTime.now();
        }
      } else {
        AppLogger.w('SceneSummaryDto', '场景摘要缺少updatedAt字段或格式不正确，使用当前时间');
        parsedUpdatedAt = DateTime.now();
      }

      // 处理sequence和wordCount字段
      int sequence = 0;
      if (json.containsKey('sequence')) {
        if (json['sequence'] is int) {
          sequence = json['sequence'] as int;
        } else if (json['sequence'] is String) {
          sequence = int.tryParse(json['sequence'] as String) ?? 0;
        }
      }

      int wordCount = 0;
      if (json.containsKey('wordCount')) {
        if (json['wordCount'] is int) {
          wordCount = json['wordCount'] as int;
        } else if (json['wordCount'] is String) {
          wordCount = int.tryParse(json['wordCount'] as String) ?? 0;
        }
      }

      return SceneSummaryDto(
        id: id,
        novelId: json['novelId'] as String? ?? '',
        chapterId: json['chapterId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        sequence: sequence,
        wordCount: wordCount,
        updatedAt: parsedUpdatedAt,
      );
    } catch (e) {
      AppLogger.e('SceneSummaryDto', '从JSON创建SceneSummaryDto实例失败', e);
      
      // 返回包含默认值的对象，避免崩溃
      return SceneSummaryDto(
        id: json['id'] as String? ?? 'error_${DateTime.now().millisecondsSinceEpoch}',
        novelId: json['novelId'] as String? ?? '',
        chapterId: json['chapterId'] as String? ?? '',
        title: '解析错误',
        summary: '',
        sequence: 0,
        wordCount: 0,
        updatedAt: DateTime.now(),
      );
    }
  }
  
  /// 转换为Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'novelId': novelId,
      'chapterId': chapterId,
      'title': title,
      'summary': summary,
      'sequence': sequence,
      'wordCount': wordCount,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
} 