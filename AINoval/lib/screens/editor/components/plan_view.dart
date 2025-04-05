import 'package:ainoval/blocs/plan/plan_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlanView extends StatefulWidget {
  const PlanView({
    super.key,
    required this.novelId,
    required this.planBloc,
  });

  final String novelId;
  final PlanBloc planBloc;

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 加载Plan视图数据
    widget.planBloc.add(const LoadPlanContent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<PlanBloc, PlanState>(
      bloc: widget.planBloc,
      builder: (context, state) {
        if (state is PlanLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state is PlanError) {
          return Center(
            child: Text('加载失败: ${state.message}'),
          );
        }

        if (state is PlanLoaded) {
          return Container(
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 主要内容区
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...state.novel.acts.map((act) => _buildActSection(act, theme)),
                          _buildAddActButton(theme),
                        ],
                      ),
                    ),
                  ),
                ),
                // 底部工具栏
                _buildBottomToolbar(theme),
              ],
            ),
          );
        }

        return const Center(
          child: Text('暂无内容'),
        );
      },
    );
  }

  // 构建Act部分
  Widget _buildActSection(novel_models.Act act, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Act标题行
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_drop_down),
                onPressed: () {
                  // 实现折叠/展开功能
                },
              ),
              Text(
                act.title,
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '添加章节',
                onPressed: () {
                  // 添加新章节
                  widget.planBloc.add(AddNewChapter(
                    novelId: widget.novelId,
                    actId: act.id,
                  ));
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: '更多操作',
                onPressed: () {
                  // 显示更多操作菜单
                },
              ),
            ],
          ),
          // Chapters区域 - 使用Wrap替代ListView以支持自动换行
          Container(
            padding: const EdgeInsets.only(left: 32.0),
            child: Wrap(
              spacing: 16.0, // 水平间距
              runSpacing: 16.0, // 垂直间距
              children: [
                ...act.chapters.map((chapter) => SizedBox(
                  width: 280,
                  height: 320,
                  child: _buildChapterCard(act.id, chapter, theme),
                )),
                SizedBox(
                  width: 280,
                  height: 320,
                  child: _buildAddChapterCard(act.id, theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建Chapter卡片
  Widget _buildChapterCard(String actId, novel_models.Chapter chapter, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter标题
            Row(
              children: [
                Expanded(
                  child: Text(
                    chapter.title,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // 显示章节操作菜单
                  },
                ),
              ],
            ),
            const Divider(),
            // Scenes列表
            Expanded(
              child: ListView.builder(
                itemCount: chapter.scenes.length + 1, // +1 for the add button
                itemBuilder: (context, index) {
                  if (index == chapter.scenes.length) {
                    // 添加新场景按钮
                    return _buildAddSceneButton(actId, chapter.id, theme);
                  }
                  return _buildSceneItem(
                    actId, 
                    chapter.id, 
                    chapter.scenes[index], 
                    index + 1,
                    theme
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建Scene项
  Widget _buildSceneItem(
    String actId, 
    String chapterId, 
    novel_models.Scene scene, 
    int sceneNumber,
    ThemeData theme
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ListTile(
          dense: true,
          title: Row(
            children: [
              Text(
                'Scene $sceneNumber',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    child: const Icon(Icons.edit, size: 16),
                    onTap: () {
                      // 编辑场景
                    },
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    child: const Icon(Icons.more_horiz, size: 16),
                    onTap: () {
                      // 更多操作
                    },
                  ),
                ],
              ),
            ],
          ),
          subtitle: Text(
            scene.summary.content.isNotEmpty
                ? scene.summary.content
                : '点击添加场景描述...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scene.summary.content.isNotEmpty
                  ? Colors.black87
                  : Colors.grey,
              fontStyle: scene.summary.content.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            // 显示场景摘要编辑对话框
            _showSceneSummaryDialog(actId, chapterId, scene);
          },
        ),
      ),
    );
  }

  // 显示场景摘要编辑对话框
  void _showSceneSummaryDialog(
    String actId,
    String chapterId,
    novel_models.Scene scene,
  ) {
    final TextEditingController controller = 
        TextEditingController(text: scene.summary.content);
        
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑场景摘要'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入场景摘要...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 保存场景摘要
              widget.planBloc.add(UpdateSceneSummary(
                novelId: widget.novelId,
                actId: actId,
                chapterId: chapterId,
                sceneId: scene.id,
                summary: controller.text,
              ));
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 构建添加场景按钮
  Widget _buildAddSceneButton(String actId, String chapterId, ThemeData theme) {
    return TextButton.icon(
      icon: const Icon(Icons.add, size: 16),
      label: const Text('新场景'),
      style: TextButton.styleFrom(
        foregroundColor: theme.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        textStyle: theme.textTheme.labelMedium,
      ),
      onPressed: () {
        // 添加新场景
        widget.planBloc.add(AddNewScene(
          novelId: widget.novelId,
          actId: actId,
          chapterId: chapterId,
        ));
      },
    );
  }

  // 构建添加章节卡片
  Widget _buildAddChapterCard(String actId, ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: InkWell(
        onTap: () {
          // 添加新章节
          widget.planBloc.add(AddNewChapter(
            novelId: widget.novelId,
            actId: actId,
          ));
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 32,
                color: theme.primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                '新章节',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建添加Act按钮
  Widget _buildAddActButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('添加新Act'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        ),
        onPressed: () {
          // 添加新Act
          widget.planBloc.add(const AddNewAct());
        },
      ),
    );
  }

  // 构建底部工具栏
  Widget _buildBottomToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            icon: const Icon(Icons.add_box),
            label: const Text('添加Act'),
            onPressed: () {
              // 添加新Act
              widget.planBloc.add(const AddNewAct());
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.format_list_numbered),
            label: const Text('大纲设置'),
            onPressed: () {
              // 实现大纲设置功能
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.filter_alt),
            label: const Text('筛选'),
            onPressed: () {
              // 实现筛选功能
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('选项'),
            onPressed: () {
              // 实现选项功能
            },
          ),
        ],
      ),
    );
  }
} 