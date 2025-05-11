import 'dart:async';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/components/editable_title.dart';
import 'package:ainoval/utils/debouncer.dart' as debouncer;
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/screens/editor/widgets/custom_dropdown.dart';
import 'package:ainoval/screens/editor/widgets/menu_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class ChapterSection extends StatefulWidget {
  const ChapterSection({
    super.key,
    required this.title,
    required this.scenes,
    required this.actId,
    required this.chapterId,
    required this.editorBloc,
    this.chapterIndex, // 添加章节序号参数
  });
  final String title;
  final List<Widget> scenes;
  final String actId;
  final String chapterId;
  final EditorBloc editorBloc;
  final int? chapterIndex; // 章节在卷中的序号，从1开始

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
    
    // 更新标题控制器
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

  // 获取章节序号文本
  String _getChapterIndexText() {
    if (widget.chapterIndex == null) return '';
    
    // 使用中文数字表示章节序号
    final List<String> chineseNumbers = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    
    if (widget.chapterIndex! <= 10) {
      return '第${chineseNumbers[widget.chapterIndex!]}章 · ';
    } else if (widget.chapterIndex! < 20) {
      return '第十${chineseNumbers[widget.chapterIndex! - 10]}章 · ';
    } else {
      // 对于更大的数字，直接使用阿拉伯数字
      return '第${widget.chapterIndex}章 · ';
    }
  }

  // 手动触发加载场景的方法
  void _loadScenes() {
    AppLogger.i('ChapterSection', '手动触发加载章节场景: ${widget.actId} - ${widget.chapterId}');
    
    try {
      final controller = Provider.of<EditorScreenController>(context, listen: false);
      controller.loadScenesForChapter(widget.actId, widget.chapterId);
    } catch (e) {
      // 如果无法获取控制器，直接使用EditorBloc
      widget.editorBloc.add(LoadMoreScenes(
        fromChapterId: widget.chapterId,
        direction: 'center',
        actId: widget.actId,
        chaptersLimit: 2,
        preventFocusChange: true,
      ));
    }
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
              // 添加章节序号前缀
              if (widget.chapterIndex != null)
                Text(
                  _getChapterIndexText(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
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
              
              // 替换为MenuBuilder
              MenuBuilder.buildChapterMenu(
                context: context,
                editorBloc: widget.editorBloc,
                actId: widget.actId,
                chapterId: widget.chapterId,
                onRenamePressed: () {
                  // 聚焦到标题编辑框
                  // 通过setState强制刷新使标题进入编辑状态
                  setState(() {});
                },
              ),
            ],
          ),
        ),

        // 场景列表
        if (widget.scenes.isEmpty)
          // 显示空章节的UI，提供手动加载按钮
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.article_outlined, 
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '章节 "${widget.title}" 暂无场景内容',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请手动加载或创建场景',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 加载场景按钮
                      OutlinedButton.icon(
                        onPressed: _loadScenes,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('加载场景'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 创建新场景按钮
                      ElevatedButton.icon(
                        onPressed: _addNewScene,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('创建新场景'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
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

  // 添加一个创建新场景的方法
  void _addNewScene() {
    final newSceneId = DateTime.now().millisecondsSinceEpoch.toString();
    AppLogger.i('ChapterSection', '添加新场景：actId=${widget.actId}, chapterId=${widget.chapterId}, sceneId=$newSceneId');
    
    widget.editorBloc.add(AddNewScene(
      novelId: widget.editorBloc.novelId,
      actId: widget.actId,
      chapterId: widget.chapterId,
      sceneId: newSceneId,
    ));
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
          ).copyWith(overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.hovered)) {
                return Colors.grey.shade200;
              }
              return null;
            },
          )),
        ),
      ),
    );
  }
}
