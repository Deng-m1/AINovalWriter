import 'dart:convert';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/quill_helper.dart';

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

/// 字数统计分析器
class WordCountAnalyzer {
  static const String _tag = 'WordCountAnalyzer';
  static const int _averageReadingWordsPerMinute = 200;

  /// 统计字数的方法
  /// 
  /// @param content 可能是Delta格式或纯文本的内容
  /// @return 内容的字数
  static int countWords(String? content) {
    if (content == null || content.isEmpty) {
      return 0;
    }

    try {
      // 使用QuillHelper工具类解析文本内容
      final plainText = QuillHelper.deltaToText(content);
      
      // 计算字数 - 使用Unicode字符计数
      return _countUnicodeCharacters(plainText);
    } catch (e) {
      AppLogger.e(_tag, '解析内容失败，尝试直接计数', e);
      // 如果解析失败，尝试直接计数
      return _countUnicodeCharacters(content);
    }
  }

  /// 统计基本字数信息
  /// 
  /// @param delta Quill Delta格式内容
  /// @return 包含字数、行数、字符数统计结果的Map
  static Map<String, int> getBasicStats(String? delta) {
    if (delta == null || delta.isEmpty) {
      return {'words': 0, 'lines': 0, 'chars': 0};
    }

    try {
      // 使用QuillHelper工具类解析文本内容
      final plainText = QuillHelper.deltaToText(delta);
      
      // 计算字数、行数和字符数
      final int wordCount = _countUnicodeCharacters(plainText);
      final int lineCount = _countLines(plainText);
      final int charCount = plainText.length;

      return {
        'words': wordCount,
        'lines': lineCount,
        'chars': charCount,
      };
    } catch (e) {
      AppLogger.e(_tag, '解析内容失败，返回默认值', e);
      return {'words': 0, 'lines': 0, 'chars': 0};
    }
  }

  /// 分析文本并返回详细的字数统计信息
  /// 
  /// @param content 可能是Delta格式或纯文本的内容
  /// @return 详细的字数统计信息
  static WordCountStats analyze(String? content) {
    if (content == null || content.isEmpty) {
      return const WordCountStats(
        charactersNoSpaces: 0,
        charactersWithSpaces: 0,
        words: 0,
        paragraphs: 0,
        readTimeMinutes: 0,
      );
    }
    
    // 提取纯文本
    String plainText;
    try {
      plainText = QuillHelper.deltaToText(content);
    } catch (e) {
      // 如果解析失败，假设是纯文本
      plainText = content;
      AppLogger.i(_tag, '内容格式解析失败，使用原始内容: ${e.toString()}');
    }
    
    // 计算字符数（不含空格）
    final charactersNoSpaces = plainText.replaceAll(RegExp(r'\s'), '').length;
    
    // 计算字符数（含空格）
    final charactersWithSpaces = plainText.length;
    
    // 计算字数
    final words = _countUnicodeCharacters(plainText);
    
    // 计算段落数
    final paragraphs = _countParagraphs(plainText);
    
    // 估算阅读时间（假设平均每分钟阅读200个字）
    final readTimeMinutes = _calculateReadingTime(words);
    
    return WordCountStats(
      charactersNoSpaces: charactersNoSpaces,
      charactersWithSpaces: charactersWithSpaces,
      words: words,
      paragraphs: paragraphs,
      readTimeMinutes: readTimeMinutes,
    );
  }

  /// 统计Unicode字符数（更适合中文等非英语字符）
  static int _countUnicodeCharacters(String text) {
    if (text.isEmpty) return 0;
    
    // 移除所有换行符和额外的空格
    final String cleanText = text
        .replaceAll('\n', '')  // 移除换行符
        .replaceAll(RegExp(r'\s+'), ' '); // 连续空格替换为单个空格
    
    // 如果清理后为空，返回0
    if (cleanText.trim().isEmpty) return 0;
    
    // 返回清理后的字符串长度
    return cleanText.length;
  }

  /// 统计行数
  static int _countLines(String text) {
    if (text.isEmpty) return 0;
    
    // 计算换行符数量
    final lineCount = '\n'.allMatches(text).length;
    
    // 如果文本不以换行符结尾，加1
    return text.endsWith('\n') ? lineCount : lineCount + 1;
  }

  /// 统计段落数
  static int _countParagraphs(String text) {
    if (text.isEmpty) return 0;
    
    // 按连续的换行符分割文本，并计算非空段落数
    return text.split(RegExp(r'\n+'))
        .where((p) => p.trim().isNotEmpty)
        .length;
  }

  /// 计算阅读时间（分钟）
  /// 
  /// 假设平均阅读速度为每分钟200个字
  static int _calculateReadingTime(int wordCount) {
    if (wordCount <= 0) return 0;
    return (wordCount / _averageReadingWordsPerMinute).ceil();
  }

  /// 计算阅读时间（分钟）
  /// 
  /// @param content 内容文本
  /// @return 估计的阅读时间（分钟）
  static int estimateReadingTime(String content) {
    final wordCount = countWords(content);
    return _calculateReadingTime(wordCount);
  }
} 