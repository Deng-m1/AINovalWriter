import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/screens/editor/widgets/selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';

/// 场景编辑器组件，用于编辑小说中的单个场景
///
/// [title] 场景标题
/// [wordCount] 场景字数统计
/// [isActive] 当前场景是否处于激活状态
/// [actId] 所属篇章ID
/// [chapterId] 所属章节ID
/// [sceneId] 场景ID
/// [isFirst] 是否为章节中的第一个场景
/// [controller] 场景内容编辑控制器
/// [summaryController] 场景摘要编辑控制器
/// [editorBloc] 编辑器状态管理
class SceneEditor extends StatefulWidget {
  const SceneEditor({
    super.key,
    required this.title,
    required this.wordCount,
    required this.isActive,
    this.actId,
    this.chapterId,
    this.sceneId,
    this.isFirst = true,
    required this.controller,
    required this.summaryController,
    required this.editorBloc,
  });
  final String title;
  final String wordCount;
  final bool isActive;
  final String? actId;
  final String? chapterId;
  final String? sceneId;
  final bool isFirst;
  final QuillController controller;
  final TextEditingController summaryController;
  final EditorBloc editorBloc;

  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isFocused = false;
  // 为编辑器创建一个Key
  late final Key _editorKey;
  // 内容更新防抖定时器
  Timer? _contentDebounceTimer;
  final FocusNode _summaryFocusNode = FocusNode();
  bool _isSummaryFocused = false;

  // 添加文本选择工具栏相关变量
  bool _showToolbar = false;
  final LayerLink _toolbarLayerLink = LayerLink();
  int _selectedTextWordCount = 0;
  Timer? _selectionDebounceTimer;
  bool _showToolbarAbove = true; // 默认在选区上方显示
  Rect _selectionRect = Rect.zero; // 当前选区的位置
  final GlobalKey _editorContentKey = GlobalKey(); // 编辑器内容区域的key

  @override
  void initState() {
    super.initState();
    // 修改初始化Key的方式，确保唯一性
    final String sceneId = widget.sceneId ??
        (widget.actId != null && widget.chapterId != null
            ? '${widget.actId}_${widget.chapterId}'
            : widget.title.replaceAll(' ', '_').toLowerCase());
    // 使用ValueKey代替GlobalObjectKey
    _editorKey = ValueKey('editor_$sceneId');

    // 监听焦点变化
    _focusNode.addListener(_onEditorFocusChange);
    _summaryFocusNode.addListener(_onSummaryFocusChange);

    // 添加控制器内容监听器
    widget.controller.document.changes.listen(_onDocumentChange);

    // 添加文本选择变化监听
    widget.controller.addListener(_handleSelectionChange);
  }

