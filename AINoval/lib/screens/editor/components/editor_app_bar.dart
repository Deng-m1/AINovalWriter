import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {

  const EditorAppBar({
    super.key,
    required this.novelTitle,
    required this.wordCount,
    required this.isSaving,
    this.lastSaveTime,
    required this.onBackPressed,
  });
  final String novelTitle;
  final int wordCount;
  final bool isSaving;
  final DateTime? lastSaveTime;
  final VoidCallback onBackPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black54),
        onPressed: onBackPressed,
      ),
      title: Row(
        children: [
          // 小说标题
          Text(
            novelTitle,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          // 小箭头
          const Icon(Icons.keyboard_arrow_right, size: 16, color: Colors.black54),
        ],
      ),
      actions: [
        // 顶部导航按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Plan 按钮
              _NavButton(
                label: 'Plan',
                icon: Icons.map_outlined,
                isActive: false,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              // Write 按钮 (激活状态)
              _NavButton(
                label: 'Write',
                icon: Icons.edit_outlined,
                isActive: true,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              // Chat 按钮
              _NavButton(
                label: 'Chat',
                icon: Icons.chat_outlined,
                isActive: false,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              // Review 按钮
              _NavButton(
                label: 'Review',
                icon: Icons.rate_review_outlined,
                isActive: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
        
        // 字数统计
        _WordCountIndicator(wordCount: wordCount),
        
        const SizedBox(width: 8),
        
        // 格式按钮
        IconButton(
          icon: const Icon(Icons.text_format, color: Colors.black54),
          tooltip: '格式',
          onPressed: () {},
        ),
        
        // 焦点按钮
        IconButton(
          icon: const Icon(Icons.center_focus_strong, color: Colors.black54),
          tooltip: '焦点模式',
          onPressed: () {},
        ),
        
        // 保存状态指示器
        if (isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          )
        else if (lastSaveTime != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: l10n.saved,
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade300,
              ),
            ),
          ),
      ],
    );
  }
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