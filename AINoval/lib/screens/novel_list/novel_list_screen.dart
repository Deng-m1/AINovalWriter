import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/blocs/novel_import/novel_import_bloc.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/editor_screen.dart';
import 'package:ainoval/screens/novel_list/widgets/continue_writing_section.dart';
import 'package:ainoval/screens/novel_list/widgets/empty_novel_view.dart';
import 'package:ainoval/screens/novel_list/widgets/header_section.dart';
import 'package:ainoval/screens/novel_list/widgets/loading_view.dart';
import 'package:ainoval/screens/novel_list/widgets/novel_card.dart';
import 'package:ainoval/screens/novel_list/widgets/novel_list_error_view.dart';
import 'package:ainoval/screens/novel_list/widgets/search_filter_bar.dart';
import 'package:ainoval/screens/novel_list/widgets/import_novel_dialog.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';
import 'package:ainoval/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen>
    with SingleTickerProviderStateMixin {
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _cardScaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cardScaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxContentWidth = screenSize.width * 0.5; // 内容最大宽度为屏幕的50%
    final maxContentHeight = screenSize.height * 0.75; // 内容最大高度为屏幕的75%

    return Scaffold(
      body: MainBackground(
        child: Center(
          child: ScaleTransition(
            scale: _cardScaleAnimation,
            child: MainCard(
              maxWidth: maxContentWidth,
              maxHeight: maxContentHeight,
              isGridView: _isGridView,
              searchController: _searchController,
              onViewTypeChanged: (isGrid) {
                setState(() {
                  _isGridView = isGrid;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 主背景组件
class MainBackground extends StatelessWidget {
  const MainBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背景层
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.1),
                BlendMode.darken,
              ),
            ),
          ),
        ),

        // 试用期过期提示
        const TrialExpiredBanner(),

        // 主内容
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: child,
        ),
      ],
    );
  }
}