  void _onEditorFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        if (_isFocused && widget.actId != null && widget.chapterId != null) {
          _setActiveElements();
        }
      });
    }
  }

  void _onSummaryFocusChange() {
    if (mounted) {
      setState(() {
        _isSummaryFocused = _summaryFocusNode.hasFocus;
        if (_isSummaryFocused &&
            widget.actId != null &&
            widget.chapterId != null) {
          _setActiveElements();
        }
      });
    }
  }

  void _setActiveElements() {
    if (widget.actId != null && widget.chapterId != null) {
      widget.editorBloc.add(
          SetActiveChapter(actId: widget.actId!, chapterId: widget.chapterId!));
      if (widget.sceneId != null) {
        widget.editorBloc.add(SetActiveScene(
            actId: widget.actId!,
            chapterId: widget.chapterId!,
            sceneId: widget.sceneId!));
      }
    }
  }

  // 监听文档变化
  void _onDocumentChange(DocChange change) {
    if (!mounted) return;

    // 立即计算最新字数，用于显示
    final text = widget.controller.document.toPlainText();
    final currentWordCount = WordCountAnalyzer.countWords(text);

    // 更新当前场景标题旁的字数显示（如果widget有回调方法）
    // 后续可添加回调通知上层组件更新显示

    // 使用防抖动机制，避免频繁发送保存请求
    _contentDebounceTimer?.cancel();
    _contentDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      // 缩短为350毫秒防抖，在打字暂停时快速响应
      _saveContent();
    });
  }

  // 保存内容的方法
  void _saveContent() {
    if (mounted &&
        widget.actId != null &&
        widget.chapterId != null &&
        widget.sceneId != null) {
      try {
        final jsonStr =
            jsonEncode(widget.controller.document.toDelta().toJson());
        // 计算新的字数统计
        final text = widget.controller.document.toPlainText();
        final wordCount = WordCountAnalyzer.countWords(text);

        // 添加日志以便调试
        AppLogger.i(
            'SceneEditor', '保存场景: ${widget.sceneId} 内容已更新, 字数: $wordCount');

        widget.editorBloc.add(UpdateSceneContent(
          novelId: widget.editorBloc.novelId,
          actId: widget.actId!,
          chapterId: widget.chapterId!,
          sceneId: widget.sceneId!,
          content: jsonStr,
          wordCount: wordCount.toString(), // 添加字数统计
          shouldRebuild: true, // 始终为true，确保UI会被更新
        ));
      } catch (e, stackTrace) {
        AppLogger.e(
            'SceneEditor', '更新场景内容失败: ${widget.sceneId}', e, stackTrace);
      }
    }
  }

  // 处理文本选择变化
  void _handleSelectionChange() {
    // 使用防抖动处理选择变化，避免频繁更新
    _selectionDebounceTimer?.cancel();
    _selectionDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      final selection = widget.controller.selection;
      if (selection.isCollapsed) {
        // 如果选择已折叠（没有选中文本），隐藏工具栏
        if (_showToolbar) {
          setState(() {
            _showToolbar = false;
            _selectedTextWordCount = 0;
            _selectionRect = Rect.zero;
          });
        }
      } else {
        // 有文本被选中
        final selectedText = widget.controller.document
            .getPlainText(selection.start, selection.end - selection.start);

        // 计算选中文本的字数
        final wordCount = WordCountAnalyzer.countWords(selectedText);

        // 计算选区矩形位置
        final selectionRect = _calculateSelectionRect();

        // 决定工具栏显示在上方还是下方
        final showAbove = _shouldShowToolbarAbove(selectionRect);

        setState(() {
          _showToolbar = true;
          _selectedTextWordCount = wordCount;
          _selectionRect = selectionRect;
          _showToolbarAbove = showAbove;
        });
      }
    });
  }

  // 计算选区矩形
  Rect _calculateSelectionRect() {
    try {
      // 获取编辑器渲染对象
      final RenderBox? editorBox =
          _editorContentKey.currentContext?.findRenderObject() as RenderBox?;
      if (editorBox == null) {
        AppLogger.w('SceneEditor', '无法获取编辑器渲染对象');
        return Rect.zero;
      }

      // 获取选区的开始和结束位置
      final selection = widget.controller.selection;
      if (selection.isCollapsed) {
        AppLogger.w('SceneEditor', '选区已折叠，无法计算位置');
        return Rect.zero;
      }

      // 使用最新获取的编辑器全局坐标
      final editorOffset = editorBox.localToGlobal(Offset.zero);
      final editorHeight = editorBox.size.height;
      final editorWidth = editorBox.size.width;

      // 创建一个更合理的固定偏移值
      double verticalPosition = editorOffset.dy + 50; // 固定在编辑器顶部下方50像素
      final horizontalPosition = editorWidth * 0.5; // 水平居中

      AppLogger.i('SceneEditor',
          '选区位置计算: editorOffset=$editorOffset, editorWidth=$editorWidth, editorHeight=$editorHeight');

      // 返回一个更易于查看的固定位置
      return Rect.fromLTWH(
        horizontalPosition - 50, // 水平居中，但略微左侧偏移
        verticalPosition,
        100, // 设置一个固定宽度
        30, // 适当高度
      );
    } catch (e, stackTrace) {
      AppLogger.e('SceneEditor', '计算选区矩形失败', e, stackTrace);
      return Rect.zero;
    }
  }

  // 决定工具栏是否显示在选区上方
  bool _shouldShowToolbarAbove(Rect selectionRect) {
    // 默认显示在选区上方 - 但也可以根据位置调整
    // 如果选区在编辑器上半部分，工具栏显示在下方更合适
    return false; // 始终显示在下方，确保可见
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onEditorFocusChange);
    _summaryFocusNode.removeListener(_onSummaryFocusChange);
    _debounceTimer?.cancel();
    _contentDebounceTimer?.cancel(); // 取消内容防抖定时器
    _selectionDebounceTimer?.cancel(); // 取消选择防抖定时器
    widget.controller.removeListener(_handleSelectionChange); // 移除选择变化监听
    _focusNode.dispose();
    _summaryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isEditorOrSummaryFocused = _isFocused || _isSummaryFocused;

    // 2. 卡片设计: 使用 Card Widget
    return Card(
      elevation: isEditorOrSummaryFocused || widget.isActive
          ? 2.0
          : 1.0, // 悬浮感，激活/聚焦时更明显
      // 增加卡片间距，代替之前的 SceneDivider
      margin: EdgeInsets.only(
          bottom: widget.isFirst ? 16.0 : 24.0, top: widget.isFirst ? 0 : 8.0),
      shape: RoundedRectangleBorder(
        // 圆角
        borderRadius: BorderRadius.circular(12.0),
        // 使用 _getCardBorder 获取边框
        side: _getCardBorder(context, isEditorOrSummaryFocused, widget.isActive)
                ?.bottom ??
            BorderSide.none,
      ),
      // 使用 _getCardBackgroundColor 获取背景色
      color: _getCardBackgroundColor(
          context, isEditorOrSummaryFocused, widget.isActive),
      clipBehavior: Clip.antiAlias, // 确保内容在圆角内
      child: InkWell(
        // 添加 InkWell 以便整个卡片可点击并显示水波纹
        onTap: () {
          // 点击整个卡片时，设置活动状态并将焦点赋予编辑器
          _setActiveElements();
          if (mounted && _focusNode.canRequestFocus) {
            _focusNode.requestFocus();
          }
        },
        hoverColor: Colors.grey.shade50.withOpacity(0.5), // 添加悬停效果
        child: Padding(
          padding: const EdgeInsets.all(16.0), // 卡片内部统一内边距
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 场景标题和字数统计 (移到卡片内部)
              _buildSceneHeader(
                  theme, isEditorOrSummaryFocused), // 传入 theme 和焦点状态
              const SizedBox(height: 12), // 增加标题和内容间距

              // 编辑器和摘要区域并排显示
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 编辑器区域
                  Expanded(
                    flex: 7,
                    child: Stack(
                      children: [
                        // 编辑器
                        CompositedTransformTarget(
                          link: _toolbarLayerLink,
                          child: _buildEditor(theme, isEditorOrSummaryFocused),
                        ),
                        // 文本选择工具栏
                        if (_showToolbar)
                          Positioned(
                            child: SelectionToolbar(
                              controller: widget.controller,
                              layerLink: _toolbarLayerLink,
                              wordCount: _selectedTextWordCount,
                              editorSize: _editorContentKey.currentContext
                                      ?.findRenderObject() is RenderBox
                                  ? (_editorContentKey.currentContext!
                                          .findRenderObject() as RenderBox)
                                      .size
                                  : const Size(300, 150),
                              selectionRect: _selectionRect,
                              showAbove: _showToolbarAbove,
                              onClosed: () {
                                setState(() {
                                  _showToolbar = false;
                                });
                              },
                              onFormatChanged: () {
                                // 格式变更时可能需要更新选择状态
                                _handleSelectionChange();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // 编辑器和摘要之间的间距
                  // 摘要区域
                  Expanded(
                    flex: 3,
                    child: _buildSummaryArea(theme, isEditorOrSummaryFocused),
                  ),
                ],
              ),

              const SizedBox(height: 16), // 内容和底部按钮间距
              // 底部操作按钮 (整合后)
              _buildBottomActions(theme), // 传入 theme
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSceneHeader(ThemeData theme, bool isFocused) {
    return Padding(
      // 移除底部 padding，由 SizedBox 控制
      padding: const EdgeInsets.only(bottom: 0.0),
      child: Row(
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isFocused || widget.isActive
                  ? theme.colorScheme.primary
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (widget.wordCount.isNotEmpty)
            Text(
              widget.wordCount,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor(ThemeData theme, bool isFocused) {
    // 使用 key 以便获取编辑器尺寸
    return Container(
      key: _editorContentKey,
      child: QuillEditor.basic(
        key: _editorKey, // 传递 key
        controller: widget.controller,
        focusNode: _focusNode, // 使用编辑器的 FocusNode
        scrollController: ScrollController(), // 每个编辑器独立的滚动控制器
        config: const QuillEditorConfig(
          // 移除背景色和边框，让 Card 控制
          // decoration: BoxDecoration(...)
          minHeight: 150, // 增加最小高度
          placeholder: '开始写作...',
          padding:
              EdgeInsets.symmetric(vertical: 8, horizontal: 4), // 调整内部填充
          enableInteractiveSelection: true, // 确保启用文本选择交互
          scrollable: true, // 确保可滚动
          showCursor: true, 
          autoFocus: false, // 禁用自动聚焦以减少不必要的渲染
          expands: false, // 不自动扩展，保持控制
          customStyles: DefaultStyles(
            // 确保样式配置正确
            bold: TextStyle(fontWeight: FontWeight.bold),
            italic: TextStyle(fontStyle: FontStyle.italic),
            underline: TextStyle(decoration: TextDecoration.underline),
            strikeThrough:
                TextStyle(decoration: TextDecoration.lineThrough),
            // 移除不支持的自定义样式
            link: TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  // 新增：处理编辑器点击事件，更精确定位选区
  void _onQuillEditorTapDown(TapDownDetails details,
      TextPosition Function(Offset) getPositionForOffset) {
    AppLogger.i('SceneEditor', '编辑器点击事件: ${details.globalPosition}');
    try {
      if (_showToolbar && !widget.controller.selection.isCollapsed) {
        // 更新选区位置计算
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final selectionRect = _calculateSelectionRect();
            if (selectionRect != Rect.zero) {
              setState(() {
                _selectionRect = selectionRect;
              });
            }
          }
        });
      }
    } catch (e, stackTrace) {
      AppLogger.e('SceneEditor', '处理编辑器点击事件失败', e, stackTrace);
    }
  }

  Widget _buildSummaryArea(ThemeData theme, bool isFocused) {
    // Container 用于添加内边距和可能的背景/边框（如果需要与卡片区分）
    return Container(
      // 移除 margin，由 Row 的 SizedBox 控制
      padding: const EdgeInsets.all(12), // 调整摘要区内边距
      decoration: BoxDecoration(
        color: isFocused || widget.isActive
            ? Colors.grey.shade50.withOpacity(0.7) // 摘要区激活/聚焦时稍微区别于卡片背景
            : Colors.transparent, // 默认透明或使用 theme.cardColor 的细微变体
        borderRadius: BorderRadius.circular(8), // 给摘要区本身加圆角
        // 可以添加可选的细边框
        // border: Border.all(
        //   color: Colors.grey.shade200,
        //   width: 0.5,
        // ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 摘要标题和右上角按钮
          Row(
            children: [
              Expanded(
                child: Text(
                  '摘要',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isFocused || widget.isActive
                        ? theme.colorScheme.primary
                        : Colors.grey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 摘要操作按钮（刷新、AI生成） - 移到右上角
              _buildSummaryActionButtons(theme, isFocused),
            ],
          ),

          const SizedBox(height: 8),

          // 摘要内容
          TextField(
            controller: widget.summaryController,
            focusNode: _summaryFocusNode,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: '添加场景摘要...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
            onChanged: (value) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                if (mounted &&
                    widget.actId != null &&
                    widget.chapterId != null &&
                    widget.sceneId != null) {
                  widget.editorBloc.add(UpdateSummary(
                    novelId: widget.editorBloc.novelId,
                    actId: widget.actId!,
                    chapterId: widget.chapterId!,
                    sceneId: widget.sceneId!,
                    summary: value,
                    shouldRebuild: false,
                  ));
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // 新增：摘要区域右上角的操作按钮
  Widget _buildSummaryActionButtons(ThemeData theme, bool isFocused) {
    // 使用 Row + IconButton 实现
    return Row(
      mainAxisSize: MainAxisSize.min, // 重要：避免 Row 占用过多空间
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: '刷新摘要',
          onPressed: () {
            // 实现刷新摘要逻辑
            if (widget.summaryController.text.isNotEmpty &&
                widget.actId != null &&
                widget.chapterId != null &&
                widget.sceneId != null) {
              widget.editorBloc.add(UpdateSummary(
                novelId: widget.editorBloc.novelId,
                actId: widget.actId!,
                chapterId: widget.chapterId!,
                sceneId: widget.sceneId!,
                summary: widget.summaryController.text,
                shouldRebuild: false,
              ));
            }
          },
          color: Colors.grey.shade600,
          splashRadius: 18,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          // 添加悬停效果
          hoverColor: theme.primaryColor.withOpacity(0.1),
        ),
        IconButton(
          icon: const Icon(Icons.auto_awesome, size: 18),
          tooltip: 'AI 生成摘要',
          onPressed: () {
            // 实现 AI 生成摘要逻辑
            if (widget.actId != null && 
                widget.chapterId != null && 
                widget.sceneId != null) {
              // 触发生成摘要事件
              widget.editorBloc.add(
                GenerateSceneSummaryRequested(
                  sceneId: widget.sceneId!,
                ),
              );
            }
          },
          color: Colors.grey.shade600,
          splashRadius: 18,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          // 添加悬停效果
          hoverColor: theme.primaryColor.withOpacity(0.1),
        ),
      ],
    );
  }

  // 整合底部按钮
  Widget _buildBottomActions(ThemeData theme) {
    // 使用 Row 和 PopupMenuButton
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 使用 TextButton 或 OutlinedButton 提供视觉反馈
        _ActionButton(
          icon: Icons.label_outline,
          label: '标签',
          tooltip: '添加标签 (Placeholder)',
          onPressed: () {/* TODO */},
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.lan_outlined,
          label: 'Codex',
          tooltip: '关联 Codex (Placeholder)',
          onPressed: () {/* TODO */},
        ),
        const SizedBox(width: 8),
        // 更多操作按钮
        PopupMenuButton<String>(
          onSelected: (String result) {
            // TODO: 处理菜单项点击
            switch (result) {
              case 'delete':
                // 触发删除事件
                if (widget.actId != null &&
                    widget.chapterId != null &&
                    widget.sceneId != null) {
                  widget.editorBloc.add(DeleteScene(
                      novelId: widget.editorBloc.novelId,
                      actId: widget.actId!,
                      chapterId: widget.chapterId!,
                      sceneId: widget.sceneId!));
                }
                break;
              case 'duplicate':
                // TODO: 处理复制场景
                break;
              // 添加其他操作...
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'duplicate',
              child: ListTile(
                  leading: Icon(Icons.copy_outlined, size: 18),
                  title: Text('复制场景', style: TextStyle(fontSize: 14))),
            ),
            const PopupMenuItem<String>(
              value: 'split',
              child: ListTile(
                  leading: Icon(Icons.splitscreen_outlined, size: 18),
                  title: Text('拆分场景', style: TextStyle(fontSize: 14))),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                  leading: Icon(Icons.delete_outline,
                      size: 18, color: Colors.red.shade700),
                  title: Text('删除场景',
                      style:
                          TextStyle(fontSize: 14, color: Colors.red.shade700))),
            ),
          ],
          // 使用 IconButton 作为子项，更符合 UI 习惯
          icon: const Icon(Icons.more_horiz, size: 20),
          tooltip: '更多操作',
          color: Colors.grey.shade600,
          splashRadius: 20,
          offset: const Offset(0, 30),
        ),
      ],
    );
  }

  // Helper to determine card background color based on state
  Color _getCardBackgroundColor(
      BuildContext context, bool isFocused, bool isActive) {
    if (isFocused) return Colors.white;
    if (isActive) return Colors.grey.shade50;
    return Colors.white;
  }

  // Helper to determine card border based on state
  Border? _getCardBorder(BuildContext context, bool isFocused, bool isActive) {
    final theme = Theme.of(context);
    if (isFocused) {
      return Border.all(color: theme.primaryColor.withOpacity(0.5), width: 1.5);
    }
    return Border.all(color: Colors.grey.shade200, width: 1.0);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.tooltip,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // 使用 TextButton 提供更柔和的外观
    return Tooltip(
      message: tooltip ?? label,
      child: TextButton.icon(
        onPressed: onPressed ?? () {},
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ).copyWith(overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.hovered)) {
              return Colors.grey.shade200;
            }
            return null;
          },
        )),
      ),
    );
  }
}
