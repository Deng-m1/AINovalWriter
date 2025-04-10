import 'package:json_annotation/json_annotation.dart';

/// 场景摘要生成请求 DTO
class SummarizeSceneRequest {
  final String? styleInstructions;

  SummarizeSceneRequest({
    this.styleInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      if (styleInstructions != null) 'styleInstructions': styleInstructions,
    };
  }
}

/// 场景摘要生成响应 DTO
class SummarizeSceneResponse {
  final String summary;

  SummarizeSceneResponse({
    required this.summary,
  });

  factory SummarizeSceneResponse.fromJson(Map<String, dynamic> json) {
    return SummarizeSceneResponse(
      summary: json['summary'] as String,
    );
  }
}

/// 从摘要生成场景请求 DTO
class GenerateSceneFromSummaryRequest {
  final String summary;
  final String? chapterId;
  final String? styleInstructions;

  GenerateSceneFromSummaryRequest({
    required this.summary,
    this.chapterId,
    this.styleInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      if (chapterId != null) 'chapterId': chapterId,
      if (styleInstructions != null) 'styleInstructions': styleInstructions,
    };
  }
}

/// 从摘要生成场景响应 DTO
class GenerateSceneFromSummaryResponse {
  final String content;

  GenerateSceneFromSummaryResponse({
    required this.content,
  });

  factory GenerateSceneFromSummaryResponse.fromJson(Map<String, dynamic> json) {
    return GenerateSceneFromSummaryResponse(
      content: json['content'] as String,
    );
  }
} 