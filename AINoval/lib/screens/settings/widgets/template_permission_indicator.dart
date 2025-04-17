import 'package:flutter/material.dart';

/// 模板权限指示器组件
/// 
/// 用于显示当前模板的类型（公共/私有）
class TemplatePermissionIndicator extends StatelessWidget {
  /// 是否为公共模板
  final bool isPublic;
  
  /// 复制到私有模板的回调（仅公共模板有效）
  final VoidCallback? onCopyToPrivate;
  
  const TemplatePermissionIndicator({
    Key? key,
    required this.isPublic,
    this.onCopyToPrivate,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isPublic 
          ? theme.colorScheme.primary.withOpacity(0.1)
          : theme.colorScheme.secondary.withOpacity(0.1),
        border: Border.all(
          color: isPublic
            ? theme.colorScheme.primary.withOpacity(0.2)
            : theme.colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock_outline,
            size: 16,
            color: isPublic
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            isPublic ? '公共模板（只读）' : '私有模板',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isPublic
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
            ),
          ),
          const Spacer(),
          if (isPublic && onCopyToPrivate != null)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('复制到我的模板'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(120, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onCopyToPrivate,
            ),
        ],
      ),
    );
  }
} 