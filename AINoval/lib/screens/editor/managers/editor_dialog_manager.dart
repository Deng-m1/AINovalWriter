import 'package:flutter/material.dart';

/// 编辑器对话框管理器
/// 负责管理编辑器中的各种对话框
class EditorDialogManager {
  // 显示编辑器侧边栏宽度调整对话框
  static void showEditorSidebarWidthDialog(
    BuildContext context,
    double currentWidth,
    double minWidth,
    double maxWidth,
    ValueChanged<double> onWidthChanged,
    VoidCallback onSave,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return _buildWidthAdjustmentDialog(
          context,
          '调整侧边栏宽度',
          currentWidth,
          minWidth,
          maxWidth,
          onWidthChanged,
          onSave,
        );
      },
    );
  }

  // 显示聊天侧边栏宽度调整对话框
  static void showChatSidebarWidthDialog(
    BuildContext context,
    double currentWidth,
    double minWidth,
    double maxWidth,
    ValueChanged<double> onWidthChanged,
    VoidCallback onSave,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return _buildWidthAdjustmentDialog(
          context,
          '调整聊天侧边栏宽度',
          currentWidth,
          minWidth,
          maxWidth,
          onWidthChanged,
          onSave,
        );
      },
    );
  }

  // 构建宽度调整对话框
  static Widget _buildWidthAdjustmentDialog(
    BuildContext context,
    String title,
    double currentWidth,
    double minWidth,
    double maxWidth,
    ValueChanged<double> onWidthChanged,
    VoidCallback onSave,
  ) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前宽度: ${currentWidth.toInt()} 像素'),
          const SizedBox(height: 16),
          StatefulBuilder(
            builder: (context, setState) {
              return Slider(
                value: currentWidth,
                min: minWidth,
                max: maxWidth,
                divisions: 8,
                label: currentWidth.toInt().toString(),
                onChanged: (value) {
                  onWidthChanged(value);
                  setState(() {});
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            onSave();
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  // 显示登录提示对话框
  static Widget buildLoginRequiredPanel(BuildContext context, VoidCallback onClose) {
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: 400, // Smaller width for message
        height: 200, // Smaller height for message
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '需要登录', // TODO: Localize
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '请先登录以访问和管理 AI 配置。', // TODO: Localize
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement navigation to login screen
                onClose(); // Close panel for now
              },
              child: const Text('前往登录'), // TODO: Localize
            )
          ],
        ),
      ),
    );
  }
}
