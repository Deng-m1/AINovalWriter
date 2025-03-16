import 'package:ainoval/theme/text_styles.dart';
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
    this.onChatPressed,
    this.isChatActive = false,
  });
  final String novelTitle;
  final int wordCount;
  final bool isSaving;
  final DateTime? lastSaveTime;
  final VoidCallback onBackPressed;
  final VoidCallback? onChatPressed;
  final bool isChatActive;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: _buildLeadingButton(),
      title: _buildTitle(),
      actions: _buildActions(context),
    );
  }

  Widget _buildLeadingButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.black54),
      onPressed: onBackPressed,
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Text(
          novelTitle,
          style: AppTextStyles.titleStyle,
        ),
        const SizedBox(width: 8),
        const Icon(Icons.keyboard_arrow_right, size: 16, color: Colors.black54),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final List<Widget> actions = [];
    
    // 添加导航按钮
    actions.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _buildNavButtons(),
    ));
    
    // 添加字数统计
    actions.add(_WordCountIndicator(wordCount: wordCount));
    
    // 添加间隔
    actions.add(const SizedBox(width: 8));
    
    // 添加格式按钮
    actions.add(IconButton(
      icon: const Icon(Icons.text_format, color: Colors.black54),
      tooltip: '格式',
      onPressed: () {},
    ));
    
    // 添加焦点按钮
    actions.add(IconButton(
      icon: const Icon(Icons.center_focus_strong, color: Colors.black54),
      tooltip: '焦点模式',
      onPressed: () {},
    ));
    
    // 添加保存状态指示器
    if (isSaving) {
      actions.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ));
    } else if (lastSaveTime != null) {
      actions.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Tooltip(
          message: AppLocalizations.of(context)!.saved,
          child: Icon(
            Icons.check_circle,
            color: Colors.green.shade300,
          ),
        ),
      ));
    }
    
    return actions;
  }
  
  Widget _buildNavButtons() {
    return Row(
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
          isActive: isChatActive,
          onPressed: onChatPressed ?? () {},
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