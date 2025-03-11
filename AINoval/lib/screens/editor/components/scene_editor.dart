import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';

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
  // 为编辑器创建一个GlobalKey
  late final GlobalKey _editorKey;

  @override
  void initState() {
    super.initState();
    // 初始化GlobalKey
    final String sceneId = widget.sceneId ?? 
        (widget.actId != null && widget.chapterId != null 
            ? '${widget.actId}_${widget.chapterId}' 
            : widget.title.replaceAll(' ', '_').toLowerCase());
    _editorKey = GlobalObjectKey('editor_$sceneId');
    
    // 监听焦点变化
    _focusNode.addListener(_onFocusChange);
    
    // 如果当前场景是活动场景，自动请求焦点
    if (widget.isActive) {
      Future.microtask(() {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
          setState(() {
            _isFocused = true;
          });
        }
      });
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _debounceTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String sceneId = widget.sceneId ?? 
        (widget.actId != null && widget.chapterId != null 
            ? '${widget.actId}_${widget.chapterId}' 
            : widget.title.replaceAll(' ', '_').toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 如果不是第一个场景，添加场景分隔符
        if (!widget.isFirst)
          const _SceneDivider(),
        
        // 场景标题和字数统计
        _buildSceneHeader(),
        
        // 编辑器和摘要区域并排显示
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 编辑器区域
            Expanded(
              flex: 7, // 占据70%的宽度
              child: _buildEditor(sceneId),
            ),
            
            // 摘要区域
            Expanded(
              flex: 3, // 占据30%的宽度
              child: _buildSummaryArea(sceneId),
            ),
          ],
        ),
        
        // 底部操作按钮
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildSceneHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: _isFocused || widget.isActive ? Colors.black87 : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (widget.wordCount.isNotEmpty)
            Text(
              widget.wordCount,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor(String sceneId) {
    return GestureDetector(
      key: _editorKey, // 使用GlobalKey
      onTap: () {
        // 如果有actId和chapterId，设置为活动章节
        if (widget.actId != null && widget.chapterId != null) {
          // 设置活动章节
          widget.editorBloc.add(SetActiveChapter(
            actId: widget.actId!, 
            chapterId: widget.chapterId!
          ));
          
          // 如果有sceneId，设置为活动场景
          if (widget.sceneId != null) {
            widget.editorBloc.add(SetActiveScene(
              actId: widget.actId!,
              chapterId: widget.chapterId!,
              sceneId: widget.sceneId!
            ));
          }
        }
        
        // 立即请求焦点
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      },
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 100, // 设置最小高度
        ),
        decoration: BoxDecoration(
          // 使用更明显的背景色来指示选中状态
          color: _isFocused 
              ? Colors.grey.shade100  // 焦点状态时使用更深的背景色
              : (widget.isActive ? Colors.grey.shade50 : Colors.transparent),
          borderRadius: BorderRadius.circular(4),
          // 添加焦点状态的边框
          border: _isFocused 
              ? Border.all(color: Colors.blue.shade200, width: 1.0)
              : null,
        ),
        child: QuillEditor(
          controller: widget.controller,
          focusNode: _focusNode,
          scrollController: ScrollController(),
          configurations: const QuillEditorConfigurations(
            scrollable: false, // 改为false，不需要内部滚动
            autoFocus: false, // 不自动获取焦点
            sharedConfigurations: QuillSharedConfigurations(
              locale: Locale('zh', 'CN'),
            ),
            placeholder: 'Start writing, or type \'/\' for commands...',
            expands: false,
            padding: EdgeInsets.all(8),
            customStyles: DefaultStyles(
              paragraph: DefaultTextBlockStyle(
                TextStyle(
                  fontSize: 16,
                  fontFamily: 'Serif',
                  height: 1.5,
                  color: Colors.black87,
                ),
                HorizontalSpacing(0, 0),
                VerticalSpacing(0, 0),
                VerticalSpacing(0, 0),
                BoxDecoration(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryArea(String sceneId) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isFocused || widget.isActive ? Colors.grey.shade50 : Colors.white, // 编辑区获得焦点时，摘要区也变色
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _isFocused ? Colors.blue.shade100 : Theme.of(context).dividerColor,
          width: _isFocused ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 摘要标题
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isFocused || widget.isActive ? Colors.black87 : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 16),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey.shade700,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 摘要内容
          TextField(
            controller: widget.summaryController,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            maxLines: null, // 允许无限行
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Add summary...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
            onChanged: (value) {
              // 使用防抖动机制，避免频繁更新摘要
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                if (mounted && widget.actId != null && widget.chapterId != null) {
                  widget.editorBloc.add(UpdateSummary(
                    novelId: widget.editorBloc.novelId,
                    actId: widget.actId!,
                    chapterId: widget.chapterId!,
                    sceneId: sceneId,
                    summary: value,
                    shouldRebuild: false,
                  ));
                }
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // 底部操作按钮
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryActionButton(
                icon: Icons.refresh,
                label: '刷新',
              ),
              _SummaryActionButton(
                icon: Icons.auto_awesome,
                label: 'AI生成',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return const Padding(
      padding: EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ActionButton(
            icon: Icons.add,
            label: 'Actions',
          ),
          SizedBox(width: 8),
          _ActionButton(
            icon: Icons.label_outline,
            label: 'Label',
          ),
          SizedBox(width: 8),
          _ActionButton(
            icon: Icons.code,
            label: 'Codex',
          ),
        ],
      ),
    );
  }
}

class _SceneDivider extends StatelessWidget {
  const _SceneDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Container(
          width: 40,
          height: 20,
          alignment: Alignment.center,
          child: const Icon(
            Icons.diamond_outlined,
            size: 16,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _SummaryActionButton extends StatelessWidget {

  const _SummaryActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
} 