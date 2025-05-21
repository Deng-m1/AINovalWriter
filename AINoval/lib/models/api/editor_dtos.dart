import 'package:json_annotation/json_annotation.dart';

/// 场景摘要生成请求 DTO
class SummarizeSceneRequest {
  final String? additionalInstructions;

  SummarizeSceneRequest({
    this.additionalInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      if (additionalInstructions != null) 'additionalInstructions': additionalInstructions,
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
  final String? additionalInstructions;

  GenerateSceneFromSummaryRequest({
    required this.summary,
    this.chapterId,
    this.additionalInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      if (chapterId != null) 'chapterId': chapterId,
      if (additionalInstructions != null) 'additionalInstructions': additionalInstructions,
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