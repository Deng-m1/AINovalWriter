import 'package:flutter/material.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;

/// 编辑器侧边栏组件
class EditorSidebar extends StatelessWidget {
  
  const EditorSidebar({
    super.key,
    required this.novel,
    required this.currentChapterId,
    required this.onChapterSelected,
    required this.onAddChapter,
  });
  
  final novel_models.Novel novel;
  final String currentChapterId;
  final Function(String) onChapterSelected;
  final VoidCallback onAddChapter;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  novel.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  '总字数: ${novel.wordCount}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '最后编辑: ${_formatDate(novel.updatedAt)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    '章节列表',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ...novel.acts.expand((act) => [
                  ListTile(
                    title: Text(
                      act.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    tileColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  ...act.chapters.map((chapter) => ListTile(
                    title: Text(chapter.title),
                    selected: chapter.id == currentChapterId,
                    selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    onTap: () => onChapterSelected(chapter.id),
                    contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                  )),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: onAddChapter,
              icon: const Icon(Icons.add),
              label: const Text('添加章节'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} 分钟前';
      }
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
} 