import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/screens/editor/widgets/selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:ainoval/screens/editor/widgets/custom_dropdown.dart';
import 'package:ainoval/screens/editor/widgets/menu_builder.dart';

/// 场景编辑器组件，用于编辑小说中的单个场景
///
/// [title] 场景标题
/// [wordCount] 场景字数统计
/// [isActive] 当前场景是否处于激活状态
/// [actId] 所属篇章ID
/// [chapterId] 所属章节ID
/// [sceneId] 场景ID
/// [isFirst] 是否为章节中的第一个场景
/// [sceneIndex] 场景在章节中的序号，从1开始
/// [controller] 场景内容编辑控制器
/// [summaryController] 场景摘要编辑控制器
/// [editorBloc] 编辑器状态管理
/// [onContentChanged] 内容变更回调
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
    this.sceneIndex, // 添加场景序号参数
    required this.controller,
    required this.summaryController,
    required this.editorBloc,
    this.onContentChanged, // 添加回调函数
    this.isVisuallyNearby = true, // 新增参数，默认为true以保持当前行为
  });
  final String title;
  final int wordCount;
  final bool isActive;
  final String? actId;
  final String? chapterId;
  final String? sceneId;
  final bool isFirst;
  final int? sceneIndex; // 场景在章节中的序号，从1开始
  final QuillController controller;
  final TextEditingController summaryController;
  final editor_bloc.EditorBloc editorBloc;
  // 添加内容变更回调
  final Function(String content, int wordCount, {bool syncToServer})? onContentChanged;
  final bool isVisuallyNearby; // 新增参数声明

  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> with AutomaticKeepAliveClientMixin {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isFocused = false;
  // 为编辑器创建一个Key
  late final Key _editorKey;
  // 内容更新防抖定时器
  Timer? _contentDebounceTimer;
  final FocusNode _summaryFocusNode = FocusNode();
  bool _isSummaryFocused = false;
  // 焦点防抖定时器
  Timer? _focusDebounceTimer;

  // 添加文本选择工具栏相关变量
  bool _showToolbar = false;
  final LayerLink _toolbarLayerLink = LayerLink();
  int _selectedTextWordCount = 0;
  Timer? _selectionDebounceTimer;
  bool _showToolbarAbove = false; // 默认在选区下方显示，简化计算
  Rect _selectionRect = Rect.zero; // 当前选区的位置
  final GlobalKey _editorContentKey = GlobalKey(); // 编辑器内容区域的key
  
  // 添加一个延迟初始化标志
  bool _isEditorFullyInitialized = false;

  // 添加防抖处理
  String _pendingContent = '';
  String _lastSavedContent = ''; // 添加最后保存的内容，用于比较变化
  DateTime _lastChangeTime = DateTime.now(); // 添加最后变更时间
  int _pendingWordCount = 0;
  Timer? _syncTimer;
  final int _minorChangeThreshold = 5; // 定义微小改动的字符数阈值

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
    
    // 监听EditorBloc状态变化，确保摘要控制器内容与模型保持同步
    _setupBlocListener();
    
    // 初始化最后保存的内容
    //TODO 是否需要初始化？
    _lastSavedContent = widget.controller.document.toPlainText();
    
    // 延迟完整初始化，优先显示基础UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 在渲染完成后再初始化复杂功能
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _isEditorFullyInitialized = true;
          });
        }
      });
    });
  }

  void _onEditorFocusChange() {
    // 使用节流控制焦点更新频率
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        final newFocusState = _focusNode.hasFocus;
        // 仅当焦点状态真正改变时更新状态
        if (_isFocused != newFocusState) {
          setState(() {
            _isFocused = newFocusState;
            // 只有当获得焦点时才设置活动元素，失去焦点时不做任何改变
            // 这样可以避免在编辑过程中频繁触发不必要的状态更新
            if (_isFocused && widget.actId != null && widget.chapterId != null) {
              // 使用更温和的方式设置活动状态，避免引起滚动
              _setActiveElementsQuietly();
            }
          });
        }
      }
    });
  }

  void _onSummaryFocusChange() {
    // 使用节流控制焦点更新频率
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        final newFocusState = _summaryFocusNode.hasFocus;
        // 仅当焦点状态真正改变时更新状态
        if (_isSummaryFocused != newFocusState) {
          setState(() {
            _isSummaryFocused = newFocusState;
            // 只有当获得焦点时才设置活动元素，失去焦点时不做任何改变
            if (_isSummaryFocused && widget.actId != null && widget.chapterId != null) {
              // 使用更温和的方式设置活动状态，避免引起滚动
              _setActiveElementsQuietly();
            }
          });
        }
      }
    });
  }

  // 设置活动元素 - 原始方法
  void _setActiveElements() {
    if (widget.actId != null && widget.chapterId != null) {
      widget.editorBloc.add(
          editor_bloc.SetActiveChapter(actId: widget.actId!, chapterId: widget.chapterId!));
      if (widget.sceneId != null) {
        widget.editorBloc.add(editor_bloc.SetActiveScene(
            actId: widget.actId!,
            chapterId: widget.chapterId!,
            sceneId: widget.sceneId!));
      }
    }
  }

  // 设置活动元素但不触发滚动 - 适用于编辑中场景
  void _setActiveElementsQuietly() {
    if (widget.actId != null && widget.chapterId != null) {
      // 直接使用BlocProvider获取EditorBloc实例
      final editorBloc = widget.editorBloc;
      
      // 检查当前活动状态，避免重复设置相同的活动元素
      if (editorBloc.state is editor_bloc.EditorLoaded) {
        final state = editorBloc.state as editor_bloc.EditorLoaded;
        
        // 只有当活动元素确实需要变化时才发出事件
        final needsToUpdateAct = state.activeActId != widget.actId;
        final needsToUpdateChapter = state.activeChapterId != widget.chapterId;
        final needsToUpdateScene = widget.sceneId != null && state.activeSceneId != widget.sceneId;
        
        if (needsToUpdateAct || needsToUpdateChapter) {
          AppLogger.d('SceneEditor', '设置活动章节: ${widget.actId}/${widget.chapterId}');
          editorBloc.add(editor_bloc.SetActiveChapter(
            actId: widget.actId!, 
            chapterId: widget.chapterId!,
          ));
        }
        
        if (needsToUpdateScene && widget.sceneId != null) {
          AppLogger.d('SceneEditor', '设置活动场景: ${widget.sceneId}');
          editorBloc.add(editor_bloc.SetActiveScene(
            actId: widget.actId!,
            chapterId: widget.chapterId!,
            sceneId: widget.sceneId!,
          ));
        }
      } else {
        // 如果状态不是EditorLoaded，则使用原始方法
        _setActiveElements();
      }
    }
  }

  // 监听文档变化
  void _onDocumentChange(DocChange change) {
    if (!mounted) return;

    // 立即计算最新字数，用于显示
    final text = widget.controller.document.toPlainText();
    //final currentWordCount = WordCountAnalyzer.countWords(text);

    // 更新当前场景标题旁的字数显示（如果widget有回调方法）
    // 后续可添加回调通知上层组件更新显示

    // 使用防抖动机制，避免频繁发送保存请求
    _contentDebounceTimer?.cancel();
    _contentDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      // 延长为800毫秒防抖，更好地应对快速输入
      _onTextChanged(text);
    });
  }

  // 添加防抖处理
  void _onTextChanged(String newText) {
    // 计算字数 
    final wordCount = WordCountAnalyzer.countWords(newText);
    
    // 判断是否为微小改动
    final bool isMinorChange = _isMinorTextChange(newText);
    
    // 记录变动信息
    AppLogger.v('SceneEditor', '文本变更 - 字数: $wordCount, 是否微小改动: $isMinorChange');
    
    // 保存到本地变量，避免立即更新
    _pendingContent = newText;
    _pendingWordCount = wordCount;
    _lastChangeTime = DateTime.now();
    
    // 如果是微小改动，直接使用UpdateSceneContent事件，标记为微小改动
    // 这样EditorBloc可以智能决定UI刷新策略
    if (widget.actId != null && widget.chapterId != null && widget.sceneId != null) {
      widget.editorBloc.add(
        editor_bloc.UpdateSceneContent(
          novelId: widget.editorBloc.novelId,
          actId: widget.actId!,
          chapterId: widget.chapterId!,
          sceneId: widget.sceneId!,
          content: _pendingContent,
          wordCount: _pendingWordCount.toString(),
          isMinorChange: isMinorChange, // 传递是否为微小改动的标志
        ),
      );
    }
    
    // 无论是否为微小改动，都更新最后保存的内容
    _lastSavedContent = newText;
    
    // 重置防抖计时器 - 连续输入时只触发一次保存
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      // 等待2秒再保存本地，这样可以减少本地保存频率
      _saveLocalOnly();
    });
    
    // 设置同步计时器 - 每8秒同步一次到服务器
    if (_syncTimer == null || !_syncTimer!.isActive) {
      _syncTimer = Timer(const Duration(seconds: 8), () {
        _syncToServer();
      });
    }
  }
  
  // 检测是否为微小文本改动
  bool _isMinorTextChange(String newText) {
    if (_lastSavedContent.isEmpty) return false;
    
    // 1. 检查变化的字符数
    final int lengthDiff = (newText.length - _lastSavedContent.length).abs();
    
    // 2. 计算编辑距离 (简化版 - 仅考虑长度变化)
    // 对于完整的编辑距离(Levenshtein)需要更复杂的算法，这里简化处理
    final int editDistance = min(lengthDiff, _minorChangeThreshold + 1);
    
    // 3. 检查时间间隔 (如果刚刚保存过，更可能是微小改动)
    final timeSinceLastChange = DateTime.now().difference(_lastChangeTime);
    final bool isRecentChange = timeSinceLastChange < const Duration(seconds: 3);
    
    // 4. 综合判断 (字符变化很小，或者最近刚改过且变化不大)
    final bool isMinor = editDistance <= _minorChangeThreshold || 
                         (isRecentChange && editDistance <= _minorChangeThreshold * 2);
    
    AppLogger.v('SceneEditor', '变更分析 - 字符差异: $lengthDiff, 编辑距离: $editDistance, 时间间隔: ${timeSinceLastChange.inMilliseconds}ms, 判定为${isMinor ? "微小" : "重要"}改动');
    
    return isMinor;
  }

  // 保存到本地
  void _saveLocalOnly() {
    if (widget.actId != null && widget.chapterId != null && widget.sceneId != null) {
      // 直接调用EditorBloc保存，不触发同步
      widget.editorBloc.add(
        editor_bloc.SaveSceneContent(
          novelId: widget.editorBloc.novelId,
          actId: widget.actId!,
          chapterId: widget.chapterId!,
          sceneId: widget.sceneId!,
          content: _pendingContent,
          wordCount: _pendingWordCount.toString(),
          localOnly: true, // 仅保存到本地
        ),
      );
      
      // 更新最后保存的内容
      _lastSavedContent = _pendingContent;
    } else if (widget.onContentChanged != null) {
      // 如果提供了回调，使用回调函数
      widget.onContentChanged!(_pendingContent, _pendingWordCount, syncToServer: false);
      
      // 更新最后保存的内容
      _lastSavedContent = _pendingContent;
    }
  }
  
  // 同步到服务器
  void _syncToServer() {
    if (widget.actId != null && widget.chapterId != null && widget.sceneId != null) {
      // 使用EditorBloc同步到服务器
      widget.editorBloc.add(
        editor_bloc.SaveSceneContent(
          novelId: widget.editorBloc.novelId,
          actId: widget.actId!,
          chapterId: widget.chapterId!,
          sceneId: widget.sceneId!,
          content: _pendingContent,
          wordCount: _pendingWordCount.toString(),
          localOnly: false, // 同步到服务器
        ),
      );
      
      // 更新最后保存的内容
      _lastSavedContent = _pendingContent;
    } else if (widget.onContentChanged != null) {
      // 如果提供了回调，使用回调函数
      widget.onContentChanged!(_pendingContent, _pendingWordCount, syncToServer: true);
      
      // 更新最后保存的内容
      _lastSavedContent = _pendingContent;
    }
  }

  // 处理文本选择变化
  void _handleSelectionChange() {
    // 若选区变化太快，跳过更新
    final selection = widget.controller.selection;
    if (selection.isCollapsed) {
      // 如果没有选择文本，隐藏工具栏
      if (_showToolbar) {
        setState(() {
          _showToolbar = false;
          _selectedTextWordCount = 0;
        });
      }
      return;
    }
    
    // 使用更高效的节流控制
    _selectionDebounceTimer?.cancel();
    _selectionDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      
      // 高效判断是否需要更新界面
      final selectedText = widget.controller.document
          .getPlainText(selection.start, selection.end - selection.start);
      final wordCount = WordCountAnalyzer.countWords(selectedText);
      
      // 仅当选择内容与上次不同时才更新
      if (!_showToolbar || _selectedTextWordCount != wordCount) {
        setState(() {
          _showToolbar = true;
          _selectedTextWordCount = wordCount;
          // 简化位置计算，使用固定位置
          _showToolbarAbove = false;
        });
      }
    });
  }

  // // 简化的选区矩形计算
  // Rect _calculateSelectionRect() {
  //   try {
  //     // 获取编辑器渲染对象
  //     final RenderBox? editorBox =
  //         _editorContentKey.currentContext?.findRenderObject() as RenderBox?;
  //     if (editorBox == null) return Rect.zero;

  //     // 获取编辑器全局坐标
  //     final editorOffset = editorBox.localToGlobal(Offset.zero);
  //     final editorWidth = editorBox.size.width;

  //     // 创建一个固定位置，避免复杂计算
  //     return Rect.fromLTWH(
  //       editorWidth * 0.5 - 50, // 水平居中偏左
  //       50, // 固定在顶部下方50像素
  //       100, // 固定宽度
  //       30, // 固定高度
  //     );
  //   } catch (e) {
  //     return Rect.zero;
  //   }
  // }

  @override
  void dispose() {
    // 页面关闭前确保同步到服务器
    _debounceTimer?.cancel();
    _syncTimer?.cancel();
    
    // 如果有待同步内容，立即同步
    if (_pendingContent.isNotEmpty && _pendingContent != _lastSavedContent) {
      _syncToServer();
    }
    
    _focusNode.removeListener(_onEditorFocusChange);
    _summaryFocusNode.removeListener(_onSummaryFocusChange);
    _contentDebounceTimer?.cancel(); // 取消内容防抖定时器
    _selectionDebounceTimer?.cancel(); // 取消选择防抖定时器
    _focusDebounceTimer?.cancel(); // 取消焦点防抖定时器
    widget.controller.removeListener(_handleSelectionChange); // 移除选择变化监听
    _focusNode.dispose();
    _summaryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用super.build
    final theme = Theme.of(context);
    final bool isEditorOrSummaryFocused = _isFocused || _isSummaryFocused;

    return _buildOptimizedSceneEditor(theme, isEditorOrSummaryFocused);
  }
  
  // 优化后的场景编辑器构建方法
  Widget _buildOptimizedSceneEditor(ThemeData theme, bool isEditorOrSummaryFocused) {
    // 使用RepaintBoundary包装Card以隔离重绘
    return RepaintBoundary(
      child: Card(
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
        child: MouseRegion(
          cursor: SystemMouseCursors.text, // 在卡片上显示文本光标
          child: GestureDetector(
            onTapDown: (_) {
              // 只在非焦点状态下进行激活操作
              if (!_isFocused && !_isSummaryFocused) {
                _setActiveElementsQuietly();
              }
            },
            // 添加点击处理，但确保不会干扰子控件的焦点
            onTap: () {
              // 如果编辑器还没有焦点，尝试获取焦点
              if (!_isFocused && !_isSummaryFocused && mounted) {
                // 只有当没有其他焦点时，才请求焦点
                if (!FocusScope.of(context).hasFocus && _focusNode.canRequestFocus) {
                  _focusNode.requestFocus();
                }
              }
            },
            behavior: HitTestBehavior.translucent, // 确保即使有子组件也能接收手势
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
                              child: _isEditorFullyInitialized 
                                ? _buildEditor(theme, isEditorOrSummaryFocused)
                                : _buildSimplePreview(),
                            ),
                            // 文本选择工具栏
                            if (_showToolbar && _isEditorFullyInitialized)
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
        ),
      ),
    );
  }
  
  // 简单预览，用于快速展示
  Widget _buildSimplePreview() {
    return SizedBox(
      height: 150,
      child: Center(
        child: Text(
          '加载中...',
          style: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }
  
  // 为了支持AutomaticKeepAliveClientMixin
  @override
  bool get wantKeepAlive => widget.isVisuallyNearby; // 使用 widget.isVisuallyNearby

  Widget _buildSceneHeader(ThemeData theme, bool isFocused) {
    return Padding(
      // 移除底部 padding，由 SizedBox 控制
      padding: const EdgeInsets.only(bottom: 0.0),
      child: Row(
        children: [
          // 添加场景序号
          if (widget.sceneIndex != null)
            Text(
              _getSceneIndexText(),
              style: theme.textTheme.titleSmall?.copyWith(
                color: isFocused || widget.isActive
                    ? theme.colorScheme.primary
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          if (!widget.wordCount.isNaN)
            Text(
              widget.wordCount.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  // 添加获取场景序号文本的方法
  String _getSceneIndexText() {
    if (widget.sceneIndex == null) return '';
    
    // 使用中文数字表示场景序号
    final List<String> chineseNumbers = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    
    if (widget.sceneIndex! <= 10) {
      return '场景${chineseNumbers[widget.sceneIndex!]} · ';
    } else if (widget.sceneIndex! < 20) {
      return '场景十${chineseNumbers[widget.sceneIndex! - 10]} · ';
    } else {
      // 对于更大的数字，直接使用阿拉伯数字
      return '场景${widget.sceneIndex} · ';
    }
  }

  // 为编辑器添加焦点处理
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
                  AppLogger.i('SceneEditor', '通过onChange保存摘要: ${widget.sceneId}');
                  widget.editorBloc.add(editor_bloc.UpdateSummary(
                    novelId: widget.editorBloc.novelId,
                    actId: widget.actId!,
                    chapterId: widget.chapterId!,
                    sceneId: widget.sceneId!,
                    summary: value,
                    shouldRebuild: true, // 改为true，确保UI更新和完整保存
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
              AppLogger.i('SceneEditor', '通过刷新按钮保存摘要: ${widget.sceneId}');
              widget.editorBloc.add(editor_bloc.UpdateSummary(
                novelId: widget.editorBloc.novelId,
                actId: widget.actId!,
                chapterId: widget.chapterId!,
                sceneId: widget.sceneId!,
                summary: widget.summaryController.text,
                shouldRebuild: true, // 修改为true，确保完整保存到后端
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
                editor_bloc.GenerateSceneSummaryRequested(
                  sceneId: widget.sceneId!,
                ),
              );
              
              // 监听生成完成状态，更新摘要控制器
              // 使用StreamSubscription监听状态变化
              StreamSubscription<editor_bloc.EditorState>? stateSubscription;
              stateSubscription = widget.editorBloc.stream.listen((state) {
                if (state is editor_bloc.EditorLoaded) {
                  // 当摘要生成完成时
                  if (state.aiSummaryGenerationStatus == editor_bloc.AIGenerationStatus.completed &&
                      state.generatedSummary != null &&
                      widget.sceneId == state.activeSceneId) {
                    // 更新摘要文本
                    widget.summaryController.text = state.generatedSummary!;
                    
                    // 触发摘要保存
                    widget.editorBloc.add(editor_bloc.UpdateSummary(
                      novelId: widget.editorBloc.novelId,
                      actId: widget.actId!,
                      chapterId: widget.chapterId!,
                      sceneId: widget.sceneId!,
                      summary: state.generatedSummary!,
                      shouldRebuild: true, // 修改为true，确保完整保存到后端
                    ));
                    
                    // 取消监听
                    stateSubscription?.cancel();
                  } else if (state.aiSummaryGenerationStatus == editor_bloc.AIGenerationStatus.failed) {
                    // 生成失败时也要取消监听
                    stateSubscription?.cancel();
                  }
                }
              });
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
        
        // 新增：从摘要生成场景按钮
        if (widget.summaryController.text.isNotEmpty)
          _ActionButton(
            icon: Icons.auto_stories,
            label: 'AI生成场景',
            tooltip: '从摘要生成场景内容',
            onPressed: () {
              if (widget.actId != null && 
                  widget.chapterId != null && 
                  widget.sceneId != null) {
                // 获取布局管理器并打开AI生成面板
                final layoutManager = Provider.of<EditorLayoutManager>(context, listen: false);
                
                // 保存当前摘要到EditorBloc中，以便AI生成面板可以获取到
                widget.editorBloc.add(
                  editor_bloc.SetPendingSummary(
                    summary: widget.summaryController.text,
                  ),
                );
                
                // 显示AI生成面板
                layoutManager.toggleAISceneGenerationPanel();
                
                // 不再在这里立即触发生成，让用户在面板中确认后再生成
                // 面板将会自动填充之前设置的摘要内容
              }
            },
          ),
        const SizedBox(width: 8),
        
        // 更多操作按钮
        widget.actId != null && widget.chapterId != null && widget.sceneId != null
            ? MenuBuilder.buildSceneMenu(
                context: context,
                editorBloc: widget.editorBloc,
                actId: widget.actId!,
                chapterId: widget.chapterId!,
                sceneId: widget.sceneId!,
              )
            : const SizedBox.shrink(),
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

  // 添加EditorBloc状态监听，确保摘要控制器内容与模型保持同步
  void _setupBlocListener() {
    widget.editorBloc.stream.listen((state) {
      if (!mounted) return;
      
      if (state is editor_bloc.EditorLoaded && 
          widget.sceneId != null && 
          widget.actId != null && 
          widget.chapterId != null) {
        try {
          // 使用更安全的查找方式
          bool found = false;
          String? modelSummaryContent;
          
          // 遍历所有元素查找指定场景
          for (final act in state.novel.acts) {
            if (act.id == widget.actId) {
              for (final chapter in act.chapters) {
                if (chapter.id == widget.chapterId) {
                  for (final scene in chapter.scenes) {
                    if (scene.id == widget.sceneId) {
                      found = true;
                      modelSummaryContent = scene.summary.content ?? '';
                      break;
                    }
                  }
                  if (found) break;
                }
              }
              if (found) break;
            }
          }
          
          // 如果场景不存在，则提前返回
          if (!found) {
            AppLogger.d('SceneEditor', '跳过摘要同步：场景不存在或已被删除: ${widget.sceneId}');
            return;
          }
          
          // 当前控制器中的文本
          final currentControllerText = widget.summaryController.text;
          
          // 仅当摘要控制器内容与模型不同时更新
          if (currentControllerText != modelSummaryContent) {
            // 判断变更方向
            if (currentControllerText.isNotEmpty && (modelSummaryContent == null || modelSummaryContent.isEmpty)) {
              // 如果控制器有内容但模型为空，说明是用户刚输入了内容但可能未保存成功
              // 重新触发保存操作确保内容被保存
              AppLogger.i('SceneEditor', '检测到摘要未同步到模型，重新保存: ${widget.sceneId}');
              
              // 将更新放在下一帧执行，避免在build过程中修改
              Future.microtask(() {
                if (mounted) {
                  // 触发摘要保存并强制重建UI以确保更新成功
                  widget.editorBloc.add(editor_bloc.UpdateSummary(
                    novelId: widget.editorBloc.novelId,
                    actId: widget.actId!,
                    chapterId: widget.chapterId!,
                    sceneId: widget.sceneId!,
                    summary: currentControllerText,
                    shouldRebuild: true, // 强制重建UI
                  ));
                }
              });
            } else if (modelSummaryContent != null && modelSummaryContent.isNotEmpty) {
              // 模型中有内容但控制器不同，更新控制器
              AppLogger.i('SceneEditor', '摘要内容从模型同步到控制器: ${widget.sceneId}');
              
              // 将更新放在下一帧执行，避免在build过程中修改
              Future.microtask(() {
                if (mounted) {
                  widget.summaryController.text = modelSummaryContent!;
                }
              });
            }
          }
        } catch (e, stackTrace) {
          // 记录详细错误信息但不抛出异常
          AppLogger.i('SceneEditor', '同步摘要控制器失败，可能是场景已被删除: ${widget.sceneId}');
          AppLogger.v('SceneEditor', '同步摘要控制器详细错误: ${e.toString()}', e, stackTrace);
        }
      }
    });
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
