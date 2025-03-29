import 'package:flutter/material.dart';
import '../../../models/chat_models.dart';

class ContextPanel extends StatelessWidget {
  const ContextPanel({
    Key? key,
    required this.context,
    required this.onClose,
  }) : super(key: key);
  final ChatContext context;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      // 使用 surfaceContainerLow 作为背景，与 ai_chat_sidebar 区分但又协调
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5), // 更细微的边框
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 面板标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // 使用 surfaceContainer 作为标题背景
              color: colorScheme.surfaceContainer,
              // 底部边框调整
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '上下文信息',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: '关闭面板',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  // 调整关闭按钮颜色
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),

          // 上下文项目列表
          Expanded(
            child: this.context.relevantItems.isEmpty
                ? Center(
                    child: Text(
                    '无相关上下文信息',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant), // 调整空状态文本颜色
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0), // 为列表添加整体边距
                    itemCount: this.context.relevantItems.length,
                    itemBuilder: (context, index) {
                      final item = this.context.relevantItems[index];
                      return _buildContextItem(context, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 构建上下文项目卡片
  Widget _buildContextItem(BuildContext context, ContextItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0.5, // 减少卡片阴影
      margin: const EdgeInsets.only(bottom: 8), // 只保留底部间距
      // 卡片背景色
      color: colorScheme.surfaceContainerHigh, // 使用比面板背景稍亮的颜色
      shape: RoundedRectangleBorder(
          // 圆角和边框
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.3), width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildContextTypeIcon(item.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600, // 加粗标题
                          color: colorScheme.onSurface, // 标题颜色
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8), // 图标和相关度之间的间距
                // 相关度标签样式调整
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3), // 内边距
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5), // 背景色
                    borderRadius: BorderRadius.circular(12), // 圆角
                  ),
                  child: Text(
                    '${(item.relevanceScore * 100).toInt()}% 相关', // 添加 "相关" 文字
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer, // 文字颜色
                          fontWeight: FontWeight.w500,
                          fontSize: 11, // 稍小字体
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // 标题和分割线间距
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withOpacity(0.3)), // 分割线样式
            const SizedBox(height: 8), // 分割线和内容间距
            Text(
              item.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant, // 内容文字颜色
                    height: 1.4, // 行高
                  ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 根据上下文类型返回对应图标
  Widget _buildContextTypeIcon(ContextItemType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case ContextItemType.character:
        iconData = Icons.person;
        color = Colors.blue;
        break;
      case ContextItemType.location:
        iconData = Icons.place;
        color = Colors.green;
        break;
      case ContextItemType.plot:
        iconData = Icons.auto_stories;
        color = Colors.purple;
        break;
      case ContextItemType.chapter:
        iconData = Icons.bookmark;
        color = Colors.orange;
        break;
      case ContextItemType.scene:
        iconData = Icons.movie;
        color = Colors.red;
        break;
      case ContextItemType.note:
        iconData = Icons.note;
        color = Colors.teal;
        break;
      case ContextItemType.lore:
        iconData = Icons.history_edu;
        color = Colors.brown;
        break;
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(iconData, size: 16, color: color),
    );
  }
}
