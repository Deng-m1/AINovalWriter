import 'package:json_annotation/json_annotation.dart';

/// 剧情大纲生成的数据块
/// 用于流式传输生成的剧情大纲选项
class OutlineGenerationChunk {
  /// 选项ID，用于唯一标识一个剧情选项
  final String optionId;
  
  /// 选项标题，AI生成的剧情选项的短标题
  final String? optionTitle;
  
  /// 文本块内容，大纲内容的文本片段
  final String textChunk;
  
  /// 是否为该选项的最后一个块
  final bool isFinalChunk;
  
  /// 错误信息，如果生成过程中出错则包含错误信息
  final String? error;

  OutlineGenerationChunk({
    required this.optionId,
    this.optionTitle,
    required this.textChunk,
    required this.isFinalChunk,
    this.error,
  });

  factory OutlineGenerationChunk.fromJson(Map<String, dynamic> json) {
    return OutlineGenerationChunk(
      optionId: json['optionId'] as String? ?? '',
      optionTitle: json['optionTitle'] as String?,
      textChunk: json['textChunk'] as String? ?? '',
      isFinalChunk: json['finalChunk'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optionId': optionId,
      if (optionTitle != null) 'optionTitle': optionTitle,
      'textChunk': textChunk,
      'isFinalChunk': isFinalChunk,
      if (error != null) 'error': error,
    };
  }
}
