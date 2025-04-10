import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget { // 新增写作按钮回调

  const EditorAppBar({
    super.key,
    required this.novelTitle,
    required this.wordCount,
    required this.isSaving,
    required this.lastSaveTime,
    required this.onBackPressed,
    required this.onChatPressed,
    required this.isChatActive,
    required this.onAiConfigPressed,
    required this.isSettingsActive,
    required this.onPlanPressed,
    required this.isPlanActive,
    this.onWritePressed, // 新增可选参数
    this.onAIGenerationPressed,
    this.onAISummaryPressed,
    this.isAIGenerationActive = false,
  });
  final String novelTitle;
  final int wordCount;
  final bool isSaving;
  final DateTime? lastSaveTime;
  final VoidCallback onBackPressed;
  final VoidCallback onChatPressed;
  final bool isChatActive;
  final VoidCallback onAiConfigPressed;
  final bool isSettingsActive;
  final VoidCallback onPlanPressed;
  final bool isPlanActive;
  final VoidCallback? onWritePressed;
  final VoidCallback? onAIGenerationPressed;
  final VoidCallback? onAISummaryPressed;
  final bool isAIGenerationActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String lastSaveText = '从未保存';
    if (lastSaveTime != null) {
      final formatter = DateFormat('HH:mm:ss');
      lastSaveText = '上次保存: ${formatter.format(lastSaveTime!.toLocal())}';
    }
    if (isSaving) {
      lastSaveText = '正在保存...';
    }

    // 构建实际显示的字数文本
    final String wordCountText = '${wordCount.toString()} 字';

    return AppBar(
      titleSpacing: 0,
      automaticallyImplyLeading: false, // 禁用自动leading按钮
      title: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back),
            splashRadius: 22,
            onPressed: onBackPressed,
          ),

          // 左对齐的功能图标区域
          Row(
            children: [
              // 大纲按钮
              _buildNavButton(
                context: context,
                icon: Icons.view_kanban_outlined,
                label: '大纲',
                isActive: isPlanActive,
                onPressed: onPlanPressed,
              ),

              // 写作按钮
              _buildNavButton(
                context: context,
                icon: Icons.edit_outlined,
                label: '写作',
                isActive: !isPlanActive, // 写作状态与Plan状态相反
                onPressed: onWritePressed ?? () {},
              ),

              // 设置按钮
              _buildNavButton(
                context: context,
                icon: Icons.settings_outlined,
                label: '设置',
                isActive: isSettingsActive,
                onPressed: onAiConfigPressed,
              ),

              // AI生成按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  tooltip: 'AI生成',
                  onSelected: (value) {
                    if (value == 'scene') {
                      onAIGenerationPressed?.call();
                    } else if (value == 'summary') {
                      onAISummaryPressed?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'scene',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome),
                          SizedBox(width: 8),
                          Text('AI生成场景'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'summary',
                      child: Row(
                        children: [
                          Icon(Icons.summarize),
                          SizedBox(width: 8),
                          Text('AI生成摘要'),
                        ],
                      ),
                    ),
                  ],
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: isAIGenerationActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Row(
                      children: [
                        Text(
                          'AI生成',
                          style: TextStyle(
                            color: isAIGenerationActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: isAIGenerationActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: isAIGenerationActive
                          ? theme.colorScheme.primaryContainer.withAlpha(76)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: null, // 由 PopupMenuButton 处理点击事件
                  ),
                ),
              ),

              // 聊天按钮
              _buildNavButton(
                context: context,
                icon: Icons.chat_bubble_outline,
                label: '聊天',
                isActive: isChatActive,
                onPressed: onChatPressed,
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Word Count and Save Status
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
             children: [
              Row(
                children: [
                  Icon(
                    Icons.text_fields,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wordCountText,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    isSaving ? Icons.sync : Icons.check_circle_outline,
                    size: 14,
                    color: isSaving
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lastSaveText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSaving
                          ? Colors.orange.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      elevation: 0,
      shape: Border(
        bottom: BorderSide(
          color: theme.dividerColor,
          width: 1.0,
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
    );
  }

  // 构建导航按钮的辅助方法
  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton.icon(
        icon: Icon(
          icon,
          size: 20,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isActive
              ? theme.colorScheme.primaryContainer.withAlpha(76)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
