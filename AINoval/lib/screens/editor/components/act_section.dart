import 'dart:async';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/screens/editor/widgets/custom_dropdown.dart';
import 'package:ainoval/screens/editor/widgets/menu_builder.dart';
import 'package:flutter/material.dart';

class ActSection extends StatefulWidget {
  const ActSection({
    super.key,
    required this.title,
    required this.chapters,
    required this.actId,
    required this.editorBloc,
    this.totalChaptersCount,
    this.loadedChaptersCount,
    this.actIndex, // 添加卷序号参数
  });
  final String title;
  final List<Widget> chapters;
  final String actId;
  final EditorBloc editorBloc;
  final int? totalChaptersCount; // 章节总数
  final int? loadedChaptersCount; // 已加载章节数
  final int? actIndex; // 卷序号，从1开始

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

  // 获取卷序号文本
  String _getActIndexText() {
    if (widget.actIndex == null) return '';
    
    // 使用中文数字表示卷序号
    final List<String> chineseNumbers = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    
    if (widget.actIndex! <= 10) {
      return '第${chineseNumbers[widget.actIndex!]}卷 · ';
    } else if (widget.actIndex! < 20) {
      return '第十${chineseNumbers[widget.actIndex! - 10]}卷 · ';
    } else {
      // 对于更大的数字，直接使用阿拉伯数字
      return '第${widget.actIndex}卷 · ';
    }
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 添加卷序号前缀
                        if (widget.actIndex != null)
                          Text(
                            _getActIndexText(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        Expanded(
                          child: Material( // 添加Material组件作为TextField的直接父组件
                            color: Colors.transparent, // 使用透明背景，不改变视觉效果
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // 显示加载状态
                if (widget.totalChaptersCount != null && widget.loadedChaptersCount != null)
                  Tooltip(
                    message: '已加载 ${widget.loadedChaptersCount}/${widget.totalChaptersCount} 章节',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${widget.loadedChaptersCount}/${widget.totalChaptersCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  
                const SizedBox(width: 8),
                // 替换为MenuBuilder
                MenuBuilder.buildActMenu(
                  context: context,
                  editorBloc: widget.editorBloc,
                  actId: widget.actId,
                  onRenamePressed: () {
                    // 聚焦到标题编辑框
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),

        // 显示"没有章节"提示信息（当章节列表为空时）
        if (widget.chapters.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                children: [
                  Icon(Icons.menu_book_outlined, 
                       size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '该Act下还没有章节',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击下方按钮添加新章节',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
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
    final theme = Theme.of(context);
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
          label: const Text('添加新章节'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary, // 使用主题色
            backgroundColor: Colors.white,
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5), // 更粗的边框
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            // 添加阴影
            elevation: 1,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) {
                  return theme.colorScheme.primary.withOpacity(0.1);
                }
                return null;
              },
            ),
          ),
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
