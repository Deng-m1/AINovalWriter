import 'package:flutter/material.dart';

/// 编辑器内容区域组件
class EditorContentArea extends StatelessWidget {
  
  const EditorContentArea({
    super.key,
    required this.controller,
    required this.focusNode,
    this.isReadOnly = false,
    required this.onChanged,
  });
  
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isReadOnly;
  final Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.background,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: isReadOnly,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '开始写作...',
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(
          fontSize: 16.0,
          height: 1.5,
        ),
        onChanged: onChanged,
      ),
    );
  }
} 