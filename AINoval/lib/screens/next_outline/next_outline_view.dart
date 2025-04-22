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

  /// 跳转到添加模型页面的回调
  final VoidCallback? onNavigateToAddModel;

  /// 跳转到配置特定模型页面的回调
  final Function(String configId)? onConfigureModel;

  const NextOutlineView({
    Key? key,
    required this.novelId,
    required this.novelTitle,
    required this.onSwitchToWrite,
    this.onNavigateToAddModel,
    this.onConfigureModel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 主内容区域
        Expanded(
          child: NextOutlineScreen(
            novelId: novelId,
            novelTitle: novelTitle,
            onSwitchToWrite: onSwitchToWrite,
            onNavigateToAddModel: onNavigateToAddModel,
            onConfigureModel: onConfigureModel,
          ),
        ),
      ],
    );
  }
}
