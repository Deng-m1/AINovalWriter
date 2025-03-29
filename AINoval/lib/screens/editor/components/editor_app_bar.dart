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
    // Use MaterialLocalizations for standard tooltips like back button
    final materialL10n = MaterialLocalizations.of(context);

    String lastSaveText = '从未保存';
    if (lastSaveTime != null) {
      final formatter = DateFormat('HH:mm:ss');
      lastSaveText = '上次保存: ${formatter.format(lastSaveTime!.toLocal())}';
    }
    if (isSaving) {
      lastSaveText = '正在保存...';
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: materialL10n.backButtonTooltip, // Use standard tooltip
        onPressed: onBackPressed,
      ),
      title: Text(novelTitle),
      actions: [
        // Word Count and Save Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$wordCount 字',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                lastSaveText,
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),

        // AI Config/Settings Button
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置', // Consistent tooltip
          style: IconButton.styleFrom(
            backgroundColor: isSettingsActive ? theme.colorScheme.primaryContainer : null,
          ),
          onPressed: onAiConfigPressed,
        ),

        // Chat Button
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: '打开/关闭 AI 聊天', // TODO: Localize
          style: IconButton.styleFrom(
            backgroundColor: isChatActive ? theme.colorScheme.primaryContainer : null,
          ),
          onPressed: onChatPressed,
        ),
        const SizedBox(width: 8), // Add some padding at the end
      ],
      elevation: 1, // Add subtle elevation
      backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _NavButton extends StatelessWidget {

  const _NavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? Colors.white : Colors.black87,
        size: 16,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.black87,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.grey.shade800 : Colors.transparent,
        foregroundColor: isActive ? Colors.white : Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _WordCountIndicator extends StatelessWidget {

  const _WordCountIndicator({
    required this.wordCount,
  });
  final int wordCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$wordCount Words',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${(wordCount / 250).ceil()} pages · ${(wordCount / 200).ceil()}m read',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
} 