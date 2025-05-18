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
    this.onAIGenerationPressed, // For AI Scene Generation
    this.onAISummaryPressed,
    this.onAutoContinueWritingPressed, 
    this.onAISettingGenerationPressed, // New: For AI Setting Generation
    this.onNextOutlinePressed,
    this.isAIGenerationActive = false, // This might now represent the dropdown itself or a specific item
    this.isAISummaryActive = false, // New: For AI Summary panel active state
    this.isAIContinueWritingActive = false, // New: For AI Continue Writing panel active state
    this.isAISettingGenerationActive = false, // New: For AI Setting Generation panel active state
    this.isNextOutlineActive = false,
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
  final VoidCallback? onAIGenerationPressed; // AI 生成场景
  final VoidCallback? onAISummaryPressed;    // AI 生成摘要
  final VoidCallback? onAutoContinueWritingPressed; // 自动续写
  final VoidCallback? onAISettingGenerationPressed; // AI 生成设定 (New)
  final VoidCallback? onNextOutlinePressed;
  final bool isAIGenerationActive; // AI 生成场景面板激活状态
  final bool isAISummaryActive; // AI 生成摘要面板激活状态 (New)
  final bool isAIContinueWritingActive; // AI 自动续写面板激活状态 (New)
  final bool isAISettingGenerationActive; // AI 生成设定面板激活状态 (New)
  final bool isNextOutlineActive;

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
    
    // Determine if the main "AI生成" dropdown should appear active
    // It can be active if any of its sub-panels are active
    final bool isAnyAIPanelActive = isAIGenerationActive || 
                                  isAISummaryActive || 
                                  isAIContinueWritingActive || 
                                  isAISettingGenerationActive;

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

              // AI生成按钮 (Dropdown)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  tooltip: 'AI辅助', // Changed tooltip to be more general
                  onSelected: (value) {
                    if (value == 'scene') {
                      onAIGenerationPressed?.call();
                    } else if (value == 'summary') {
                      onAISummaryPressed?.call();
                    } else if (value == 'continue-writing') {
                      onAutoContinueWritingPressed?.call();
                    } else if (value == 'setting-generation') { // New case
                      onAISettingGenerationPressed?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'scene',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_outlined, color: isAIGenerationActive ? theme.colorScheme.primary : null),
                          const SizedBox(width: 8),
                          Text('AI生成场景', style: TextStyle(color: isAIGenerationActive ? theme.colorScheme.primary : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'summary',
                      child: Row(
                        children: [
                          Icon(Icons.summarize_outlined, color: isAISummaryActive ? theme.colorScheme.primary : null),
                          const SizedBox(width: 8),
                          Text('AI生成摘要', style: TextStyle(color: isAISummaryActive ? theme.colorScheme.primary : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'continue-writing',
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories_outlined, color: isAIContinueWritingActive ? theme.colorScheme.primary : null),
                          const SizedBox(width: 8),
                          Text('自动续写', style: TextStyle(color: isAIContinueWritingActive ? theme.colorScheme.primary : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>( // New Menu Item
                      value: 'setting-generation',
                      child: Row(
                        children: [
                          Icon(Icons.auto_fix_high_outlined, color: isAISettingGenerationActive ? theme.colorScheme.primary : null), // Example Icon
                          const SizedBox(width: 8),
                          Text('AI生成设定', style: TextStyle(color: isAISettingGenerationActive ? theme.colorScheme.primary : null)),
                        ],
                      ),
                    ),
                  ],
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.psychology_alt_outlined, // Changed icon to be more general for AI tools
                      size: 20,
                      color: isAnyAIPanelActive // Use combined active state
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Row(
                      children: [
                        Text(
                          'AI辅助', // Changed label to be more general
                          style: TextStyle(
                            color: isAnyAIPanelActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: isAnyAIPanelActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: isAnyAIPanelActive
                          ? theme.colorScheme.primaryContainer.withAlpha(76)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: null, // Let PopupMenuButton handle tap
                  ),
                ),
              ),

              // 剧情推演按钮
              _buildNavButton(
                context: context,
                icon: Icons.device_hub_outlined, // Changed icon for better distinction
                label: '剧情推演',
                isActive: isNextOutlineActive,
                onPressed: onNextOutlinePressed ?? () {},
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
