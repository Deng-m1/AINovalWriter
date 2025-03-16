import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/editor_screen.dart';
import 'package:ainoval/screens/novel_list/widgets/novel_card.dart';
import 'package:ainoval/screens/novel_list/widgets/novel_list_error_view.dart';
import 'package:ainoval/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> {
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blueGrey.shade50,
                  Colors.grey.shade100,
                ],
              ),
            ),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text(
                '您的试用期已过期。请升级账户以继续编辑。只读访问仍然可用。→',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenSize.width * 0.5,
                  maxHeight: screenSize.height * 0.75,
                ),
                child: Card(
                  elevation: 8,
                  margin: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
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
                                  onPressed: () => _showCreateNovelDialog(),
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
                      ),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        color: Colors.white,
                        child: const Text(
                          '这是你的个人小说库，你想今天写哪一部？',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      
                      _buildContinueWritingSection(),
                      
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: '搜索名称/系列...',
                                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onChanged: (query) {
                                    context.read<NovelListBloc>().add(SearchNovels(query: query));
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                _buildFilterButton(
                                  label: '过滤',
                                  icon: Icons.filter_list,
                                  onPressed: () {
                                    // TODO: 显示过滤选项
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterButton(
                                  label: '排序',
                                  icon: Icons.sort,
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('排序功能将在下一个迭代中实现')),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterButton(
                                  label: '分组',
                                  icon: Icons.group_work,
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('分组功能将在下一个迭代中实现')),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isGridView = true;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          color: _isGridView ? Colors.grey.shade200 : Colors.transparent,
                                          child: Icon(
                                            Icons.grid_view,
                                            size: 18,
                                            color: _isGridView ? theme.colorScheme.primary : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isGridView = false;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          color: !_isGridView ? Colors.grey.shade200 : Colors.transparent,
                                          child: Icon(
                                            Icons.view_list,
                                            size: 18,
                                            color: !_isGridView ? theme.colorScheme.primary : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: BlocBuilder<NovelListBloc, NovelListState>(
                            builder: (context, state) {
                              if (state is NovelListInitial) {
                                context.read<NovelListBloc>().add(LoadNovels());
                                return const Center(child: CircularProgressIndicator());
                              } else if (state is NovelListLoading) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (state is NovelListLoaded) {
                                if (state.novels.isEmpty) {
                                  return _buildEmptyState();
                                }
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                      child: Row(
                                        children: [
                                          const Text(
                                            '无系列',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${state.novels.length} 本书',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: _isGridView
                                          ? _buildNovelGrid(state.novels,
                                              contentPadding: const EdgeInsets.all(16))
                                          : _buildNovelListView(state.novels,
                                              contentPadding: const EdgeInsets.all(16)),
                                    ),
                                  ],
                                );
                              } else if (state is NovelListError) {
                                return NovelListErrorView(
                                  message: state.message,
                                  onRetry: () {
                                    context.read<NovelListBloc>().add(LoadNovels());
                                  },
                                );
                              }
                              return const Center(child: CircularProgressIndicator());
                            },
                          ),
                        ),
                      ),
                      
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Build Alpha1',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Released ${DateFormatter.formatDate(DateTime.now())}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            '没有找到小说',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击"创建小说"按钮开始您的写作之旅',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateNovelDialog(),
            icon: const Icon(Icons.add),
            label: const Text('创建小说'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueWritingSection() {
    return BlocBuilder<NovelListBloc, NovelListState>(
      builder: (context, state) {
        if (state is NovelListLoaded && state.novels.isNotEmpty) {
          final recentNovels = List<NovelSummary>.from(state.novels)
            ..sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));

          if (recentNovels.length > 3) {
            recentNovels.removeRange(3, recentNovels.length);
          }

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_note,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '继续写作',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: recentNovels.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemBuilder: (context, index) {
                      final novel = recentNovels[index];
                      return Container(
                        width: 300,
                        margin: const EdgeInsets.only(left: 4, right: 16),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _navigateToEditor(novel),
                            child: Row(
                              children: [
                                Container(
                                  width: 100,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    image: novel.coverImagePath.isNotEmpty
                                        ? DecorationImage(
                                            image: AssetImage(
                                                novel.coverImagePath),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: novel.coverImagePath.isEmpty
                                      ? const Icon(Icons.auto_stories,
                                          size: 40, color: Colors.grey)
                                      : null,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          novel.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '上次编辑于 ${DateFormatter.formatRelative(novel.lastEditTime)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.text_fields,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${novel.wordCount} 字',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        LinearProgressIndicator(
                                          value: novel.completionPercentage,
                                          backgroundColor: Colors.grey.shade200,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        const SizedBox(height: 4),
                                        Flexible(
                                          child: Text(
                                            '完成度: ${(novel.completionPercentage * 100).toInt()}%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildNovelGrid(List<NovelSummary> novels,
      {EdgeInsetsGeometry contentPadding = const EdgeInsets.all(16)}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth * 0.5 - (contentPadding.horizontal / 2);
    final crossAxisCount = (availableWidth / 130).floor().clamp(2, 6);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      padding: contentPadding,
      itemCount: novels.length,
      itemBuilder: (context, index) {
        return NovelCard(
          novel: novels[index],
          onTap: () => _navigateToEditor(novels[index]),
          isGridView: true,
        );
      },
    );
  }

  Widget _buildNovelListView(List<NovelSummary> novels,
      {EdgeInsetsGeometry contentPadding = const EdgeInsets.all(16)}) {
    return ListView.builder(
      itemCount: novels.length,
      padding: contentPadding,
      itemBuilder: (context, index) {
        return NovelCard(
          novel: novels[index],
          onTap: () => _navigateToEditor(novels[index]),
          isGridView: false,
        );
      },
    );
  }

  void _navigateToEditor(NovelSummary novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(novel: novel),
      ),
    );
  }

  void _showCreateNovelDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController seriesController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createNovel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: l10n.novelTitle,
                hintText: l10n.novelTitleHint,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: seriesController,
              decoration: InputDecoration(
                labelText: l10n.seriesName,
                hintText: l10n.seriesNameHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
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
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }
}
