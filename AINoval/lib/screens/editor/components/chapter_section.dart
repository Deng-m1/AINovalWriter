import 'dart:async';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/components/editable_title.dart';
import 'package:ainoval/utils/debouncer.dart' as debouncer;
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';

class ChapterSection extends StatefulWidget {
  const ChapterSection({
    super.key,
    required this.title,
    required this.scenes,
    required this.actId,
    required this.chapterId,
    required this.editorBloc,
  });
  final String title;
  final List<Widget> scenes;
  final String actId;
  final String chapterId;
  final EditorBloc editorBloc;

  @override
  State<ChapterSection> createState() => _ChapterSectionState();
}

class _ChapterSectionState extends State<ChapterSection> {
  late TextEditingController _chapterTitleController;
  late debouncer.Debouncer _debouncer;
  // 为章节创建一个ValueKey，确保唯一性
  late final Key _chapterKey =
      ValueKey('chapter_${widget.actId}_${widget.chapterId}');

  @override
  void initState() {
    super.initState();
    _chapterTitleController = TextEditingController(text: widget.title);
    _debouncer = debouncer.Debouncer();
  }

  @override
  void didUpdateWidget(ChapterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _chapterTitleController.text = widget.title;
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _chapterTitleController.dispose();
    super.dispose();
  }

  void _loadScenes() {
    // 触发加载当前章节的场景
    widget.editorBloc.add(LoadMoreScenes(
      fromChapterId: widget.chapterId,
      direction: 'center', // 指定为中心加载
      chaptersLimit: 1, // 只加载当前章节
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: _chapterKey, // 使用ValueKey
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chapter标题
        Padding(
          // 调整间距
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24), // 调整上下间距
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
            children: [
              // 可编辑的文本字段
              Expanded(
                child: EditableTitle(
                  // 保持 EditableTitle
                  initialText: widget.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    // 使用主题标题样式
                    fontWeight: FontWeight.w600, // 加粗
                    color: Colors.black,
                  ),
                  onChanged: (value) {
                    // 使用防抖更新
                    _debouncer.run(() {
                      if (mounted) {
                        widget.editorBloc.add(UpdateChapterTitle(
                          actId: widget.actId,
                          chapterId: widget.chapterId,
                          title: value,
                        ));
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8), // 增加间距
              
              // 如果场景为空，显示加载按钮
              if (widget.scenes.isEmpty)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadScenes,
                  tooltip: '加载场景',
                  color: Colors.grey.shade600,
                  splashRadius: 20,
                ),
                
              // 更多操作按钮 (PopupMenuButton 待实现)
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: () {
                  // 显示章节操作菜单
                  _showChapterMenu(context);
                },
                tooltip: 'Chapter Actions',
                color: Colors.grey.shade600,
                splashRadius: 20,
              ),
            ],
          ),
        ),

        // 场景列表
        // 通过 Column 自动排列，间距由 SceneEditor 的 margin 控制
        if (widget.scenes.isEmpty)
          // 显示加载场景的引导
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Center(
              child: Column(
                children: [
                  Text(
                    '章节 "${widget.title}" 还没有加载场景。',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadScenes,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('加载场景'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(children: widget.scenes),

        // 添加新场景按钮
        if (widget.scenes.isNotEmpty) // 只有当已经有场景时才显示添加按钮
          _AddSceneButton(
            actId: widget.actId,
            chapterId: widget.chapterId,
            editorBloc: widget.editorBloc,
          ),
      ],
    );
  }
  
  // 显示章节操作菜单
  void _showChapterMenu(BuildContext context) {
    final theme = Theme.of(context);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(100, 100, 0, 0), // 这个位置会根据点击位置自动调整
      items: [
        if (widget.scenes.isEmpty)
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('加载场景'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () {
                Navigator.pop(context);
                _loadScenes();
              },
            ),
          ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.add),
            title: const Text('添加新场景'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () {
              Navigator.pop(context);
              // 触发添加新Scene事件
              final newSceneId = DateTime.now().millisecondsSinceEpoch.toString();
              widget.editorBloc.add(AddNewScene(
                novelId: widget.editorBloc.novelId,
                actId: widget.actId,
                chapterId: widget.chapterId,
                sceneId: newSceneId,
              ));
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('重命名章节'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () {
              Navigator.pop(context);
              // 聚焦到标题编辑框
              // 通过setState强制刷新使标题进入编辑状态
              setState(() {});
            },
          ),
        ),
        // 后面可以添加更多选项如删除等
      ],
    );
  }
}

class _AddSceneButton extends StatelessWidget {
  const _AddSceneButton({
    required this.actId,
    required this.chapterId,
    required this.editorBloc,
  });
  final String actId;
  final String chapterId;
  final EditorBloc editorBloc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0), // 调整间距
        child: OutlinedButton.icon(
          // 改为 OutlinedButton
          onPressed: () {
            // 生成不带前缀的纯数字ID，以确保与后端一致
            final newSceneId = DateTime.now().millisecondsSinceEpoch.toString();
            AppLogger.i('Editor',
                '添加新Scene按钮被点击: actId=$actId, chapterId=$chapterId, sceneId=$newSceneId');

            // 触发添加新Scene事件
            editorBloc.add(AddNewScene(
              novelId: editorBloc.novelId,
              actId: actId,
              chapterId: chapterId,
              sceneId: newSceneId,
            ));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Scene'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ).copyWith(overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.hovered)) {
                return Colors.grey.shade100;
              }
              return null;
            },
          )),
        ),
      ),
    );
  }
}
