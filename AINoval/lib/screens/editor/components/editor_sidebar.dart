import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/widgets/ai_generation_panel.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';

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

/// 章节目录标签页组件
class ChapterDirectoryTab extends StatefulWidget {
  const ChapterDirectoryTab({
    super.key,
    required this.novel,
  });
  final NovelSummary novel;

  @override
  State<ChapterDirectoryTab> createState() => _ChapterDirectoryTabState();
}

class _ChapterDirectoryTabState extends State<ChapterDirectoryTab> {
  final TextEditingController _jumpController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchText = '';
  int? _selectedChapterNumber;
  final Map<String, bool> _expandedChapters = {};
  late EditorScreenController _editorController;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // 获取EditorScreenController实例
    _editorController = Provider.of<EditorScreenController>(context, listen: false);
    // 默认第一个章节展开
    _initExpandedChapters();
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initExpandedChapters() {
    // 获取小说结构并默认展开第一章
    final novel = context.read<EditorBloc>().state;
    if (novel is EditorLoaded && novel.novel.acts.isNotEmpty) {
      for (final act in novel.novel.acts) {
        if (act.chapters.isNotEmpty) {
          // 默认展开第一个章节
          _expandedChapters[act.chapters.first.id] = true;
          break;
        }
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.trim();
    });
  }

  void _toggleChapter(String chapterId) {
    final isCurrentlyExpanded = _expandedChapters[chapterId] ?? false;
    
    // 如果要展开章节并且该章节的场景可能是空的，加载所有场景
    if (!isCurrentlyExpanded) {
      // 使用控制器中的方法预加载场景，使用preventFocusChange=true确保不会导致跳转或改变焦点
      AppLogger.i('ChapterDirectoryTab', '展开章节，预加载场景: $chapterId');
      _editorController.preloadChapterScenes(chapterId);
    }
    
    // 直接切换展开状态
    setState(() {
      _expandedChapters[chapterId] = !isCurrentlyExpanded;
    });
  }

