import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:ainoval/utils/logger.dart';

/// 文本选中上下文工具栏
///
/// 当用户在编辑器中选中文本时显示的浮动工具栏，提供格式化和自定义操作按钮
class SelectionToolbar extends StatefulWidget {
  /// 创建一个选中工具栏
  ///
  /// [controller] 富文本编辑器控制器
  /// [layerLink] 用于定位工具栏的层链接
  /// [onClosed] 工具栏关闭时的回调
  /// [onFormatChanged] 格式变更时的回调
  /// [wordCount] 选中文本的字数
  /// [showAbove] 是否显示在选区上方，默认为true
  const SelectionToolbar({
    super.key,
    required this.controller,
    required this.layerLink,
    required this.editorSize,
    required this.selectionRect,
    this.onClosed,
    this.onFormatChanged,
    this.wordCount = 0,
    this.showAbove = true,
  });

  /// 富文本编辑器控制器
  final QuillController controller;

  /// 用于定位工具栏的层链接
  final LayerLink layerLink;

  /// 编辑器尺寸
  final Size editorSize;

  /// 选区矩形
  final Rect selectionRect;

  /// 工具栏关闭时的回调
  final VoidCallback? onClosed;

  /// 格式变更时的回调
  final VoidCallback? onFormatChanged;

  /// 选中文本的字数
  final int wordCount;

  /// 是否显示在选区上方，默认为true
  final bool showAbove;

  @override
  State<SelectionToolbar> createState() => _SelectionToolbarState();
}

class _SelectionToolbarState extends State<SelectionToolbar> {
  late final FocusNode _toolbarFocusNode;
  final GlobalKey _toolbarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _toolbarFocusNode = FocusNode();

