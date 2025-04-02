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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Act标题 - 居中显示
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 可编辑的文本字段
                IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextField(
                      controller: _actTitleController,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        isDense: true,
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        // 使用防抖动机制，避免频繁更新
                        _actTitleDebounceTimer?.cancel();
                        _actTitleDebounceTimer =
                            Timer(const Duration(milliseconds: 500), () {
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
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {
                    // TODO: 实现 Act 的更多操作菜单（如重命名、删除等）
                  },
                  tooltip: 'Act Actions',
                  color: Colors.grey.shade600,
                  splashRadius: 20,
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
        // const _ActDivider(),
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
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: OutlinedButton.icon(
          onPressed: () {
            // 触发添加新Chapter事件
            editorBloc.add(AddNewChapter(
              novelId: editorBloc.novelId,
              actId: actId,
              title: '新章节 ${DateTime.now().millisecondsSinceEpoch % 100}',
            ));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Chapter'),
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

// 可以保留或移除 _ActDivider
// class _ActDivider extends StatelessWidget {
//   const _ActDivider();
//   @override
//   Widget build(BuildContext context) {
//     return Divider(
//       height: 80,
//       thickness: 1,
//       color: Colors.grey.shade200,
//       indent: 40,
//       endIndent: 40,
//     );
//   }
// }