  void _jumpToChapter() {
    try {
      final chapterNumber = int.parse(_jumpController.text.trim());
      if (chapterNumber < 1) {
        _showErrorSnackbar('章节号必须大于0');
        return;
      }

      final novel = context.read<EditorBloc>().state;
      if (novel is EditorLoaded) {
        // 扁平化所有章节以便按序号查找
        final allChapters = <novel_models.Chapter>[];
        for (final act in novel.novel.acts) {
          allChapters.addAll(act.chapters);
        }
        
        // 按order排序
        allChapters.sort((a, b) => a.order.compareTo(b.order));
        
        if (chapterNumber > allChapters.length) {
          _showErrorSnackbar('章节号超出范围');
          return;
        }
        
        // 由于章节序号是从1开始，所以需要减1来获取索引
        final chapter = allChapters[chapterNumber - 1];
        
        // 确保章节展开
        setState(() {
          _expandedChapters[chapter.id] = true;
          _selectedChapterNumber = chapterNumber;
        });
        
        // 滚动到对应章节
        Future.delayed(const Duration(milliseconds: 300), () {
          final context = _getChapterContext(chapter.id);
          if (context != null) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.3, // 滚动位置：0表示顶部，0.5表示中间，1表示底部
              duration: const Duration(milliseconds: 500),
            );
          }
          
          // 5秒后清除高亮
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _selectedChapterNumber = null;
              });
            }
          });
        });
        
        // 清空输入框
        _jumpController.clear();
      }
    } catch (e) {
      _showErrorSnackbar('请输入有效的章节号');
    }
  }
  
  // 获取章节的BuildContext，用于滚动定位
  BuildContext? _getChapterContext(String chapterId) {
    final key = GlobalKey();
    final chapterKey = GlobalObjectKey('chapter_$chapterId');
    return chapterKey.currentContext;
  }
  
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _navigateToScene(String actId, String chapterId, String sceneId) {
    final editorBloc = context.read<EditorBloc>();
    
    // 先加载当前章节的场景（确保内容已加载）
    AppLogger.i('ChapterDirectoryTab', '开始加载章节场景: $actId - $chapterId - $sceneId');
    editorBloc.add(LoadMoreScenes(
      fromChapterId: chapterId,
      direction: 'center',
      chaptersLimit: 5, // 增加加载章节数量，确保足够加载所有内容
      targetActId: actId,
      targetChapterId: chapterId,
      targetSceneId: sceneId,
      preventFocusChange: false // 确保设置为false，允许改变焦点
    ));
    
    // 直接设置活动场景，不需要再延迟
    editorBloc.add(SetActiveScene(
      actId: actId,
      chapterId: chapterId,
      sceneId: sceneId,
    ));
    
    // 主动滚动到活动场景
    _scrollToActiveScene(actId, chapterId, sceneId);
    
    AppLogger.i('ChapterDirectoryTab', '已发送场景跳转请求: $actId - $chapterId - $sceneId');
  }
  
  // 滚动到活动场景的辅助方法
  void _scrollToActiveScene(String actId, String chapterId, String sceneId) {
    // 延迟500ms确保UI已经更新
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_editorController.editorMainAreaKey.currentState != null) {
        _editorController.editorMainAreaKey.currentState!.scrollToActiveScene();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state is EditorLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is EditorLoaded) {
          return Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // 跳转和搜索区域
                _buildSearchAndJumpSection(theme),
                
                // 章节列表
                Expanded(
                  child: state.novel.acts.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildChapterList(state.novel, theme),
                ),
              ],
            ),
          );
        } else {
          return Center(
            child: Text('加载失败，请重试', style: TextStyle(color: Colors.grey.shade600)),
          );
        }
      },
    );
  }
  
  Widget _buildSearchAndJumpSection(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 跳转区域
          Row(
            children: [
              Text('跳转至:', style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              )),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _jumpController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    decoration: InputDecoration(
                      hintText: '章节号',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _jumpToChapter(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _jumpToChapter,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 搜索区域
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              decoration: InputDecoration(
                hintText: '搜索章节和场景...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search, size: 16, color: Colors.grey.shade600),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            '暂无章节',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w600, 
              color: Colors.grey.shade800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '小说结构创建中，请稍后再试',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChapterList(novel_models.Novel novel, ThemeData theme) {
    final chapters = <Widget>[];
    int chapterCounter = 0; // 记录总章节序号，用于显示
    final primaryColorLight = theme.colorScheme.primary.withOpacity(0.1);
    
    // 将章节和场景平铺为一个列表
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        chapterCounter++;
        
        // 这是当前循环章节的序号
        final chapterNumber = chapterCounter;
        
        // 如果有搜索文本，判断是否此章节应该显示
        bool shouldShowChapter = true;
        bool hasMatchingScene = false;
        
        if (_searchText.isNotEmpty) {
          // 检查章节标题是否匹配
          shouldShowChapter = chapter.title.toLowerCase().contains(_searchText.toLowerCase());
          
          // 检查是否有匹配的场景
          for (final scene in chapter.scenes) {
            if (scene.summary.content.toLowerCase().contains(_searchText.toLowerCase())) {
              hasMatchingScene = true;
              break;
            }
          }
          
          // 如果章节标题不匹配且没有匹配的场景，则不显示该章节
          if (!shouldShowChapter && !hasMatchingScene) {
            continue;
          }
        }
        
        // 构建章节组件
        final chapterKey = GlobalObjectKey('chapter_${chapter.id}');
        final isExpanded = _expandedChapters[chapter.id] ?? false;
        final isHighlighted = _selectedChapterNumber == chapterNumber;
        
        // 尝试获取EditorBloc状态判断当前章节是否活跃
        bool isActiveChapter = false;
        final editorState = context.read<EditorBloc>().state;
        if (editorState is EditorLoaded) {
          isActiveChapter = editorState.activeChapterId == chapter.id;
        }
        
        chapters.add(
          AnimatedContainer(
            key: chapterKey,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isHighlighted 
                  ? theme.colorScheme.primary.withOpacity(0.08) 
                  : isActiveChapter 
                      ? primaryColorLight 
                      : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isHighlighted || isActiveChapter
                      ? theme.colorScheme.primary.withOpacity(0.15)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: isHighlighted || isActiveChapter ? 4 : 2,
                  offset: const Offset(0, 1),
                ),
              ],
              border: isActiveChapter
                  ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 章节标题行
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: theme.colorScheme.primary.withOpacity(0.1),
                    highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                    onTap: () => _toggleChapter(chapter.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          // 箭头图标
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: Transform.rotate(
                              angle: isExpanded ? 0.0 : -1.5708, // 0 或 -90度
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: isHighlighted || isActiveChapter
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          
                          // 章节状态指示器（活跃章节有颜色）
                          if (isActiveChapter) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          
                          Expanded(
                            child: Text(
                              '第$chapterNumber章：${chapter.title}',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: isHighlighted || isActiveChapter
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade800,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // 章节场景数量和字数
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHighlighted || isActiveChapter 
                                ? theme.colorScheme.primary.withOpacity(0.15)
                                : theme.colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 10,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${chapter.scenes.length}场景',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Container(
                                  width: 1,
                                  height: 8,
                                  color: theme.colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${chapter.wordCount}字',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 场景列表（如果章节展开）
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: AnimatedCrossFade(
                    firstChild: const SizedBox(height: 0),
                    secondChild: _buildScenesList(act.id, chapter, _searchText, theme),
                    crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                    sizeCurve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    if (chapters.isEmpty && _searchText.isNotEmpty) {
      // 没有搜索结果
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '没有匹配的章节或场景',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试其他关键词重新搜索',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('清除搜索'),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchText = '';
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: chapters,
    );
  }
  
  Widget _buildScenesList(
    String actId, 
    novel_models.Chapter chapter, 
    String searchText, 
    ThemeData theme
  ) {
    final scenes = <Widget>[];
    
    // 尝试获取EditorBloc状态判断当前场景是否活跃
    String? activeSceneId;
    final editorState = context.read<EditorBloc>().state;
    if (editorState is EditorLoaded) {
      activeSceneId = editorState.activeSceneId;
    }
    
    for (int i = 0; i < chapter.scenes.length; i++) {
      final scene = chapter.scenes[i];
      
      // 如果有搜索文本，过滤场景
      if (searchText.isNotEmpty) {
        final matchesTitle = 'Scene ${i + 1}'.toLowerCase().contains(searchText.toLowerCase());
        final matchesSummary = scene.summary.content.toLowerCase().contains(searchText.toLowerCase());
        
        if (!matchesTitle && !matchesSummary) {
          continue;
        }
      }
      
      // 获取摘要，截取一定长度
      final summaryText = scene.summary.content.isEmpty 
          ? '(无摘要)' 
          : scene.summary.content;
      final truncatedSummary = summaryText.length > 100 
          ? '${summaryText.substring(0, 100)}...' 
          : summaryText;
          
      // 检查是否为活跃场景
      final isActiveScene = scene.id == activeSceneId;
      
      scenes.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActiveScene 
                ? theme.colorScheme.primary.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActiveScene 
                ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              splashColor: theme.colorScheme.primary.withOpacity(0.1),
              highlightColor: theme.colorScheme.primary.withOpacity(0.05),
              onTap: () => _navigateToScene(actId, chapter.id, scene.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 场景图标指示器
                        Icon(
                          isActiveScene 
                              ? Icons.article
                              : Icons.article_outlined, 
                          size: 14, 
                          color: isActiveScene
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 8),
                        
                        // 场景标题
                        Text(
                          'Scene ${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActiveScene ? FontWeight.w600 : FontWeight.w500,
                            color: isActiveScene
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withOpacity(0.85),
                          ),
                        ),
                        
                        // 最后编辑时间
                        const Spacer(),
                        Text(
                          _formatTimestamp(scene.lastEdited),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        
                        // 字数显示
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isActiveScene
                                ? theme.colorScheme.primary.withOpacity(0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${scene.wordCount}字',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActiveScene
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // 场景摘要
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isActiveScene
                            ? theme.colorScheme.primary.withOpacity(0.03)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActiveScene
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        truncatedSummary,
                        style: TextStyle(
                          fontSize: 12,
                          color: isActiveScene
                              ? Colors.grey.shade800
                              : Colors.grey.shade700,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // 如果场景列表为空，添加一个提示
    if (scenes.isEmpty) {
      scenes.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              '本章节暂无场景',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: scenes),
    );
  }
  
  // 格式化时间戳为友好格式
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      // 超过一周，显示日期
      return '${timestamp.month}/${timestamp.day}';
    } else if (difference.inDays > 0) {
      // 显示几天前
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      // 显示几小时前
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      // 显示几分钟前
      return '${difference.inMinutes}分钟前';
    } else {
      // 刚刚
      return '刚刚';
    }
  }
}