    // 初始化后计算是否需要调整位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustPosition();
    });
  }

  void _adjustPosition() {
    // 获取工具栏尺寸
    final RenderBox? toolbarBox =
        _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (toolbarBox == null) return;

    final toolbarSize = toolbarBox.size;
    final selectionCenter = widget.selectionRect.center;

    // 检查工具栏是否会超出边界
    final bool wouldOverflowTop =
        selectionCenter.dy - toolbarSize.height - 10 < 0;
    final bool wouldOverflowBottom =
        selectionCenter.dy + toolbarSize.height + 10 > widget.editorSize.height;

    // 根据边界情况决定显示在上方还是下方
    final bool shouldShowBelow = wouldOverflowTop && !wouldOverflowBottom;

    // 如果需要调整位置，更新状态
    if ((widget.showAbove && shouldShowBelow) ||
        (!widget.showAbove && !shouldShowBelow)) {
      // 通知父组件调整位置
      if (widget.onFormatChanged != null) {
        widget.onFormatChanged!();
      }
    }
  }

  @override
  void dispose() {
    _toolbarFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 计算位置，确保工具栏居中于选区
    return CompositedTransformFollower(
      link: widget.layerLink,
      key: _toolbarKey,
      offset: Offset(0, widget.showAbove ? -60 : 30), // 直接使用固定偏移，确保工具栏可见
      followerAnchor: Alignment.center,
      targetAnchor: Alignment.center,
      showWhenUnlinked: false,
      child: Material(
        elevation: 5,
        color: Colors.black87,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          constraints: const BoxConstraints(
            maxWidth: 600,
            minWidth: 200,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 字数统计和操作按钮
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 字数统计
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(
                      '${widget.wordCount} ${widget.wordCount > 1 ? 'Words' : 'Word'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 撤销按钮
                  _buildToolbarButton(
                    icon: Icons.undo,
                    tooltip: '撤销',
                    onPressed: () {
                      if (widget.controller.hasUndo) {
                        widget.controller.undo();
                      }
                    },
                  ),
                  // 重做按钮
                  _buildToolbarButton(
                    icon: Icons.redo,
                    tooltip: '重做',
                    onPressed: () {
                      if (widget.controller.hasRedo) {
                        widget.controller.redo();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 格式化按钮
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 加粗按钮
                    _buildFormatButton(
                      icon: Icons.format_bold,
                      tooltip: '加粗',
                      attribute: Attribute.bold,
                    ),
                    // 斜体按钮
                    _buildFormatButton(
                      icon: Icons.format_italic,
                      tooltip: '斜体',
                      attribute: Attribute.italic,
                    ),
                    // 下划线按钮
                    _buildFormatButton(
                      icon: Icons.format_underline,
                      tooltip: '下划线',
                      attribute: Attribute.underline,
                    ),
                    // 删除线按钮
                    _buildFormatButton(
                      icon: Icons.format_strikethrough,
                      tooltip: '删除线',
                      attribute: Attribute.strikeThrough,
                    ),
                    const VerticalDivider(
                      color: Colors.white24,
                      width: 16,
                      thickness: 1,
                      indent: 8,
                      endIndent: 8,
                    ),
                    // 引用按钮
                    _buildFormatButton(
                      icon: Icons.format_quote,
                      tooltip: '引用',
                      attribute: Attribute.blockQuote,
                    ),
                    // 标题按钮
                    _buildPopupButton(
                      icon: Icons.title,
                      tooltip: '标题',
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          child: const Text('标题 1'),
                          onTap: () => _applyAttribute(Attribute.h1),
                        ),
                        PopupMenuItem(
                          child: const Text('标题 2'),
                          onTap: () => _applyAttribute(Attribute.h2),
                        ),
                        PopupMenuItem(
                          child: const Text('标题 3'),
                          onTap: () => _applyAttribute(Attribute.h3),
                        ),
                        PopupMenuItem(
                          child: const Text('普通文本'),
                          onTap: () => _clearHeadingAttribute(),
                        ),
                      ],
                    ),
                    // 列表按钮
                    _buildPopupButton(
                      icon: Icons.format_list_bulleted,
                      tooltip: '列表',
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          child: const Text('无序列表'),
                          onTap: () => _applyAttribute(Attribute.ul),
                        ),
                        PopupMenuItem(
                          child: const Text('有序列表'),
                          onTap: () => _applyAttribute(Attribute.ol),
                        ),
                        PopupMenuItem(
                          child: const Text('检查列表'),
                          onTap: () => _applyAttribute(Attribute.checked),
                        ),
                        PopupMenuItem(
                          child: const Text('移除列表'),
                          onTap: () => _clearListAttribute(),
                        ),
                      ],
                    ),
                    const VerticalDivider(
                      color: Colors.white24,
                      width: 16,
                      thickness: 1,
                      indent: 8,
                      endIndent: 8,
                    ),
                    // 片段按钮
                    _buildToolbarButton(
                      text: '片段',
                      tooltip: '添加为片段',
                      onPressed: () {
                        // TODO: 实现片段功能
                        AppLogger.i('SelectionToolbar', '添加为片段');
                      },
                    ),
                    // 知识库条目按钮
                    _buildToolbarButton(
                      text: '知识库条目',
                      tooltip: '添加为知识库条目',
                      onPressed: () {
                        // TODO: 实现知识库条目功能
                        AppLogger.i('SelectionToolbar', '添加为知识库条目');
                      },
                    ),
                    // 章节/段落按钮
                    _buildToolbarButton(
                      text: '章节',
                      tooltip: '设置为章节',
                      onPressed: () {
                        // TODO: 实现章节/段落功能
                        AppLogger.i('SelectionToolbar', '设置为章节');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButton({
    IconData? icon,
    String? text,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        hoverColor: Colors.white10,
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: icon != null
              ? Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                )
              : Text(
                  text ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  /// 构建格式按钮
  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required Attribute attribute,
  }) {
    // 检查当前选中文本是否已应用了该属性
    final currentStyle = widget.controller.getSelectionStyle();
    final bool isActive = currentStyle.attributes.containsKey(attribute.key) &&
        (currentStyle.attributes[attribute.key]?.value == attribute.value);

    AppLogger.v(
        'SelectionToolbar', '按钮 ${attribute.key} 状态: isActive=$isActive');

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: () => _applyAttribute(attribute),
        borderRadius: BorderRadius.circular(4),
        hoverColor: Colors.white10,
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Icon(
            icon,
            color: isActive ? Colors.lightBlueAccent : Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  /// 构建弹出菜单按钮
  Widget _buildPopupButton({
    required IconData icon,
    required String tooltip,
    required PopupMenuItemBuilder<String> itemBuilder,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: PopupMenuButton<String>(
        tooltip: '',
        color: Colors.grey.shade800,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        position: PopupMenuPosition.under,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemBuilder: itemBuilder,
      ),
    );
  }

  /// 应用文本属性
  void _applyAttribute(Attribute attribute) {
    try {
      // 确保选中文本有效
      if (widget.controller.selection.isCollapsed) {
        AppLogger.i('SelectionToolbar', '无选中文本，无法应用格式');
        return;
      }

      // 获取选区信息
      final int start = widget.controller.selection.start;
      final int end = widget.controller.selection.end;
      final length = end - start;

      // 检查当前选中文本是否已应用了该属性
      final currentStyle = widget.controller.getSelectionStyle();
      final bool hasAttribute = currentStyle.attributes
              .containsKey(attribute.key) &&
          (currentStyle.attributes[attribute.key]?.value == attribute.value);

      AppLogger.i(
          'SelectionToolbar', '当前选区位置: start=$start, end=$end, length=$length');
      AppLogger.i('SelectionToolbar',
          '当前样式状态: ${attribute.key}=${hasAttribute ? '已应用' : '未应用'}');
      AppLogger.d('SelectionToolbar', '当前样式完整内容: ${currentStyle.attributes}');

      // 如果已应用该属性，则移除它；否则添加它
      if (hasAttribute) {
        // 创建一个同名但值为null的属性来移除格式
        final nullAttribute = Attribute.clone(attribute, null);
        widget.controller.formatText(start, length, nullAttribute);
        AppLogger.i('SelectionToolbar', '移除格式: ${attribute.key}');
      } else {
        // 应用格式
        widget.controller.formatText(start, length, attribute);
        AppLogger.i(
            'SelectionToolbar', '应用格式: ${attribute.key}=${attribute.value}');
      }

      if (widget.onFormatChanged != null) {
        widget.onFormatChanged!();
      }
    } catch (e, stackTrace) {
      AppLogger.e('SelectionToolbar', '应用/移除格式失败', e, stackTrace);
    }
  }

  /// 清除标题属性
  void _clearHeadingAttribute() {
    try {
      // 确保选中文本有效
      if (widget.controller.selection.isCollapsed) {
        AppLogger.i('SelectionToolbar', '无选中文本，无法清除标题格式');
        return;
      }

      final int start = widget.controller.selection.start;
      final int end = widget.controller.selection.end;
      final length = end - start;

      // 移除所有标题相关属性
      for (final attr in [Attribute.h1, Attribute.h2, Attribute.h3]) {
        if (widget.controller
            .getSelectionStyle()
            .attributes
            .containsKey(attr.key)) {
          widget.controller
              .formatText(start, length, Attribute.clone(attr, null));
        }
      }

      AppLogger.i('SelectionToolbar', '清除标题格式');

      if (widget.onFormatChanged != null) {
        widget.onFormatChanged!();
      }
    } catch (e, stackTrace) {
      AppLogger.e('SelectionToolbar', '清除标题格式失败', e, stackTrace);
    }
  }

  /// 清除列表属性
  void _clearListAttribute() {
    try {
      // 确保选中文本有效
      if (widget.controller.selection.isCollapsed) {
        AppLogger.i('SelectionToolbar', '无选中文本，无法清除列表格式');
        return;
      }

      final int start = widget.controller.selection.start;
      final int end = widget.controller.selection.end;
      final length = end - start;

      // 移除所有列表相关属性
      for (final attr in [Attribute.ul, Attribute.ol, Attribute.checked]) {
        if (widget.controller
            .getSelectionStyle()
            .attributes
            .containsKey(attr.key)) {
          widget.controller
              .formatText(start, length, Attribute.clone(attr, null));
        }
      }

      AppLogger.i('SelectionToolbar', '清除列表格式');

      if (widget.onFormatChanged != null) {
        widget.onFormatChanged!();
      }
    } catch (e, stackTrace) {
      AppLogger.e('SelectionToolbar', '清除列表格式失败', e, stackTrace);
    }
  }
}
