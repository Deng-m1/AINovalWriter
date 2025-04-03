import 'package:flutter/material.dart';

class NovelListErrorView extends StatelessWidget {
  const NovelListErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ErrorCard(
        title: '加载失败',
        message: message,
        icon: Icons.error_outline_rounded,
        primaryAction: RetryButton(onRetry: onRetry),
        secondaryAction: const HelpButton(),
      ),
    );
  }
}

/// 通用错误展示卡片
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.primaryAction,
    this.secondaryAction,
    this.maxWidth = 320,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget primaryAction;
  final Widget? secondaryAction;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标部分
          ErrorIconContainer(
            icon: icon,
            iconColor: theme.colorScheme.error,
            backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.2),
          ),
          const SizedBox(height: 24),

          // 标题
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 消息内容
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // 主操作按钮
          primaryAction,

          // 次要操作按钮
          if (secondaryAction != null) ...[
            const SizedBox(height: 8),
            secondaryAction!,
          ],
        ],
      ),
    );
  }
}

/// 错误图标容器
class ErrorIconContainer extends StatelessWidget {
  const ErrorIconContainer({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.size = 48,
    this.padding = 16,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: size,
        color: iconColor,
      ),
    );
  }
}

/// 重试按钮
class RetryButton extends StatelessWidget {
  const RetryButton({
    super.key,
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('重新加载'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// 帮助按钮
class HelpButton extends StatelessWidget {
  const HelpButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: () {
        // 添加一个帮助选项
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('帮助功能将在下一个版本中实现')),
        );
      },
      child: Text(
        '需要帮助？',
        style: TextStyle(
          color: theme.colorScheme.primary.withOpacity(0.8),
        ),
      ),
    );
  }
}
