import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor;
import 'package:ainoval/blocs/plan/plan_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor;
import 'package:ainoval/utils/logger.dart';

class PlanView extends StatefulWidget {
  const PlanView({
    super.key,
    required this.novelId,
    required this.planBloc,
    this.onSwitchToWrite,
  });

  final String novelId;
  final PlanBloc planBloc;
  final VoidCallback? onSwitchToWrite;

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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                tooltip: '更多操作',
                offset: const Offset(0, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 3,
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: theme.primaryColor, size: 18),
                        const SizedBox(width: 8),
                        const Text('编辑标题'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditTitleDialog(
                      title: 'Act标题',
                      initialValue: act.title,
                      onSave: (newTitle) {
                        widget.planBloc.add(UpdateActTitle(
                          actId: act.id,
                          title: newTitle,
                        ));
                      },
                    );
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog(
                      title: '删除Act',
                      content: '确定要删除"${act.title}"吗？这将删除其中所有章节和场景。',
                      onConfirm: () {
                        // TODO: 添加删除Act的功能
                        // widget.planBloc.add(DeleteAct(
                        //   novelId: widget.novelId,
                        //   actId: act.id,
                        // ));
                      },
                    );
                  }
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  offset: const Offset(0, 24),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: theme.primaryColor, size: 16),
                          const SizedBox(width: 8),
                          const Text('编辑标题', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditTitleDialog(
                        title: '章节标题',
                        initialValue: chapter.title,
                        onSave: (newTitle) {
                          widget.planBloc.add(UpdateChapterTitle(
                            actId: actId,
                            chapterId: chapter.id,
                            title: newTitle,
                          ));
                        },
                      );
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(
                        title: '删除章节',
                        content: '确定要删除"${chapter.title}"吗？这将删除其中所有场景。',
                        onConfirm: () {
                          // TODO: 添加删除Chapter的功能
                          // widget.planBloc.add(DeleteChapter(
                          //   novelId: widget.novelId,
                          //   actId: actId,
                          //   chapterId: chapter.id,
                          // ));
                        },
                      );
                    }
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
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 0,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // 导航到编辑视图并设置活动场景，而不是显示场景摘要对话框
                final editorBloc = BlocProvider.of<editor.EditorBloc>(context);
                
                // --- 添加日志 ---
                AppLogger.i('PlanView -> onTap', '准备跳转到场景: ActID=$actId, ChapterID=$chapterId, SceneID=${scene.id}');
                
                // 先加载当前章节的场景（确保内容已加载）
                // --- 添加日志 ---
                AppLogger.i('PlanView -> onTap', '分发 LoadMoreScenes 事件: fromChapterId=$chapterId, targetActId=$actId, targetChapterId=$chapterId, targetSceneId=${scene.id}');
                editorBloc.add(editor.LoadMoreScenes(
                  fromChapterId: chapterId,
                  actId: actId,
                  direction: 'center', // 保持 'center'，目标是加载并聚焦
                  chaptersLimit: 5, // 增加加载章节数量，确保加载足够的内容
                  targetChapterId: chapterId,
                  targetSceneId: scene.id
                ));
                
                // 确保场景被设置为活动状态
                Future.delayed(const Duration(milliseconds: 100), () {
                  // 主动设置当前场景为活动场景
                  editorBloc.add(editor.SetActiveScene(
                    actId: actId,
                    chapterId: chapterId,
                    sceneId: scene.id,
                  ));
                  
                  AppLogger.i('PlanView -> onTap', '主动设置活动场景: $actId - $chapterId - ${scene.id}');
                });
                
                // --- 原有日志保持 ---
                AppLogger.i('PlanView', '点击场景准备跳转: $actId - $chapterId - ${scene.id}');

                // 等待场景加载完成后切换视图
                Future.delayed(const Duration(milliseconds: 300), () {
                  // 切换到编辑视图
                  if (widget.onSwitchToWrite != null) {
                    // --- 添加日志 ---
                    AppLogger.i('PlanView -> onTap', '延迟后执行 onSwitchToWrite 回调');
                    widget.onSwitchToWrite!();
                    // --- 原有日志保持 ---
                    AppLogger.i('PlanView', '已切换到写作视图: $actId - $chapterId - ${scene.id}');
                  } else {
                    // --- 添加日志 ---
                    AppLogger.w('PlanView -> onTap', '延迟后发现 onSwitchToWrite 为 null');
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 左侧场景标签
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      margin: const EdgeInsets.only(right: 8.0),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'S$sceneNumber',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    // 中间场景描述
                    Expanded(
                      child: Text(
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
                    ),
                    // 右侧菜单按钮
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz, 
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      offset: const Offset(0, 20),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'edit',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: theme.primaryColor, size: 16),
                              const SizedBox(width: 8),
                              const Text('编辑摘要', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: Colors.red, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showSceneSummaryDialog(actId, chapterId, scene);
                        } else if (value == 'delete') {
                          _showDeleteConfirmDialog(
                            title: '删除场景',
                            content: '确定要删除此场景吗？',
                            onConfirm: () {
                              widget.planBloc.add(DeleteScene(
                                novelId: widget.novelId,
                                actId: actId,
                                chapterId: chapterId,
                                sceneId: scene.id,
                              ));
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建添加场景按钮
  Widget _buildAddSceneButton(String actId, String chapterId, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 0),
      child: TextButton.icon(
        icon: const Icon(Icons.add, size: 14),
        label: const Text('新场景', style: TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: theme.primaryColor,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          minimumSize: const Size(0, 32),
          textStyle: theme.textTheme.labelSmall,
        ),
        onPressed: () {
          // 添加新场景
          widget.planBloc.add(AddNewScene(
            novelId: widget.novelId,
            actId: actId,
            chapterId: chapterId,
          ));
        },
      ),
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

  // 显示删除确认对话框
  void _showDeleteConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 显示编辑标题对话框
  void _showEditTitleDialog({
    required String title,
    required String initialValue,
    required Function(String) onSave,
  }) {
    final TextEditingController controller = TextEditingController(text: initialValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑$title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
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
        title: Text('编辑场景摘要', style: Theme.of(context).textTheme.titleLarge),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '写下这个场景的简要描述',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '输入场景摘要...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
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
} 