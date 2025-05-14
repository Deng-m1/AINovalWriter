import 'dart:convert';
import 'package:ainoval/utils/logger.dart';

/// Quill富文本编辑器格式处理工具类
/// 
/// 用于统一处理Quill富文本编辑器的内容格式，确保正确转换和验证Delta格式
class QuillHelper {
  static const String _tag = 'QuillHelper';

  /// 确保内容是标准的Quill格式
  /// 
  /// 将{"ops":[...]}格式转换为更简洁的[...]格式
  /// 将非JSON文本转换为基本的Quill格式
  /// 
  /// @param content 输入的内容
  /// @return 标准化后的Quill Delta格式
  static String ensureQuillFormat(String content) {
    if (content.isEmpty) {
      return jsonEncode([{"insert": "\n"}]);
    }
    
    try {
      // 检查内容是否是纯文本（不是JSON格式）
      try {
        jsonDecode(content);
      } catch (e) {
        // 如果解析失败，说明是纯文本，直接转换为Delta格式
        return jsonEncode([{"insert": "$content\n"}]);
      }
      
      // 尝试解析为JSON，检查是否已经是Quill格式
      final dynamic parsed = jsonDecode(content);
      
      // 如果已经是数组格式，检查是否符合Quill格式要求
      if (parsed is List) {
        bool isValidQuill = parsed.isNotEmpty && 
                           parsed.every((item) => item is Map && (item.containsKey('insert') || item.containsKey('attributes')));
        
        if (isValidQuill) {
          return content; // 已经是有效的Quill格式
        } else {
          // 转换为纯文本后重新格式化
          String plainText = _extractTextFromList(parsed);
          return jsonEncode([{"insert": "$plainText\n"}]);
        }
      } 
      
      // 如果是对象格式，检查是否符合Delta格式
      if (parsed is Map && parsed.containsKey('ops') && parsed['ops'] is List) {
        final List ops = parsed['ops'] as List;
        return jsonEncode(ops);
      }
      
      // 其他JSON格式，转换为纯文本
      return jsonEncode([{"insert": "${jsonEncode(parsed)}\n"}]);
    } catch (e) {
      // 不是JSON格式，作为纯文本处理
      AppLogger.w('QuillHelper', '内容不是标准格式，作为纯文本处理');
      // 转义特殊字符，确保JSON格式有效
      String safeText = content
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      
      return jsonEncode([{"insert": "$safeText\n"}]);
    }
  }

  /// 将纯文本内容转换为Quill Delta格式
  /// 
  /// @param text 纯文本内容
  /// @return Quill Delta格式的字符串
  static String textToDelta(String text) {
    if (text.isEmpty) {
      return standardEmptyDelta;
    }
    
    final String escapedText = _escapeQuillText(text);
    return '[{"insert":"$escapedText\\n"}]';
  }

  /// 将Quill Delta格式转换为纯文本
  /// 
  /// @param delta Quill Delta格式的字符串
  /// @return 纯文本内容
  static String deltaToText(String deltaContent) {
    try {
      final dynamic parsed = jsonDecode(deltaContent);
      
      if (parsed is List) {
        return _extractTextFromList(parsed);
      } else if (parsed is Map && parsed.containsKey('ops') && parsed['ops'] is List) {
        return _extractTextFromList(parsed['ops'] as List);
      }
      
      // 如果不是标准格式，返回原始内容
      return deltaContent;
    } catch (e) {
      // 如果解析失败，返回原始内容
      return deltaContent;
    }
  }

  /// 验证内容是否为有效的Quill格式
  /// 
  /// @param content 要验证的内容
  /// @return 是否为有效的Quill格式
  static bool isValidQuillFormat(String content) {
    try {
      final dynamic contentJson = jsonDecode(content);
      
      // 验证{"ops":[...]}格式
      if (contentJson is Map && contentJson.containsKey('ops')) {
        final ops = contentJson['ops'];
        return ops is List && ops.isNotEmpty;
      }
      
      // 验证[...]格式
      if (contentJson is List) {
        return contentJson.isNotEmpty && 
               contentJson.every((op) => op is Map && op.containsKey('insert'));
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 获取标准的空Quill Delta格式
  static String get standardEmptyDelta => '[{"insert":"\\n"}]';
  
  /// 获取包含ops的空Quill Delta格式
  static String get opsWrappedEmptyDelta => '{"ops":[{"insert":"\\n"}]}';

  /// 转义Quill文本中的特殊字符
  static String _escapeQuillText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
  }
  
  /// 检测内容格式，确定是否需要转换
  /// 
  /// @param content 输入的内容
  /// @return 是否需要转换为标准格式
  static bool needsFormatConversion(String content) {
    if (content.isEmpty) {
      return true;
    }
    
    try {
      final dynamic contentJson = jsonDecode(content);
      return contentJson is Map && contentJson.containsKey('ops');
    } catch (e) {
      return !content.startsWith('[{');
    }
  }
  
  /// 计算Quill Delta内容的字数统计
  /// 
  /// @param delta Quill Delta格式的字符串
  /// @return 内容的字数
  static int countWords(String delta) {
    final String text = deltaToText(delta);
    if (text.isEmpty) {
      return 0;
    }
    
    // 移除所有换行符后计算字数
    final String cleanText = text.replaceAll('\n', '');
    return cleanText.length;
  }

  /// 从List中提取文本内容
  static String _extractTextFromList(List list) {
    StringBuffer buffer = StringBuffer();
    for (var item in list) {
      if (item is Map && item.containsKey('insert')) {
        buffer.write(item['insert']);
      } else if (item is String) {
        buffer.write(item);
      } else {
        buffer.write(jsonEncode(item));
      }
    }
    return buffer.toString();
  }

  /// 将纯文本转换为Quill Delta格式
  static String convertPlainTextToQuillDelta(String text) {
    if (text.isEmpty) {
      return jsonEncode([{"insert": "\n"}]);
    }
    
    // 处理换行符，确保JSON格式正确
    String safeText = text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    
    // 构建基本的Quill格式
    return jsonEncode([{"insert": "$safeText\n"}]);
  }
} 