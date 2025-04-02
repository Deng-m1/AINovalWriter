import 'package:flutter/material.dart';

/// 无数据占位符组件
class NoDataPlaceholder extends StatelessWidget {
  
  const NoDataPlaceholder({
    Key? key,
    required this.message,
    required this.icon,
    this.color,
    this.size = 64,
  }) : super(key: key);
  final String message;
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: size,
            color: color ?? theme.disabledColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 