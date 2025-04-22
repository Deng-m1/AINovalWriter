import 'package:flutter/material.dart';

/// 对话框工具类
/// 
/// 用于创建和显示各种常用对话框
class DialogUtils {
  /// 显示确认对话框
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
            style: TextButton.styleFrom(
              foregroundColor: isDangerous ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 显示危险操作确认对话框
  static Future<bool> showDangerousConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '删除',
    String cancelText = '取消',
  }) async {
    return showConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDangerous: true,
    );
  }

  /// 显示删除确认对话框
  static Future<bool> showDeleteConfirmDialog({
    required BuildContext context,
    required String itemType,
    String? itemName,
  }) async {
    final title = '删除$itemType';
    final message = itemName != null
        ? '确定要删除"$itemName"吗？此操作不可撤销。'
        : '确定要删除这个$itemType吗？此操作不可撤销。';
    
    return showDangerousConfirmDialog(
      context: context,
      title: title,
      message: message,
    );
  }

  /// 显示输入对话框
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    String? initialValue,
    String hintText = '',
    String confirmText = '确认',
    String cancelText = '取消',
  }) async {
    final controller = TextEditingController(text: initialValue);
    
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    return result;
  }

  /// 显示重命名对话框
  static Future<String?> showRenameDialog({
    required BuildContext context,
    required String itemType,
    required String currentName,
  }) async {
    return showInputDialog(
      context: context,
      title: '重命名$itemType',
      initialValue: currentName,
      hintText: '输入新的名称',
    );
  }
} 