import 'package:ainoval/models/novel_summary.dart';
import 'package:flutter/material.dart';

class EditorSidebar extends StatefulWidget {
  const EditorSidebar({
    super.key,
    required this.novel,
    required this.tabController,
    this.onOpenAIChat,
    this.onOpenSettings,
    this.onToggleSidebar,
    this.onAdjustWidth,
  });
  final NovelSummary novel;
  final TabController tabController;
  final VoidCallback? onOpenAIChat;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onAdjustWidth;

  @override
  State<EditorSidebar> createState() => _EditorSidebarState();
}

class _EditorSidebarState extends State<EditorSidebar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部应用栏
          _buildAppBar(theme),

          // 标签页导航
          _buildTabBar(theme),

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

          // 底部导航栏
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      title: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: '返回小说列表',
            splashRadius: 20,
            onPressed: () {
              Navigator.pop(context);
            },
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: '全局设置',
            splashRadius: 20,
            onPressed: widget.onOpenSettings,
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          // 标题和作者信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.novel.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.grey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Deng Binjie', // 使用作者名，此处硬编码，实际应从数据模型获取
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 侧边栏折叠按钮
          IconButton(
            icon: const Icon(Icons.format_indent_decrease, size: 20),
            tooltip: '折叠侧边栏',
            splashRadius: 20,
            onPressed: widget.onToggleSidebar,
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          // 调整宽度按钮
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20),
            tooltip: '调整侧边栏宽度',
            splashRadius: 20,
            onPressed: widget.onAdjustWidth,
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: TabBar(
        controller: widget.tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3.0, // 增加指示器粗细
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            icon: Icon(Icons.menu_book_outlined, size: 20),
            text: 'Codex',
            height: 56, // 调整高度
          ),
          Tab(
            icon: Icon(Icons.bookmark_border_outlined, size: 20),
            text: 'Snippets',
            height: 56, // 调整高度
          ),
          Tab(
            icon: Icon(Icons.forum_outlined, size: 20),
            text: 'Chats',
            height: 56, // 调整高度
          ),
        ],
      ),
    );
  }

  Widget _buildCodexTab(ThemeData theme) {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索和操作栏
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                // 搜索框
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search all entries...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            // TODO: 实现筛选功能
                          },
                          splashRadius: 20,
                          tooltip: '筛选',
                          padding: EdgeInsets.zero,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 新建条目按钮
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: 实现创建新条目逻辑
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Entry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Codex 设置按钮
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // TODO: 实现 Codex 设置逻辑
                    },
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    tooltip: 'Codex 设置',
                    splashRadius: 20,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Codex 空状态
          Expanded(
            child: _CodexEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab({required IconData icon, required String text}) {
    return Container(
      color: Colors.grey.shade50,
      child: Center(
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
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // 用户头像
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(
                Icons.person_outline,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          // 帮助按钮
          _buildBottomBarItem(
            icon: Icons.help_outline,
            label: 'Help',
            onTap: () {
              // TODO: 实现帮助功能
            },
          ),
          // 提示按钮
          _buildBottomBarItem(
            icon: Icons.lightbulb_outline,
            label: 'Prompts',
            onTap: () {
              // TODO: 实现提示功能
            },
          ),
          // 导出按钮
          _buildBottomBarItem(
            icon: Icons.download_outlined,
            label: 'Export',
            onTap: () {
              // TODO: 实现导出功能
            },
          ),
          // 保存按钮
          _buildBottomBarItem(
            icon: Icons.bookmark_border_outlined,
            label: 'Saved',
            onTap: () {
              // TODO: 实现保存功能
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
        children: [
          Text(
            'YOUR CODEX IS EMPTY',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Codex stores information about the world your story takes place in, its inhabitants and more.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              // 该点击应执行与"+ New Entry"按钮相同的操作
            },
            child: Text(
              '→ Create a new entry by clicking the button above.',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
    return Container(
      color: Colors.grey.shade50,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'AI 聊天已移至右侧',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
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
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
