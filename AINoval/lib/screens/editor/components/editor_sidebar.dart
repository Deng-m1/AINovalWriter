import 'package:ainoval/models/novel_summary.dart';
import 'package:flutter/material.dart';

class EditorSidebar extends StatefulWidget {
  const EditorSidebar({
    super.key,
    required this.novel,
    required this.tabController,
    this.onOpenAIChat,
    this.onOpenSettings,
  });
  final NovelSummary novel;
  final TabController tabController;
  final VoidCallback? onOpenAIChat;
  final VoidCallback? onOpenSettings;

  @override
  State<EditorSidebar> createState() => _EditorSidebarState();
}

class _EditorSidebarState extends State<EditorSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.canvasColor,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // 小说标题
          _buildNovelTitle(theme),

          // 标签页导航
          TabBar(
            controller: widget.tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.menu_book_outlined),
                text: 'Codex',
              ),
              Tab(
                icon: Icon(Icons.bookmark_border_outlined),
                text: 'Snippets',
              ),
              Tab(
                icon: Icon(Icons.forum_outlined),
                text: 'Chats',
              ),
            ],
          ),
          const Divider(height: 1),

          // 标签页内容
          Expanded(
            child: TabBarView(
              controller: widget.tabController,
              children: [
                // Codex 标签页
                _buildCodexTab(theme),

                // Snippets 标签页
                _buildPlaceholderTab(
                    icon: Icons.bookmark_border_outlined,
                    text: 'Snippets 功能开发中'),

                // Chats 标签页
                _ChatRedirectTab(onOpenAIChat: widget.onOpenAIChat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovelTitle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 16.0),
      child: Row(
        children: [
          Icon(Icons.edit_note_outlined,
              size: 24, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.novel.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: '小说设置',
            splashRadius: 20,
            color: Colors.grey.shade600,
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildCodexTab(ThemeData theme) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索 Codex 条目...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              isDense: true,
            ),
          ),
        ),

        // 空状态提示
        const Expanded(
          child: _CodexEmptyState(),
        ),
      ],
    );
  }

  Widget _buildPlaceholderTab({required IconData icon, required String text}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CodexEmptyState extends StatelessWidget {
  const _CodexEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Codex 为空',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '使用 Codex 存储您的故事世界、角色、地点等信息。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: 实现创建新 Codex 条目逻辑
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('创建新条目'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRedirectTab extends StatelessWidget {
  const _ChatRedirectTab({
    this.onOpenAIChat,
  });

  final VoidCallback? onOpenAIChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'AI 聊天已移至右侧',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '点击顶部工具栏的聊天图标或下方按钮即可打开 AI 助手。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onOpenAIChat,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('打开 AI 聊天'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
