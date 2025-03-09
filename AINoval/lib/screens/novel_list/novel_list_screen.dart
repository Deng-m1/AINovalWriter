import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/repositories/novel_repository.dart';
import 'package:ainoval/screens/editor/editor_screen.dart';
import 'package:ainoval/screens/novel_list/widgets/novel_card.dart';
import 'package:ainoval/screens/novel_list/widgets/novel_list_error_view.dart';
import 'package:ainoval/utils/date_formatter.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
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
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.book, size: 40),
            const SizedBox(width: 10),
            Text(l10n.homeTitle),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // TODO: 显示帮助信息
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              '你的小说',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '这是你的个人小说库，你想今天写哪一部？',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          
          // 最近编辑区域
          _buildContinueWritingSection(),
          
          // 搜索和过滤栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索名称/系列...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (query) {
                      context.read<NovelListBloc>().add(SearchNovels(query: query));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                
                // 过滤按钮
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    // TODO: 显示过滤选项
                  },
                ),
                
                // 排序按钮
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () {
                    // 简化为仅显示提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('排序功能将在下一个迭代中实现')),
                    );
                  },
                ),
                
                // 分组按钮
                IconButton(
                  icon: const Icon(Icons.group_work),
                  onPressed: () {
                    // 简化为仅显示提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('分组功能将在下一个迭代中实现')),
                    );
                  },
                ),
                
                // 视图切换按钮
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // 小说列表
          Expanded(
            child: BlocBuilder<NovelListBloc, NovelListState>(
              builder: (context, state) {
                if (state is NovelListInitial) {
                  // 触发加载小说列表事件
                  context.read<NovelListBloc>().add(LoadNovels());
                  return const Center(child: CircularProgressIndicator());
                } else if (state is NovelListLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is NovelListLoaded) {
                  if (state.novels.isEmpty) {
                    return const Center(
                      child: Text('没有找到小说，创建一部新的吧！'),
                    );
                  }
                  
                  // 简化为不分组显示
                  return _isGridView
                      ? _buildNovelGrid(state.novels)
                      : _buildNovelListView(state.novels);
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
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 导入按钮
          FloatingActionButton.extended(
            heroTag: 'import',
            onPressed: () {
              // TODO: 导入小说
            },
            label: const Text('导入'),
            icon: const Icon(Icons.file_upload),
          ),
          const SizedBox(width: 16),
          
          // 创建按钮
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => _showCreateNovelDialog(),
            label: const Text('创建小说'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
  
  // 继续写作区域
  Widget _buildContinueWritingSection() {
    return BlocBuilder<NovelListBloc, NovelListState>(
      builder: (context, state) {
        if (state is NovelListLoaded && state.novels.isNotEmpty) {
          // 获取最近编辑的3部小说
          final recentNovels = List<NovelSummary>.from(state.novels)
            ..sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));
          
          if (recentNovels.length > 3) {
            recentNovels.removeRange(3, recentNovels.length);
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '继续写作',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentNovels.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final novel = recentNovels[index];
                    return Card(
                      margin: const EdgeInsets.only(right: 16),
                      child: InkWell(
                        onTap: () => _navigateToEditor(novel),
                        child: Container(
                          width: 250,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(4),
                                  image: novel.coverImagePath.isNotEmpty
                                      ? DecorationImage(
                                          image: AssetImage(novel.coverImagePath),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: novel.coverImagePath.isEmpty
                                    ? const Icon(Icons.book, size: 30)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      novel.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '上次编辑于 ${DateFormatter.formatRelative(novel.lastEditTime)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${novel.wordCount} 字',
                                      style: TextStyle(
                                        fontSize: 12,
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
                    );
                  },
                ),
              ),
            ],
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
  
  // 构建网格视图
  Widget _buildNovelGrid(List<NovelSummary> novels, {Axis scrollDirection = Axis.vertical}) {
    if (scrollDirection == Axis.horizontal) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: novels.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 150,
            child: NovelCard(
              novel: novels[index],
              onTap: () => _navigateToEditor(novels[index]),
              isGridView: true,
            ),
          );
        },
      );
    }
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      padding: const EdgeInsets.all(16),
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
  
  // 构建列表视图
  Widget _buildNovelListView(List<NovelSummary> novels) {
    return ListView.builder(
      itemCount: novels.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return NovelCard(
          novel: novels[index],
          onTap: () => _navigateToEditor(novels[index]),
          isGridView: false,
        );
      },
    );
  }
  
  // 导航到编辑器
  void _navigateToEditor(NovelSummary novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(novel: novel),
      ),
    );
  }
  
  // 创建新小说对话框
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
                
                // 使用BlocProvider提供的NovelListBloc来创建小说
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