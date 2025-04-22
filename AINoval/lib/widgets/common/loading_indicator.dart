import 'package:flutter/material.dart';

/// 加载指示器
class LoadingIndicator extends StatelessWidget {
  /// 消息
  final String? message;
  
  /// 指示器大小
  final double size;
  
  /// 指示器粗细
  final double strokeWidth;
  
  /// 指示器颜色
  final Color? color;

  const LoadingIndicator({
    Key? key,
    this.message,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: color != null
                ? AlwaysStoppedAnimation<Color>(color!)
                : null,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
