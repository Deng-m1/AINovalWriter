import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';

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
  Timer? _chapterTitleDebounceTimer;

  @override
  void initState() {
    super.initState();
    _chapterTitleController = TextEditingController(text: widget.title);
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
    _chapterTitleDebounceTimer?.cancel();
    _chapterTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击Chapter时设置为活动Chapter
        print('Chapter被点击: actId=${widget.actId}, chapterId=${widget.chapterId}');
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
                  child: TextField(
                    controller: _chapterTitleController,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      // 使用防抖动机制，避免频繁更新
                      _chapterTitleDebounceTimer?.cancel();
                      _chapterTitleDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          widget.editorBloc.add(UpdateChapterTitle(
                            actId: widget.actId,
                            chapterId: widget.chapterId,
                            title: value,
                          ));
                        }
                      });
                    },
                    onTap: () {
                      // 防止点击文本框时触发GestureDetector的onTap
                      // 但仍然设置为活动Chapter
                      widget.editorBloc.add(SetActiveChapter(
                        actId: widget.actId,
                        chapterId: widget.chapterId,
                      ));
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
            print('添加新Scene按钮被点击: actId=$actId, chapterId=$chapterId');
            // 触发添加新Scene事件
            editorBloc.add(AddNewScene(
              novelId: editorBloc.novelId,
              actId: actId,
              chapterId: chapterId,
              sceneId: 'scene_${DateTime.now().millisecondsSinceEpoch}', // 生成临时的sceneId
            ));
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