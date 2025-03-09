import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

class WordCountStats {
  
  const WordCountStats({
    required this.words,
    required this.charactersWithSpaces,
    required this.charactersNoSpaces,
    required this.paragraphs,
    required this.readTimeMinutes,
  });
  final int words;
  final int charactersWithSpaces;
  final int charactersNoSpaces;
  final int paragraphs;
  final int readTimeMinutes;
}

class WordCountAnalyzer {
  static WordCountStats analyze(String text) {
    // 计算字符数（含空格）
    final charactersWithSpaces = text.length;
    
    // 计算字符数（不含空格）
    final charactersNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    
    // 计算单词数（英文以空格分隔，中文每个字符算一个）
    int wordCount = 0;
    
    // 处理中文字符
    final chineseCharCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(text).length;
    
    // 处理英文单词
    final englishWords = text
        .replaceAll(RegExp(r'[\u4e00-\u9fa5]'), '') // 移除中文字符
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    
    wordCount = chineseCharCount + englishWords;
    
    // 计算段落数
    final paragraphs = text.split(RegExp(r'\n+')).where((p) => p.trim().isNotEmpty).length;
    
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
  
  // 分析QuillController的内容
  static WordCountStats analyzeController(QuillController controller) {
    final text = controller.document.toPlainText();
    return analyze(text);
  }
  
  // 分析Delta JSON格式内容
  static WordCountStats analyzeJson(String jsonContent) {
    try {
      final jsonData = jsonDecode(jsonContent);
      final ops = jsonData['ops'] ?? jsonData;
      final document = Document.fromJson(ops);
      final text = document.toPlainText();
      return analyze(text);
    } catch (e) {
      // 如果解析失败，当作纯文本处理
      return analyze(jsonContent);
    }
  }
} 