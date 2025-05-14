/**
 * 文档解析工具类
 * 
 * 用于解析和处理文本内容，将其转换为可编辑的Quill文档格式。
 * 提供两种解析方法：安全解析（在UI线程使用）和隔离解析（在计算隔离中使用）。
 */
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/quill_helper.dart';

/// 文档内容解析工具类
/// 
/// 提供安全的文档内容解析功能，处理各种边缘情况和格式问题，
/// 确保始终返回有效的Quill Document对象。
class DocumentParser {
  /// 安全解析文档内容，在UI线程使用
  /// 
  /// 将输入的内容字符串转换为Quill Document对象
  /// 处理各种边缘情况如：空内容、无效JSON、纯文本内容等
  /// 
  /// [content] 要解析的内容字符串
  /// 返回 解析后的Quill Document对象
  static Document parseDocumentSafely(String content) {
    try {
      // 处理空内容情况
      if (content.isEmpty) {
        return Document.fromJson([{'insert': '\n'}]);
      }
      
      // 检查是否是纯文本（非JSON格式）
      bool isPlainText = false;
      try {
        jsonDecode(content);
      } catch (e) {
        isPlainText = true;
      }
      
      // 如果是纯文本，直接转换为Quill格式
      if (isPlainText) {
        return Document.fromJson([
          {'insert': '$content\n'}
        ]);
      }
      
      // 使用QuillHelper处理内容格式
      final String standardContent = QuillHelper.ensureQuillFormat(content);
      
      try {
        // 解析为JSON，确保正确的格式
        final List<dynamic> delta = jsonDecode(standardContent) as List<dynamic>;
        return Document.fromJson(delta);
      } catch (e) {
        AppLogger.e('DocumentParser', '解析标准化内容仍然失败，使用安全格式', e);
        // 如果仍然失败，提取内容作为纯文本
        return Document.fromJson([
          {'insert': content.isEmpty ? '\n' : '$content\n'}
        ]);
      }
    } catch (e) {
      AppLogger.e('DocumentParser', '解析场景内容失败，使用空文档', e);
      // 返回空文档，避免显示错误信息
      return Document.fromJson([{'insert': '\n'}]);
    }
  }
  
  /// 在隔离中解析文档内容，用于compute方法
  /// 
  /// 设计为在计算隔离中执行，避免阻塞UI线程
  /// 处理逻辑与安全解析类似，但简化了错误处理
  /// 
  /// [content] 要解析的内容字符串
  /// 返回 解析后的Quill Document对象
  static Document parseDocumentInIsolate(String content) {
    try {
      // 处理空内容
      if (content.isEmpty) {
        return Document.fromJson([{'insert': '\n'}]);
      }
      
      // 检查是否是纯文本
      bool isPlainText = false;
      try {
        jsonDecode(content);
      } catch (e) {
        isPlainText = true;
      }
      
      // 如果是纯文本，直接转换为Quill格式
      if (isPlainText) {
        return Document.fromJson([
          {'insert': '$content\n'}
        ]);
      }
      
      // 解析JSON格式
      try {
        final List<dynamic> delta = jsonDecode(content) as List<dynamic>;
        return Document.fromJson(delta);
      } catch (e) {
        // 如果解析失败，作为纯文本处理
        return Document.fromJson([
          {'insert': content.isEmpty ? '\n' : '$content\n'}
        ]);
      }
    } catch (e) {
      // 返回空文档
      return Document.fromJson([{'insert': '\n'}]);
    }
  }
} 