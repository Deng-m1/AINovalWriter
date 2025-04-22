import 'package:ainoval/screens/next_outline/next_outline_screen.dart';
import 'package:flutter/material.dart';

/// 剧情推演视图
/// 用于在编辑器中嵌入剧情推演功能
class NextOutlineView extends StatelessWidget {
  /// 小说ID
  final String novelId;
  
  /// 小说标题
  final String novelTitle;
  
  /// 切换到写作模式回调
  final VoidCallback onSwitchToWrite;

  const NextOutlineView({
    Key? key,
    required this.novelId,
    required this.novelTitle,
    required this.onSwitchToWrite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部操作栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '剧情推演',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('返回写作'),
                onPressed: onSwitchToWrite,
              ),
            ],
          ),
        ),
        
        // 主内容区域
        Expanded(
          child: NextOutlineScreen(
            novelId: novelId,
            novelTitle: novelTitle,
          ),
        ),
      ],
    );
  }
}
