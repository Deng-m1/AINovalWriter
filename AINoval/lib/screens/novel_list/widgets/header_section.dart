import 'package:flutter/material.dart';

/// 标题栏组件
class HeaderSection extends StatelessWidget {
  const HeaderSection({
    super.key,
    required this.onCreateNovel,
  });

  final VoidCallback onCreateNovel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '你的小说',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: 导入小说
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导入功能将在下一个版本中实现')),
                  );
                },
                icon: const Icon(Icons.file_upload),
                label: const Text('导入'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onCreateNovel,
                icon: const Icon(Icons.add),
                label: const Text('创建小说'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
