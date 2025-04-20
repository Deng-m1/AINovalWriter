import 'package:flutter/material.dart';

/// 模型服务列表页面的头部组件
/// 包含标题、环境标签、搜索框、筛选下拉框和添加按钮
class ModelServiceHeader extends StatelessWidget {
  const ModelServiceHeader({
    super.key,
    required this.onSearch,
    required this.onAddNew,
    required this.onFilterChange,
  });

  final Function(String) onSearch;
  final VoidCallback onAddNew;
  final Function(String) onFilterChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(51),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 标题和环境标签
          Expanded(
            child: Row(
              children: [
                Text(
                  '模型服务',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withAlpha(179),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '生产环境',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.bolt,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '正常运行中',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 搜索框
          SizedBox(
            width: 200,
            height: 36,
            child: TextField(
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: '搜索模型服务...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: theme.hintColor.withAlpha(179),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: theme.colorScheme.onSurface.withAlpha(128),
                ),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(77),
                    width: 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(77),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surfaceContainerHighest.withAlpha(77)
                    : theme.colorScheme.surfaceContainerLowest.withAlpha(179),
              ),
              onChanged: onSearch,
            ),
          ),

          const SizedBox(width: 12),

          // 筛选下拉框
          SizedBox(
            width: 120,
            height: 36,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(77),
                    width: 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(77),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surfaceContainerHighest.withAlpha(77)
                    : theme.colorScheme.surfaceContainerLowest.withAlpha(179),
              ),
              value: 'all',
              style: theme.textTheme.bodyMedium,
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: theme.colorScheme.onSurface.withAlpha(179),
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('全部模型', style: const TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'verified',
                  child: Text('已验证', style: const TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: 'unverified',
                  child: Text('未验证', style: const TextStyle(fontSize: 13)),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onFilterChange(value);
                }
              },
            ),
          ),

          const SizedBox(width: 12),

          // 添加按钮
          ElevatedButton.icon(
            onPressed: onAddNew,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加服务', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(0, 36),
            ),
          ),

          const SizedBox(width: 8),

          // 设置按钮
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings, size: 18),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              backgroundColor: Colors.transparent,
              foregroundColor: theme.colorScheme.onSurface.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }
}
