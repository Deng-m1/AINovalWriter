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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
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
                ),
              ],
            ),
          ),
          
          // 上下文项目列表
          Expanded(
            child: this.context.relevantItems.isEmpty
                ? const Center(child: Text('没有相关上下文信息'))
                : ListView.builder(
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
    return Card(
      margin: const EdgeInsets.all(8),
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
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(item.relevanceScore * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              item.content,
              style: Theme.of(context).textTheme.bodyMedium,
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