import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/widgets/ai_generation_panel.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/blocs/sidebar/sidebar_bloc.dart';

import 'chapter_directory_tab.dart';

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
  String _selectedMode = 'codex';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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

                // 章节目录标签页 - 替换原来的Chats标签页
                ChapterDirectoryTab(novel: widget.novel),

                // 添加AI生成选项
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('AI生成'),
                  subtitle: const Text('AI辅助内容生成'),
                  onTap: () {
                    setState(() {
                      _selectedMode = 'ai_generation';
                    });
                  },
                  selected: _selectedMode == 'ai_generation',
                ),
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
      titleSpacing: 0,
      title: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            tooltip: '返回小说列表',
            splashRadius: 18,
            onPressed: () {
              Navigator.pop(context);
            },
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(34, 34),
            ),
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            tooltip: '小说设置',
            splashRadius: 18,
            onPressed: widget.onOpenSettings,
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(34, 34),
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
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  widget.novel.author ?? 'Unknown Author', // 使用模型中的作者信息
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // 侧边栏折叠按钮
          IconButton(
            icon: const Icon(Icons.format_indent_decrease, size: 18),
            tooltip: '折叠侧边栏',
            splashRadius: 18,
            onPressed: widget.onToggleSidebar,
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(34, 34),
            ),
          ),
          // 调整宽度按钮
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 18),
            tooltip: '调整侧边栏宽度',
            splashRadius: 18,
            onPressed: widget.onAdjustWidth,
            style: IconButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(34, 34),
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
        indicatorWeight: 2.0, // 减小指示器粗细
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13, // 减小字体大小
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13, // 减小字体大小
        ),
        dividerColor: Colors.transparent,
        isScrollable: false, // 确保不可滚动，平均分配空间
        labelPadding: const EdgeInsets.symmetric(horizontal: 2.0), // 减小标签内边距
        padding: const EdgeInsets.symmetric(horizontal: 2.0), // 减小整体内边距
        tabs: const [
          Tab(
            icon: Icon(Icons.menu_book_outlined, size: 18), // 减小图标大小
            text: 'Codex',
            height: 48, // 减小高度
          ),
          Tab(
            icon: Icon(Icons.bookmark_border_outlined, size: 18), // 减小图标大小
            text: 'Snippets',
            height: 48, // 减小高度
          ),
          Tab(
            icon: Icon(Icons.menu_outlined, size: 18), // 更改为目录图标
            text: '章节目录', // 更改为"章节目录"
            height: 48, // 减小高度
          ),
          Tab(
            icon: Icon(Icons.auto_awesome, size: 18), // AI生成图标
            text: 'AI生成',
            height: 48, // 减小高度
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
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
                    height: 34,
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
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            // TODO: 实现筛选功能
                          },
                          splashRadius: 16,
                          tooltip: '筛选',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 新建条目按钮
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: 实现创建新条目逻辑
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('New'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                // Codex 设置按钮
                IconButton(
                  onPressed: () {
                    // TODO: 实现 Codex 设置逻辑
                  },
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                  tooltip: 'Codex 设置',
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
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
          // 使用Expanded包裹Wrap来确保按钮能够在可用空间内自动排列
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min, // 确保Row只占用所需空间
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

