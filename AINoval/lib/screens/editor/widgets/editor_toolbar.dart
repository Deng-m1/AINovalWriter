import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.controller,
  });
  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    // 处理无效控制器情况
    if (controller.document.isEmpty() && controller.document.length == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: const Text('编辑器工具栏加载中...'),
      );
    }
    // 构建基础工具栏 - 简化为使用标准工具栏
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 使用最基本的QuillToolbar构造
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () {
                if (controller.hasUndo) {
                  controller.undo();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: () {
                if (controller.hasRedo) {
                  controller.redo();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.format_bold),
              onPressed: () {
                controller.formatSelection(Attribute.bold);
              },
            ),
            IconButton(
              icon: const Icon(Icons.format_italic),
              onPressed: () {
                controller.formatSelection(Attribute.italic);
              },
            ),
            IconButton(
              icon: const Icon(Icons.format_underline),
              onPressed: () {
                controller.formatSelection(Attribute.underline);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 显示标题选择对话框
  void _showHeaderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('选择标题样式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('标题1',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              onTap: () {
                controller.formatSelection(Attribute.h1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('标题2',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              onTap: () {
                controller.formatSelection(Attribute.h2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('标题3',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () {
                controller.formatSelection(Attribute.h3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('正文'),
              onTap: () {
                // 修正移除标题格式的方法
                controller
                    .formatSelection(Attribute.clone(Attribute.header, null));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 显示AI助手对话框
  void _showAIAssistantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('AI写作助手'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('完善当前段落'),
              onTap: () {
                // 第一迭代中，仅显示提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI写作辅助功能将在下一个迭代中实现')),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('续写后续内容'),
              onTap: () {
                // 第一迭代中，仅显示提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI写作辅助功能将在下一个迭代中实现')),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_alt),
              title: const Text('分析当前内容'),
              onTap: () {
                // 第一迭代中，仅显示提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI写作辅助功能将在下一个迭代中实现')),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
