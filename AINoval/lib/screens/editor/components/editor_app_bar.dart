import 'package:ainoval/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ainoval/screens/ai_config/ai_config_management_screen.dart';
import 'package:ainoval/screens/ai_config/widgets/ai_model_selector.dart';
import 'package:intl/intl.dart'; // For date formatting

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String novelTitle;
  final int wordCount;
  final bool isSaving;
  final DateTime? lastSaveTime;
  final VoidCallback onBackPressed;
  final VoidCallback onChatPressed;
  final bool isChatActive;
  final VoidCallback onAiConfigPressed;
  final bool isSettingsActive;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materialL10n = MaterialLocalizations.of(context);

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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: materialL10n.backButtonTooltip,
        onPressed: onBackPressed,
        splashRadius: 22, // 统一点击反馈范围
      ),
      title: Text(
        novelTitle,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w500), // 调整标题样式
        overflow: TextOverflow.ellipsis, // 防止标题过长
      ),
      titleSpacing: 0, // 调整标题和 leading 之间的间距
      actions: [
        // Word Count and Save Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0), // 调整内边距
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
                    wordCountText, // 使用计算好的字数文本
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 2), // 微调间距
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

        // AI Config/Settings Button
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22), // 统一图标大小
          tooltip: '设置',
          splashRadius: 22, // 统一点击反馈范围
          style: IconButton.styleFrom(
            foregroundColor: isSettingsActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            backgroundColor: isSettingsActive
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
          ),
          onPressed: onAiConfigPressed,
        ),

        // Chat Button
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, size: 22),
          tooltip: '打开/关闭 AI 聊天',
          splashRadius: 22,
          style: IconButton.styleFrom(
            foregroundColor: isChatActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            backgroundColor: isChatActive
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
          ),
          onPressed: onChatPressed,
        ),
        const SizedBox(width: 12), // 调整末尾间距
      ],
      elevation: 0, // 4. 去除阴影
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

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
