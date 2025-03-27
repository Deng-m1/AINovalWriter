import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:ainoval/utils/logger.dart';

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
    _focusNode.addListener(_onFocusChange);
    
    // 添加控制器内容监听器
    widget.controller.document.changes.listen(_onDocumentChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  // 新增：监听文档变化
  void _onDocumentChange(DocChange change) {
    // 使用防抖动机制，避免频繁更新内容
    _contentDebounceTimer?.cancel();
    _contentDebounceTimer = Timer(const Duration(milliseconds: 1000), () { // 1秒防抖
      _saveContent();
    });
  }

  // 新增：保存内容的方法
  void _saveContent() {
     if (mounted && widget.actId != null && widget.chapterId != null && widget.sceneId != null) {
        try {
          final jsonStr = jsonEncode(widget.controller.document.toDelta().toJson());
          widget.editorBloc.add(UpdateSceneContent(
            novelId: widget.editorBloc.novelId,
            actId: widget.actId!,
            chapterId: widget.chapterId!,
            sceneId: widget.sceneId!, // 使用 widget.sceneId
            content: jsonStr,
            shouldRebuild: false, // 通常不需要重建整个列表
          ));
        } catch (e, stackTrace) {
          AppLogger.e('SceneEditor', '更新场景内容失败: ${widget.sceneId}', e, stackTrace);
        }
      }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _debounceTimer?.cancel();
    _contentDebounceTimer?.cancel(); // 取消内容防抖定时器
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              flex: 7, // 固定比例
              child: _buildEditor(),
            ),
            
            // 摘要区域
            Expanded(
              flex: 3, // 固定比例
              child: _buildSummaryArea(),
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

  Widget _buildEditor() {
    return GestureDetector(
      key: _editorKey, // 使用ValueKey
      onTap: () {
        // 如果有actId和chapterId，设置为活动章节/场景
        if (widget.actId != null && widget.chapterId != null) {
          // 简化：只派发事件，让 Bloc 处理状态和焦点
          widget.editorBloc.add(SetActiveChapter(
            actId: widget.actId!, 
            chapterId: widget.chapterId!
          ));
          
          if (widget.sceneId != null) {
             widget.editorBloc.add(SetActiveScene(
               actId: widget.actId!,
               chapterId: widget.chapterId!,
               sceneId: widget.sceneId!
             ));
          }
          // 不再手动请求焦点，依赖 isActive 和 QuillEditor 的 autoFocus
          // if (mounted && _focusNode.canRequestFocus) {
          //   _focusNode.requestFocus();
          // }
        } else {
          // 如果没有 actId/chapterId，可能不需要特殊处理 onTap
          // 或者如果这是某种特殊编辑器，则请求焦点
           if (mounted && _focusNode.canRequestFocus) {
             _focusNode.requestFocus();
           }
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
        child: QuillEditor.basic(
          controller: widget.controller,
          focusNode: _focusNode,
          scrollController: ScrollController(),
          config: QuillEditorConfig(
            showCursor: true,
            autoFocus: widget.isActive,
            expands: false,
            padding: EdgeInsets.zero,
            scrollable: true,
            placeholder: '开始写作...',
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryArea() {
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
                if (mounted && widget.actId != null && widget.chapterId != null && widget.sceneId != null) { // 确保 sceneId 存在
                  widget.editorBloc.add(UpdateSummary(
                    novelId: widget.editorBloc.novelId,
                    actId: widget.actId!,
                    chapterId: widget.chapterId!,
                    sceneId: widget.sceneId!, // 使用 widget.sceneId
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