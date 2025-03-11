import 'dart:async';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:flutter/material.dart';

class ActSection extends StatefulWidget {

  const ActSection({
    super.key,
    required this.title,
    required this.chapters,
    required this.actId,
    required this.editorBloc,
  });
  final String title;
  final List<Widget> chapters;
  final String actId;
  final EditorBloc editorBloc;

  @override
  State<ActSection> createState() => _ActSectionState();
}

class _ActSectionState extends State<ActSection> {
  late TextEditingController _actTitleController;
  Timer? _actTitleDebounceTimer;

  @override
  void initState() {
    super.initState();
    _actTitleController = TextEditingController(text: widget.title);
  }

  @override
  void didUpdateWidget(ActSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _actTitleController.text = widget.title;
    }
  }

  @override
  void dispose() {
    _actTitleDebounceTimer?.cancel();
    _actTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Act标题 - 居中显示
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 40, 0, 16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 可编辑的文本字段
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _actTitleController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      // 使用防抖动机制，避免频繁更新
                      _actTitleDebounceTimer?.cancel();
                      _actTitleDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          widget.editorBloc.add(UpdateActTitle(
                            actId: widget.actId,
                            title: value,
                          ));
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {},
                  tooltip: 'Actions',
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
        
        // 章节列表
        ...widget.chapters,
        
        // 添加新章节按钮
        _AddChapterButton(
          actId: widget.actId,
          editorBloc: widget.editorBloc,
        ),
        
        // Act分隔线
        const _ActDivider(),
      ],
    );
  }
}

class _AddChapterButton extends StatelessWidget {
  const _AddChapterButton({
    required this.actId,
    required this.editorBloc,
  });
  final String actId;
  final EditorBloc editorBloc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: TextButton.icon(
          onPressed: () {
            // 触发添加新Chapter事件
            editorBloc.add(AddNewChapter(
              novelId: editorBloc.novelId,
              actId: actId,
              title: '新章节',
            ));
          },
          icon: const Icon(Icons.add),
          label: const Text('New Chapter'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _ActDivider extends StatelessWidget {
  const _ActDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      height: 1,
      color: Colors.grey.shade200,
    );
  }
} 