/// 试用期过期横幅
class TrialExpiredBanner extends StatelessWidget {
  const TrialExpiredBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请联系管理员升级您的账户')),
            );
          },
          child: Container(
            color: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  '您的试用期已过期。请升级账户以继续编辑。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('升级功能将在下一个版本中实现')),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '立即升级',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 主卡片组件
class MainCard extends StatelessWidget {
  const MainCard({
    super.key,
    required this.maxWidth,
    required this.maxHeight,
    required this.isGridView,
    required this.searchController,
    required this.onViewTypeChanged,
  });

  final double maxWidth;
  final double maxHeight;
  final bool isGridView;
  final TextEditingController searchController;
  final ValueChanged<bool> onViewTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final novelRepository = context.read<NovelRepository>();

    return BlocProvider(
      create: (context) => NovelImportBloc(novelRepository: novelRepository),
      child: Builder(
        builder: (context) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Card(
              elevation: 12,
              margin: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  HeaderSection(
                    onCreateNovel: () => _showCreateNovelDialog(context),
                    onImportNovel: () => _showImportNovelDialog(context),
                  ),

                  // 标题下方说明文本
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Text(
                          '这是你的个人小说库，你想今天写哪一部？',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        // 添加帮助按钮
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('帮助文档将在下一个版本中提供')),
                            );
                          },
                          icon: Icon(
                            Icons.help_outline,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          tooltip: '帮助',
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // 继续写作区域
                  const ContinueWritingSection(),

                  // 搜索和过滤工具栏
                  SearchFilterBar(
                    searchController: searchController,
                    isGridView: isGridView,
                    onSearchChanged: (query) {
                      context.read<NovelListBloc>().add(SearchNovels(query: query));
                    },
                    onViewTypeChanged: onViewTypeChanged,
                    onFilterPressed: () => _showFilterOptions(context),
                    onSortPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('排序功能将在下一个迭代中实现')),
                      );
                    },
                    onGroupPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('分组功能将在下一个迭代中实现')),
                      );
                    },
                  ),

                  // 主要内容区域（小说列表）
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: BlocBuilder<NovelListBloc, NovelListState>(
                        builder: (context, state) {
                          if (state is NovelListInitial) {
                            context.read<NovelListBloc>().add(LoadNovels());
                            return const LoadingView();
                          } else if (state is NovelListLoading) {
                            return const LoadingView();
                          } else if (state is NovelListLoaded) {
                            if (state.novels.isEmpty) {
                              return EmptyNovelView(
                                onCreateTap: () => _showCreateNovelDialog(context),
                              );
                            }

                            return NovelListSection(
                              novels: state.novels,
                              isGridView: isGridView,
                            );
                          } else if (state is NovelListError) {
                            return NovelListErrorView(
                              message: state.message,
                              onRetry: () {
                                context.read<NovelListBloc>().add(LoadNovels());
                              },
                            );
                          }
                          return const LoadingView();
                        },
                      ),
                    ),
                  ),

                  // 底部版本信息
                  VersionFooter(),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  // 显示过滤选项
  void _showFilterOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('过滤选项'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('根据系列:'),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('全部')),
                Chip(label: Text('无系列')),
                Chip(label: Text('武侠系列')),
                Chip(label: Text('科幻系列')),
              ],
            ),
            SizedBox(height: 16),
            Text('根据状态:'),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('所有状态')),
                Chip(label: Text('进行中')),
                Chip(label: Text('已完成')),
                Chip(label: Text('草稿')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }

  // 显示创建小说对话框
  void _showCreateNovelDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController seriesController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.create_new_folder_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(l10n.createNovel),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: l10n.novelTitle,
                hintText: l10n.novelTitleHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.book_outlined),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: seriesController,
              decoration: InputDecoration(
                labelText: l10n.seriesName,
                hintText: l10n.seriesNameHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.bookmarks_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '添加系列可以更好地组织您的作品',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () {
              final title = titleController.text.trim();
              final series = seriesController.text.trim();

              if (title.isNotEmpty) {
                Navigator.pop(context);

                context.read<NovelListBloc>().add(CreateNovel(
                      title: title,
                      seriesName: series.isNotEmpty ? series : null,
                    ));
              }
            },
            icon: const Icon(Icons.check),
            label: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  // 显示导入小说对话框
  void _showImportNovelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const ImportNovelDialog(),
    );
  }
}

/// 版本底部栏
class VersionFooter extends StatelessWidget {
  const VersionFooter({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Build Alpha1',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Released ${DateFormatter.formatDate(DateTime.now())}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 小说列表区域
class NovelListSection extends StatelessWidget {
  const NovelListSection({
    super.key,
    required this.novels,
    required this.isGridView,
  });

  final List<NovelSummary> novels;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签栏
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Row(
                children: [
                  Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '无系列',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${novels.length} 本书',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // "全部阅读"的链接
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('阅读模式将在下一个版本中实现')),
                  );
                },
                icon: Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  '全部阅读',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        // 小说列表
        Expanded(
          child: isGridView
              ? _buildNovelGrid(novels, context)
              : _buildNovelListView(novels, context),
        ),
      ],
    );
  }

  // 小说网格视图
  Widget _buildNovelGrid(List<NovelSummary> novels, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth * 0.5 - 32;
    // 动态计算每行显示的卡片数量，但不少于2个，不多于6个
    final crossAxisCount = (availableWidth / 160).floor().clamp(2, 6);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7, // 更好的纵横比，适合书籍封面
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      padding: const EdgeInsets.all(16),
      itemCount: novels.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return NovelCard(
          novel: novels[index],
          onTap: () => _navigateToEditor(novels[index], context),
          isGridView: true,
        );
      },
    );
  }

  // 小说列表视图
  Widget _buildNovelListView(List<NovelSummary> novels, BuildContext context) {
    return ListView.builder(
      itemCount: novels.length,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return NovelCard(
          novel: novels[index],
          onTap: () => _navigateToEditor(novels[index], context),
          isGridView: false,
        );
      },
    );
  }

  // 导航到编辑器
  void _navigateToEditor(NovelSummary novel, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(novel: novel),
      ),
    );
  }
}
