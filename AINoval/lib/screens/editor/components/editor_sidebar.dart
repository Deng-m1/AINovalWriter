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
    return Container(
      width: 280,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // 小说标题
          _buildNovelTitle(),
          
          // 标签页导航
          TabBar(
            controller: widget.tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.book_outlined),
                text: 'Codex',
              ),
              Tab(
                icon: Icon(Icons.snippet_folder_outlined),
                text: 'Snippets',
              ),
              Tab(
                icon: Icon(Icons.chat_outlined),
                text: 'Chats',
              ),
            ],
          ),
          
          // 标签页内容
          Expanded(
            child: TabBarView(
              controller: widget.tabController,
              children: [
                // Codex 标签页
                _buildCodexTab(),
                
                // Snippets 标签页
                const _SnippetsTab(),
                
                // Chats 标签页 - 替换为提示使用右侧聊天功能的界面
                _ChatRedirectTab(onOpenAIChat: widget.onOpenAIChat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovelTitle() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.book, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.novel.title,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildCodexTab() {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索条目...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
}

class _CodexEmptyState extends StatelessWidget {
  const _CodexEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Codex为空',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Codex存储有关您的故事世界的信息',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: const Text('创建新条目'),
          ),
        ],
      ),
    );
  }
}

class _SnippetsTab extends StatelessWidget {
  const _SnippetsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Snippets功能将在未来版本中推出'),
    );
  }
}

// 新增的聊天重定向标签页
class _ChatRedirectTab extends StatelessWidget {
  const _ChatRedirectTab({
    this.onOpenAIChat,
  });
  
  final VoidCallback? onOpenAIChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '使用右侧AI聊天',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '我们已经将聊天功能移至右侧，点击顶部的Chat按钮或下方的按钮打开AI聊天',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onOpenAIChat,
            icon: const Icon(Icons.chat),
            label: const Text('打开AI聊天'),
          ),
        ],
      ),
    );
  }
} 