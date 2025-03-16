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
  late final Key _chapterKey = ValueKey('chapter_${widget.actId}_${widget.chapterId}');

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _chapterKey, // 使用ValueKey
      onTap: () {
        // 点击Chapter时设置为活动Chapter
        AppLogger.i('Editor', 'Chapter被点击: actId=${widget.actId}, chapterId=${widget.chapterId}');
        // 不检查当前状态，直接触发事件
        widget.editorBloc.add(SetActiveChapter(
          actId: widget.actId,
          chapterId: widget.chapterId,
        ));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter标题
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 40, 0, 16),
            child: Row(
              children: [
                // 可编辑的文本字段
                Expanded(
                  child: EditableTitle(
                    initialText: widget.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    onChanged: (value) {
                      try {
                        widget.editorBloc.add(UpdateChapterTitle(
                          actId: widget.actId,
                          chapterId: widget.chapterId,
                          title: value,
                        ));
                      } catch (e) {
                        AppLogger.e('ChapterSection', '更新章节标题失败', e);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {},
                  tooltip: 'Actions',
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),

          // 场景列表
          ...widget.scenes,

          // 添加新场景按钮
          _AddSceneButton(
            actId: widget.actId,
            chapterId: widget.chapterId,
            editorBloc: widget.editorBloc,
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: TextButton.icon(
          onPressed: () {
            // 生成不带前缀的纯数字ID，以确保与后端一致
            final newSceneId = DateTime.now().millisecondsSinceEpoch.toString();
            AppLogger.i('Editor', '添加新Scene按钮被点击: actId=$actId, chapterId=$chapterId, sceneId=$newSceneId');
            
            // 先设置活动章节，确保状态正确
            editorBloc.add(SetActiveChapter(
              actId: actId,
              chapterId: chapterId
            ));
            
            // 延迟一帧后再添加场景，确保活动章节状态已更新
            Future.microtask(() {
              // 触发添加新Scene事件
              editorBloc.add(AddNewScene(
                novelId: editorBloc.novelId,
                actId: actId,
                chapterId: chapterId,
                sceneId: newSceneId,
              ));
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('New Scene'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
} 