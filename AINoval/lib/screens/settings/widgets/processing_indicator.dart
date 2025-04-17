import 'package:flutter/material.dart';

/// 处理状态指示器组件
class ProcessingIndicator extends StatelessWidget {
  /// 进度值（0.0-1.0）
  final double progress;
  
  /// 取消操作回调
  final VoidCallback? onCancel;
  
  const ProcessingIndicator({
    Key? key,
    this.progress = 0.0,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showProgress = progress > 0 && progress < 1.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // 标题和进度指示
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '正在优化提示词模板...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusMessage(progress),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCancel != null)
                TextButton.icon(
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('取消'),
                  onPressed: onCancel,
                ),
            ],
          ),
          
          // 进度条
          if (showProgress) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  /// 获取状态消息
  String _getStatusMessage(double progress) {
    if (progress < 0.1) {
      return '正在分析提示词内容...';
    } else if (progress < 0.4) {
      return '生成优化建议中...';
    } else if (progress < 0.7) {
      return '应用语言模型增强中...';
    } else if (progress < 0.9) {
      return '润色和格式化内容...';
    } else {
      return '优化即将完成...';
    }
  }
} 