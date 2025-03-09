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
    // 构建基础工具栏
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
      child: QuillToolbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            alignment: WrapAlignment.start,
            children: [
              // 基础格式化工具
              QuillToolbarHistoryButton(controller: controller, isUndo: true),
              QuillToolbarHistoryButton(controller: controller, isUndo: false),
              QuillToolbarToggleStyleButton(attribute: Attribute.bold, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.italic, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.underline, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.strikeThrough, controller: controller),
              QuillToolbarClearFormatButton(controller: controller),
              
              // 列表和对齐
              QuillToolbarToggleStyleButton(attribute: Attribute.ol, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.ul, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.blockQuote, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.codeBlock, controller: controller),
              QuillToolbarToggleCheckListButton(controller: controller),
              
              // 对齐
              QuillToolbarToggleStyleButton(attribute: Attribute.leftAlignment, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.centerAlignment, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.rightAlignment, controller: controller),
              QuillToolbarToggleStyleButton(attribute: Attribute.justifyAlignment, controller: controller),
              
              // 缩进
              QuillToolbarIndentButton(controller: controller, isIncrease: true),
              QuillToolbarIndentButton(controller: controller, isIncrease: false),
              
              // 链接
              QuillToolbarLinkStyleButton(controller: controller),
              
              // 搜索按钮
              QuillToolbarSearchButton(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
  
  // 显示标题选择对话框
  void _showHeaderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择标题样式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('标题1', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              onTap: () {
                controller.formatSelection(Attribute.h1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('标题2', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              onTap: () {
                controller.formatSelection(Attribute.h2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('标题3', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () {
                controller.formatSelection(Attribute.h3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('正文'),
              onTap: () {
                // 修正移除标题格式的方法
                controller.formatSelection(Attribute.clone(Attribute.header, null));
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