import 'package:flutter/material.dart';
import 'package:ainoval/models/novel_structure.dart';

/// 生成场景对话框结果
class GenerateSceneDialogResult {
  final String summary;
  final String? chapterId;
  final String? styleInstructions;
  
  GenerateSceneDialogResult({
    required this.summary,
    this.chapterId,
    this.styleInstructions,
  });
}

/// 生成场景对话框，用于输入摘要/大纲，然后触发AI生成场景内容
class GenerateSceneDialog extends StatefulWidget {
  const GenerateSceneDialog({
    Key? key,
    required this.novel,
    this.initialSummary = '',
    this.initialChapterId,
  }) : super(key: key);
  
  /// 当前小说
  final Novel novel;
  
  /// 初始摘要文本
  final String initialSummary;
  
  /// 初始章节ID
  final String? initialChapterId;

  @override
  State<GenerateSceneDialog> createState() => _GenerateSceneDialogState();
}

class _GenerateSceneDialogState extends State<GenerateSceneDialog> {
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _styleController = TextEditingController();
  String? _selectedChapterId;
  
  @override
  void initState() {
    super.initState();
    _summaryController.text = widget.initialSummary;
    _selectedChapterId = widget.initialChapterId;
  }
  
  @override
  void dispose() {
    _summaryController.dispose();
    _styleController.dispose();
    super.dispose();
  }
  
  /// 准备章节列表，包含篇章>章节层级
  List<DropdownMenuItem<String>> _buildChapterItems() {
    final items = <DropdownMenuItem<String>>[];
    
    // 空选项
    items.add(const DropdownMenuItem<String>(
      value: null,
      child: Text('（无指定章节）'),
    ));
    
    // 遍历篇章和章节
    for (final act in widget.novel.acts) {
      for (final chapter in act.chapters) {
        items.add(DropdownMenuItem<String>(
          value: chapter.id,
          child: Text('${act.title} > ${chapter.title}'),
        ));
      }
    }
    
    return items;
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 生成场景内容'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 摘要/大纲输入
            TextField(
              controller: _summaryController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '场景摘要/大纲 *',
                hintText: '请输入场景的摘要或大纲，AI将根据此内容生成详细场景',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // 章节选择
            DropdownButtonFormField<String>(
              value: _selectedChapterId,
              decoration: const InputDecoration(
                labelText: '选择章节（可选）',
                border: OutlineInputBorder(),
              ),
              items: _buildChapterItems(),
              onChanged: (value) {
                setState(() {
                  _selectedChapterId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // 风格指令
            TextField(
              controller: _styleController,
              decoration: const InputDecoration(
                labelText: '风格指令（可选）',
                hintText: '例如：多对话，少描写，悬疑风格',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        
        // 生成按钮
        ElevatedButton(
          onPressed: _summaryController.text.trim().isEmpty
              ? null
              : () {
                  // 返回生成结果
                  Navigator.of(context).pop(
                    GenerateSceneDialogResult(
                      summary: _summaryController.text.trim(),
                      chapterId: _selectedChapterId,
                      styleInstructions: _styleController.text.trim().isNotEmpty
                          ? _styleController.text.trim()
                          : null,
                    ),
                  );
                },
          child: const Text('生成'),
        ),
      ],
    );
  }
} 