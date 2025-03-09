import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

/// 字数统计信息
class WordCountStats {
  
  const WordCountStats({
    required this.charactersNoSpaces,
    required this.charactersWithSpaces,
    required this.words,
    required this.paragraphs,
    required this.readTimeMinutes,
  });
  final int charactersNoSpaces;
  final int charactersWithSpaces;
  final int words;
  final int paragraphs;
  final int readTimeMinutes;
}

/// 字数统计工具类
class WordCountAnalyzer {
  /// 计算文本中的字数
  /// 
  /// 对于中文，每个字符算一个字
  /// 对于英文，按空格分隔的单词算一个字
  static int countWords(String content) {
    if (content.isEmpty) {
      return 0;
    }
    
    // 尝试解析富文本内容
    String plainText;
    try {
      final dynamic json = jsonDecode(content);
      if (json is Map && json.containsKey('ops')) {
        plainText = _extractPlainTextFromDelta(json['ops']);
      } else if (json is List) {
        plainText = _extractPlainTextFromDelta(json);
      } else {
        plainText = content;
      }
    } catch (e) {
      // 如果解析失败，假设是纯文本
      plainText = content;
    }
    
    // 计算中文字符数
    final chineseCharCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(plainText).length;
    
    // 计算英文单词数
    final englishText = plainText.replaceAll(RegExp(r'[\u4e00-\u9fa5]'), ' ');
    final englishWords = englishText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    
    // 总字数 = 中文字符数 + 英文单词数
    return chineseCharCount + englishWords;
  }
  
  /// 从Delta格式的富文本中提取纯文本
  static String _extractPlainTextFromDelta(dynamic ops) {
    if (ops is! List) {
      return '';
    }
    
    final buffer = StringBuffer();
    
    for (final op in ops) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is String) {
          buffer.write(insert);
        }
      }
    }
    
    return buffer.toString();
  }
  
  /// 计算阅读时间（分钟）
  /// 
  /// 假设平均阅读速度为每分钟200个字
  static int estimateReadingTime(String content) {
    final wordCount = countWords(content);
    return (wordCount / 200).ceil();
  }
  
  /// 计算字数统计信息
  static WordCountStats analyzeContent(String content) {
    final plainText = _extractPlainText(content);
    
    // 计算字符数（不含空格）
    final charactersNoSpaces = plainText.replaceAll(RegExp(r'\s'), '').length;
    
    // 计算字符数（含空格）
    final charactersWithSpaces = plainText.length;
    
    // 计算字数
    final words = countWords(content);
    
    // 计算段落数
    final paragraphs = plainText.split(RegExp(r'\n+')).where((p) => p.trim().isNotEmpty).length;
    
    // 估算阅读时间
    final readTimeMinutes = estimateReadingTime(content);
    
    return WordCountStats(
      charactersNoSpaces: charactersNoSpaces,
      charactersWithSpaces: charactersWithSpaces,
      words: words,
      paragraphs: paragraphs,
      readTimeMinutes: readTimeMinutes,
    );
  }
  
  /// 从内容中提取纯文本
  static String _extractPlainText(String content) {
    try {
      final dynamic json = jsonDecode(content);
      if (json is Map && json.containsKey('ops')) {
        return _extractPlainTextFromDelta(json['ops']);
      } else if (json is List) {
        return _extractPlainTextFromDelta(json);
      }
    } catch (e) {
      // 解析失败，返回原始内容
    }
    
    return content;
  }

  /// 分析文本并返回详细的字数统计信息
  static WordCountStats analyze(String text) {
    // 尝试解析富文本内容
    String plainText;
    try {
      final dynamic deltaJson = jsonDecode(text);
      if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
        plainText = _extractPlainTextFromDelta(deltaJson['ops']);
      } else if (deltaJson is List) {
        plainText = _extractPlainTextFromDelta(deltaJson);
      } else {
        plainText = text;
      }
    } catch (e) {
      // 如果解析失败，假设是纯文本
      plainText = text;
    }
    
    // 计算字符数（不含空格）
    final charactersNoSpaces = plainText.replaceAll(RegExp(r'\s'), '').length;
    
    // 计算字符数（含空格）
    final charactersWithSpaces = plainText.length;
    
    // 计算单词数（英文以空格分隔，中文每个字符算一个）
    int wordCount = 0;
    
    // 处理中文字符
    final chineseCharCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(plainText).length;
    
    // 处理英文单词
    final englishWords = plainText
        .replaceAll(RegExp(r'[\u4e00-\u9fa5]'), '') // 移除中文字符
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    
    wordCount = chineseCharCount + englishWords;
    
    // 计算段落数
    final paragraphs = plainText.split(RegExp(r'\n+')).where((p) => p.trim().isNotEmpty).length;
    
    // 估算阅读时间（假设平均每分钟阅读200个中文字或英文单词）
    final readTimeMinutes = (wordCount / 200).ceil();
    
    return WordCountStats(
      charactersNoSpaces: charactersNoSpaces,
      charactersWithSpaces: charactersWithSpaces,
      words: wordCount,
      paragraphs: paragraphs,
      readTimeMinutes: readTimeMinutes,
    );
  }
} 