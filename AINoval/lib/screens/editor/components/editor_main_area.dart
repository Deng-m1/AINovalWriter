import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/screens/editor/components/act_section.dart';
import 'package:ainoval/screens/editor/components/chapter_section.dart';
import 'package:ainoval/screens/editor/components/scene_editor.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditorMainArea extends StatefulWidget {
  const EditorMainArea({
    super.key,
    required this.novel,
    required this.editorBloc,
    required this.sceneControllers,
    required this.sceneSummaryControllers,
    this.activeActId,
    this.activeChapterId,
    this.activeSceneId,
    required this.scrollController,
    required this.sceneKeys,
  });
  final novel_models.Novel novel;
  final editor_bloc.EditorBloc editorBloc;
  final Map<String, QuillController> sceneControllers;
  final Map<String, TextEditingController> sceneSummaryControllers;
  final String? activeActId;
  final String? activeChapterId;
  final String? activeSceneId;
  final ScrollController scrollController;
  final Map<String, GlobalKey> sceneKeys;

  @override
  State<EditorMainArea> createState() => EditorMainAreaState();
}

class EditorMainAreaState extends State<EditorMainArea> {
  Timer? _debounceTimer;
  bool _isInitialized = false;
  
  // 用于跟踪正在加载的章节，避免重复加载请求
  final Set<String> _loadingChapterIds = {};

  @override
  void initState() {
    super.initState();
    
    // 延迟执行，确保滚动监听器生效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isInitialized = true;
      // 只检查活动章节和周围的章节，而不是所有空章节
      _checkForVisibleEmptyChapters();
      
      // 添加滚动监听器，在滚动停止时检查可见章节
      _setupScrollListener();
      
      // 添加Bloc状态监听以更新_loadingChapterIds
      _listenToEditorBlocState();
    });
  }
  
  // 监听EditorBloc状态更新，用于跟踪加载状态变更
  void _listenToEditorBlocState() {
    widget.editorBloc.stream.listen((state) {
      if (state is editor_bloc.EditorLoaded) {
        // 如果加载状态变为false，清空正在加载的章节列表并刷新UI
        if (!state.isLoading && _loadingChapterIds.isNotEmpty) {
          setState(() {
            _loadingChapterIds.clear();
          });
          
          // 添加延迟以确保状态更新后再刷新UI
          Future.microtask(() {
            if (mounted) {
              setState(() {
                // 强制刷新UI以显示新加载的章节
                AppLogger.i('EditorMainArea', '加载完成，刷新UI显示新章节');
              });
            }
          });
        }
      }
    });
  }
  
  // 新增方法：仅检查活动章节并加载
  void _checkForVisibleEmptyChapters() {
    if (!_isInitialized) return;
    
    // 只处理活动章节
    final activeChapterId = widget.activeChapterId;
    if (activeChapterId != null) {
      // 检查活动章节是否为空
      bool isActiveChapterEmpty = false;
      String? activeActId;
      
      // 查找活动章节所属的Act和是否为空
      for (final act in widget.novel.acts) {
        for (final chapter in act.chapters) {
          if (chapter.id == activeChapterId) {
            isActiveChapterEmpty = chapter.scenes.isEmpty;
            activeActId = act.id;
            break;
          }
        }
        if (activeActId != null) break;
      }
      
      // 如果活动章节为空，则加载它
      if (isActiveChapterEmpty && activeActId != null && !_isChapterLoading(activeChapterId)) {
        _markChapterAsLoading(activeChapterId);
        AppLogger.i('EditorMainArea', '加载活动章节场景: $activeChapterId');
        widget.editorBloc.add(editor_bloc.LoadMoreScenes(
          fromChapterId: activeChapterId,
          direction: 'center',
          chaptersLimit: 3,
          preventFocusChange: true,  // 防止焦点自动变化
        ));
      }
    }
    
    // 不再主动检查和加载视口中的其他空章节
    // 改为在滚动检测边界时加载
  }

  // 添加滚动监听器
  void _setupScrollListener() {
    if (widget.scrollController.hasListeners) {
      AppLogger.i('EditorMainArea', '滚动监听器已存在，不重复添加');
      return;
    }
    
    widget.scrollController.addListener(_onScroll);
    AppLogger.i('EditorMainArea', '已添加滚动监听器');
  }
  
  // 用于记录上次检查的时间
  DateTime? _lastScrollCheckTime;
  // 用于记录上次检查的滚动位置
  double? _lastScrollPosition;
  // 防抖定时器，用于在滚动停止后再检查
  Timer? _scrollDebounceTimer;
  // 节流控制 - 记录最近成功触发加载的时间
  DateTime? _lastVisibleCheckTime;
  // 最大加载请求时间间隔
  static const Duration _loadThrottleInterval = Duration(seconds: 3);
  
  // 滚动监听回调
  void _onScroll() {
    // 取消之前的定时器
    _scrollDebounceTimer?.cancel();
    
    // 获取当前时间和滚动位置
    final now = DateTime.now();
    final currentPosition = widget.scrollController.position.pixels;
    
    // 判断是否需要检查（节流处理）
    if (_lastScrollCheckTime != null && _lastScrollPosition != null) {
      final timeDiff = now.difference(_lastScrollCheckTime!).inMilliseconds;
      final posDiff = (currentPosition - _lastScrollPosition!).abs();
      
      // 如果滚动速度很快，先不检查
      if (timeDiff < 500 && posDiff > 100) {
        return;
      }
    }
    
    // 更新上次检查时间和位置
    _lastScrollCheckTime = now;
    _lastScrollPosition = currentPosition;
    
    // 使用防抖，在滚动停止后再检查
    // 减小延迟时间以提高响应速度
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        // 节流控制 - 避免频繁检查滚动边界
        final now = DateTime.now();
        if (_lastVisibleCheckTime != null && 
            now.difference(_lastVisibleCheckTime!) < _loadThrottleInterval) {
          AppLogger.d('EditorMainArea', '跳过滚动边界检查 - 间隔过短');
          return;
        }
        
        _lastVisibleCheckTime = now;
        AppLogger.d('EditorMainArea', '滚动停止，检查滚动边界');
        
        // 检查是否需要加载上下方向的内容 - 优先级更高
        _checkScrollBoundaries();
      }
    });
  }
  
  // 检查滚动边界，决定是否需要向上或向下加载更多内容
  void _checkScrollBoundaries() {
    if (!widget.scrollController.hasClients) return;
    
    // 如果正在加载中，跳过边界检查
    if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
      final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
      if (state.isLoading) {
        AppLogger.d('EditorMainArea', '编辑器正在加载中，跳过边界检查');
        return;
      }
    }
    
    final scrollPosition = widget.scrollController.position;
    final currentOffset = scrollPosition.pixels;
    final maxOffset = scrollPosition.maxScrollExtent;
    final viewportHeight = scrollPosition.viewportDimension;
    
    // 定义边界阈值 - 使用视口高度的一定比例作为阈值
    final threshold = viewportHeight * 0.2; // 进一步减小到20%以更积极地加载
    
    // 判断是否接近顶部或底部
    bool nearTop = currentOffset <= threshold;
    bool nearBottom = (maxOffset - currentOffset) <= threshold;
    
    AppLogger.d('EditorMainArea', '滚动位置检查: 当前=$currentOffset, 最大=$maxOffset, 阈值=$threshold, 接近顶部=$nearTop, 接近底部=$nearBottom');
    
    if (nearTop) {
      // 接近顶部，加载上方内容
      AppLogger.i('EditorMainArea', '接近顶部边界，加载上方内容');
      _loadMoreInDirection('up');
    } else if (nearBottom) {
      // 接近底部，加载下方内容
      AppLogger.i('EditorMainArea', '接近底部边界，加载下方内容');
      _loadMoreInDirection('down');
    }
  }
  
  // 记录上次加载方向的时间，用于防抖
  DateTime? _lastLoadUpTime;
  DateTime? _lastLoadDownTime;
  
  // 加载指定方向的更多内容
  void _loadMoreInDirection(String direction) {
    // 防抖处理 - 控制加载频率
    final now = DateTime.now();
    if (direction == 'up' && _lastLoadUpTime != null) {
      final secondsSinceLastLoad = now.difference(_lastLoadUpTime!).inSeconds;
      if (secondsSinceLastLoad < 2) { // 减少到2秒，更积极地加载
        AppLogger.d('EditorMainArea', '向上加载过于频繁(${secondsSinceLastLoad}秒前刚加载)，跳过此次请求');
        return;
      }
    } else if (direction == 'down' && _lastLoadDownTime != null) {
      final secondsSinceLastLoad = now.difference(_lastLoadDownTime!).inSeconds;
      if (secondsSinceLastLoad < 2) { // 减少到2秒，更积极地加载
        AppLogger.d('EditorMainArea', '向下加载过于频繁(${secondsSinceLastLoad}秒前刚加载)，跳过此次请求');
        return;
      }
    }
    
    // 检查是否有正在进行的加载
    if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
      final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
      if (state.isLoading) {
        AppLogger.d('EditorMainArea', '有正在进行的加载，跳过加载请求');
        return;
      }
    }
    
    // 查找起始章节ID
    String? fromChapterId;
    if (direction == 'up') {
      // 向上加载时，从找到的第一个非空章节开始
      fromChapterId = _findFirstNonEmptyChapterId();
      _lastLoadUpTime = now;
    } else {
      // 向下加载时，从找到的最后一个非空章节开始
      fromChapterId = _findLastNonEmptyChapterId();
      _lastLoadDownTime = now;
    }
    
    if (fromChapterId != null) {
      AppLogger.i('EditorMainArea', '加载${direction == 'up' ? '上方' : '下方'}内容，起始章节: $fromChapterId');
      
      // 标记章节为加载中状态，避免重复请求
      _markChapterAsLoading(fromChapterId);
      
      // 发送加载请求
      widget.editorBloc.add(editor_bloc.LoadMoreScenes(
        fromChapterId: fromChapterId,
        direction: direction,
        chaptersLimit: 5, // 增加到5个章节，确保加载更多内容
        preventFocusChange: true, // 防止焦点改变
      ));
      
      // 强制刷新UI以显示加载状态
      setState(() {});
    } else {
      AppLogger.w('EditorMainArea', '无法找到适合加载的章节ID');
    }
  }
  
  // 辅助方法：查找第一个非空章节ID
  String? _findFirstNonEmptyChapterId() {
    for (final act in widget.novel.acts) {
      for (final chapter in act.chapters) {
        if (chapter.scenes.isNotEmpty) {
          return chapter.id;
        }
      }
    }
    // 如果没有非空章节，返回第一个章节
    if (widget.novel.acts.isNotEmpty && widget.novel.acts.first.chapters.isNotEmpty) {
      return widget.novel.acts.first.chapters.first.id;
    }
    return null;
  }
  
  // 辅助方法：查找最后一个非空章节ID
  String? _findLastNonEmptyChapterId() {
    for (int i = widget.novel.acts.length - 1; i >= 0; i--) {
      final act = widget.novel.acts[i];
      for (int j = act.chapters.length - 1; j >= 0; j--) {
        final chapter = act.chapters[j];
        if (chapter.scenes.isNotEmpty) {
          return chapter.id;
        }
      }
    }
    // 如果没有非空章节，返回最后一个章节
    if (widget.novel.acts.isNotEmpty && widget.novel.acts.last.chapters.isNotEmpty) {
      return widget.novel.acts.last.chapters.last.id;
    }
    return null;
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final veryLightGrey = Colors.grey.shade100; // 使用更浅的灰色或自定义颜色 #F8F9FA
    // 或者 Color(0xFFF8F9FA);

    // 获取当前EditorLoaded状态，检查是否正在加载更多场景
    bool isLoadingMore = false;
    if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
      final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
      isLoadingMore = state.isLoading;
    }

    return BlocListener<editor_bloc.EditorBloc, editor_bloc.EditorState>(
      bloc: widget.editorBloc,
      listener: (context, state) {
        if (state is editor_bloc.EditorLoaded) {
          // 当状态加载完成时，如果加载状态从true变为false，则刷新UI
          if (!state.isLoading && _loadingChapterIds.isNotEmpty) {
            setState(() {
              _loadingChapterIds.clear();
              AppLogger.i('EditorMainArea', 'BlocListener: 加载完成，刷新UI显示新章节');
            });
          }
        }
      },
      child: Stack(
        children: [
          Container(
            // 1. 使用更柔和的背景色
            color: veryLightGrey,
            child: _buildOptimizedScrollView(context, isLoadingMore),
          ),
          
          // 添加加载动画覆盖层
          if (isLoadingMore)
            _buildLoadingOverlay(),
        ],
      ),
    );
  }
  
  // 创建一个加载动画覆盖层，类似社交媒体应用
  Widget _buildLoadingOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.8),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '正在加载更多内容...',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // 优化的滚动视图
  Widget _buildOptimizedScrollView(BuildContext context, bool isLoadingMore) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      // 添加性能优化配置
      clipBehavior: Clip.hardEdge, // 使用硬边界裁剪提高性能
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(), // 使用弹性滚动物理效果
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // 拖动时收起键盘
      child: Center(
        child: ConstrainedBox(
          // 3. 限制内容最大宽度
          constraints: const BoxConstraints(maxWidth: 1100), // 保持或调整最大宽度
          child: Padding(
            // 调整内边距，增加呼吸空间
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 使用RepaintBoundary包装整个Acts列表，减少不必要的重绘
                RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 懒加载Acts - 只加载可见Act
                      ...widget.novel.acts
                           .where(_shouldShowAct) // 过滤不需要显示的Acts
                           .map((act) => _buildActSection(act)),
                    ],
                  ),
                ),

                // 添加新Act按钮
                _AddActButton(editorBloc: widget.editorBloc),
                
                // 底部空间，确保底部有足够的滚动空间触发加载
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 判断是否应该显示Act
  bool _shouldShowAct(novel_models.Act act) {
    // 如果是当前活动的Act，始终显示
    if (widget.activeActId == act.id) return true;
    
    // 已加载章节数量
    final loadedChapters = act.chapters.where((chapter) => chapter.scenes.isNotEmpty).length;
    
    // 如果有已加载的章节，则显示
    return loadedChapters > 0;
  }

  Widget _buildActSection(novel_models.Act act) {
    // 统计该Act的章节加载情况
    final totalChapters = act.chapters.length;
    final loadedChapters = act.chapters.where((chapter) => chapter.scenes.isNotEmpty).length;
    
    // 使用ValueKey确保Act正确重建
    final actKey = ValueKey('act_${act.id}');
    
    // 在每个 ActSection 外添加垂直间距
    return Padding(
      key: actKey,
      padding: const EdgeInsets.only(bottom: 48.0), // 增加 Act 之间的间距
      child: ActSection(
        title: act.title,
        chapters: act.chapters
            // 只映射已加载场景的章节或活动章节
            .where((chapter) => chapter.scenes.isNotEmpty || widget.activeChapterId == chapter.id)
            .map((chapter) => _buildChapterSection(act.id, chapter))
            .toList(),
        actId: act.id,
        editorBloc: widget.editorBloc,
        totalChaptersCount: totalChapters,
        loadedChaptersCount: loadedChapters,
      ),
    );
  }

  Widget _buildChapterSection(String actId, novel_models.Chapter chapter) {
    // 如果章节没有场景且不是活动章节，则不显示
    if (chapter.scenes.isEmpty && widget.activeChapterId != chapter.id) {
      return const SizedBox.shrink(); // 不显示空章节
    }
    
    // 使用Key标识章节，确保在章节更新时能够正确重建
    final chapterKey = ValueKey('chapter_${actId}_${chapter.id}');
    
    // 在每个 ChapterSection 外添加垂直间距
    return Padding(
      key: chapterKey,
      padding: const EdgeInsets.only(bottom: 32.0), // 增加 Chapter 之间的间距
      child: _buildChapterContent(actId, chapter), // 将内容提取到新方法
    );
  }

  // 修改构建章节内容的方法，适应空场景的情况
  Widget _buildChapterContent(String actId, novel_models.Chapter chapter) {
    // 使用RepaintBoundary包装章节内容，进一步隔离重绘
    return RepaintBoundary(
      child: ChapterSection(
        title: chapter.title,
        scenes: chapter.scenes.isEmpty ? [] : _buildLazySceneList(actId, chapter),
        actId: actId,
        chapterId: chapter.id,
        editorBloc: widget.editorBloc,
      ),
    );
  }

  // 懒加载场景列表构建
  List<Widget> _buildLazySceneList(String actId, novel_models.Chapter chapter) {
    final scenes = <Widget>[];
    
    // 判断章节是否是当前活动章节
    final isActiveChapter = (widget.activeChapterId == chapter.id);
    
    for (int i = 0; i < chapter.scenes.length; i++) {
      final scene = chapter.scenes[i];
      final isFirst = i == 0;
      final sceneId = '${actId}_${chapter.id}_${scene.id}';
      
      // 判断是否是当前活动场景
      final isActiveScene = (isActiveChapter && widget.activeSceneId == scene.id);
      
      // 创建一个懒加载包装器 - 减少初始化开销
      scenes.add(
        _LazySceneLoader(
          key: ValueKey('loader_$sceneId'),
          sceneId: sceneId,
          actId: actId,
          chapterId: chapter.id,
          scene: scene,
          isFirst: isFirst,
          isActive: isActiveScene,
          sceneControllers: widget.sceneControllers,
          sceneSummaryControllers: widget.sceneSummaryControllers,
          sceneKeys: widget.sceneKeys,
          editorBloc: widget.editorBloc,
          parseDocumentSafely: _parseDocumentSafely,
        ),
      );
    }
    
    return scenes;
  }

  // 安全解析文档内容
  Document _parseDocumentSafely(String content) {
    try {
      if (content.isEmpty) {
        return Document.fromJson([{'insert': '\n'}]);
      }
      
      final dynamic decodedContent = jsonDecode(content);
      
      // 处理不同的内容格式
      if (decodedContent is List) {
        // 如果直接是List，验证格式后使用
        return Document.fromJson(decodedContent);
      } else if (decodedContent is Map<String, dynamic>) {
        // 检查是否是Quill格式的对象（包含ops字段）
        if (decodedContent.containsKey('ops') && decodedContent['ops'] is List) {
          return Document.fromJson(decodedContent['ops'] as List);
        } else {
          // 不是标准Quill格式，记录详细错误信息
          AppLogger.e('EditorMainArea', '解析场景内容失败: 不是有效的Quill文档格式 ${decodedContent.runtimeType}');
          return Document.fromJson([{'insert': '\n'}]);
        }
      } else {
        // 不支持的内容格式
        AppLogger.e('EditorMainArea', '解析场景内容失败: 不支持的内容格式 ${decodedContent.runtimeType}');
        return Document.fromJson([{'insert': '\n'}]);
      }
    } catch (e, stack) {
      AppLogger.e('EditorMainArea', '解析场景内容失败', e);
      // 不再返回"内容加载失败"而是返回空文档，避免显示错误信息
      return Document.fromJson([{'insert': '\n'}]);
    }
  }

  // 尝试滚动到活动场景位置
  void scrollToActiveScene() {
    if (widget.activeActId != null && 
        widget.activeChapterId != null && 
        widget.activeSceneId != null) {
      
      final sceneId = '${widget.activeActId}_${widget.activeChapterId}_${widget.activeSceneId}';
      final key = widget.sceneKeys[sceneId];
      
      if (key != null && key.currentContext != null) {
        // 滚动到当前活动场景位置
        Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.3, // 定位在视口的三分之一处
          duration: const Duration(milliseconds: 300),
        );
        
        AppLogger.i('EditorMainArea', '滚动到活动场景: $sceneId');
      } else {
        AppLogger.w('EditorMainArea', '无法滚动到活动场景，未找到场景: $sceneId');
      }
    }
  }

  // 新增方法：检测可见区域中的空章节并按需加载
  void checkVisibleChaptersAndLoadIfEmpty() {
    // 仅在开发模式下记录可见的空章节，但不主动加载
    if (kDebugMode) {
      final visibleChapterIds = _getVisibleChapterIds();
      
      if (visibleChapterIds.isEmpty) {
        AppLogger.d('EditorMainArea', '无可见章节');
        return;
      }
      
      // 找出可见且为空的章节
      final emptyVisibleChapterIds = <String>[];
      
      for (final chapterId in visibleChapterIds) {
        // 检查章节是否为空
        bool isEmpty = false;
        for (final act in widget.novel.acts) {
          for (final chapter in act.chapters) {
            if (chapter.id == chapterId && chapter.scenes.isEmpty) {
              isEmpty = true;
              break;
            }
          }
          if (isEmpty) break;
        }
        
        if (isEmpty && !_loadingChapterIds.contains(chapterId)) {
          emptyVisibleChapterIds.add(chapterId);
        }
      }
      
      if (emptyVisibleChapterIds.isNotEmpty) {
        AppLogger.d('EditorMainArea', '发现可见的空章节: ${emptyVisibleChapterIds.join(", ")}，等待滚动分页系统加载');
      }
    }
  }
  
  // 获取可见区域内的章节ID列表
  List<String> _getVisibleChapterIds() {
    final result = <String>[];
    
    try {
      // 获取滚动位置信息
      if (!widget.scrollController.hasClients || 
          !widget.scrollController.position.hasViewportDimension) {
        return result;
      }
      
      final scrollPosition = widget.scrollController.position;
      final viewportStart = scrollPosition.pixels;
      final viewportEnd = viewportStart + scrollPosition.viewportDimension;
      
      // 预加载区域 - 当前视口外额外的距离
      const preloadDistance = 500.0;
      
      // 扩展检测范围，包括预加载区域
      final checkStart = viewportStart - preloadDistance;
      final checkEnd = viewportEnd + preloadDistance;
      
      // 遍历所有章节，使用章节的位置信息
      for (final act in widget.novel.acts) {
        for (final chapter in act.chapters) {
          // 创建章节Key的标识符
          final chapterId = chapter.id;
          
          // 使用BuildContext.findRenderObject的替代方法
          // 这里不能直接使用findAllElements
          
          // 如果是活动章节，直接添加
          if (chapterId == widget.activeChapterId) {
            result.add(chapterId);
            continue;
          }
          
          // 如果章节没有场景但是接近当前活动章节，也加入列表
          // 这种方法虽然不精确，但比查找RenderObject更稳定
          if (widget.activeChapterId != null) {
            // 找出活动章节的索引
            int activeChapterIndex = -1;
            int currentChapterIndex = -1;
            
            for (int actIndex = 0; actIndex < widget.novel.acts.length; actIndex++) {
              final currentAct = widget.novel.acts[actIndex];
              for (int chapterIndex = 0; chapterIndex < currentAct.chapters.length; chapterIndex++) {
                final currentChapter = currentAct.chapters[chapterIndex];
                if (currentChapter.id == widget.activeChapterId) {
                  activeChapterIndex = actIndex * 1000 + chapterIndex; // 使用一个足够大的数乘以actIndex
                }
                if (currentChapter.id == chapterId) {
                  currentChapterIndex = actIndex * 1000 + chapterIndex;
                }
              }
            }
            
            // 如果活动章节和当前章节都找到了，计算它们之间的距离
            if (activeChapterIndex >= 0 && currentChapterIndex >= 0) {
              final distance = (currentChapterIndex - activeChapterIndex).abs();
              // 只加载与活动章节相距较近的章节
              if (distance <= 3) { // 只考虑前后3个章节
                result.add(chapterId);
              }
            }
          }
        }
      }
    } catch (e) {
      AppLogger.e('EditorMainArea', '获取可见章节列表出错', e);
    }
    
    return result;
  }

  // 检查章节是否正在加载
  bool _isChapterLoading(String chapterId) {
    return _loadingChapterIds.contains(chapterId);
  }
  
  // 标记章节为正在加载状态
  void _markChapterAsLoading(String chapterId) {
    setState(() {
      _loadingChapterIds.add(chapterId);
    });
    
    // 5秒后自动移除加载状态，防止卡在加载状态
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _loadingChapterIds.contains(chapterId)) {
        setState(() {
          _loadingChapterIds.remove(chapterId);
        });
      }
    });
  }
}

class _AddActButton extends StatelessWidget {
  const _AddActButton({required this.editorBloc});
  final editor_bloc.EditorBloc editorBloc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: OutlinedButton.icon(
          onPressed: () {
            editorBloc.add(const editor_bloc.AddNewAct(title: '新Act'));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加新Act'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            backgroundColor: Colors.white,
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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

// 添加一个新组件，用于懒加载场景
class _LazySceneLoader extends StatefulWidget {
  const _LazySceneLoader({
    Key? key,
    required this.sceneId,
    required this.actId,
    required this.chapterId,
    required this.scene,
    required this.isFirst,
    required this.isActive,
    required this.sceneControllers,
    required this.sceneSummaryControllers,
    required this.sceneKeys,
    required this.editorBloc,
    required this.parseDocumentSafely,
  }) : super(key: key);

  final String sceneId;
  final String actId;
  final String chapterId;
  final novel_models.Scene scene;
  final bool isFirst;
  final bool isActive;
  final Map<String, QuillController> sceneControllers;
  final Map<String, TextEditingController> sceneSummaryControllers;
  final Map<String, GlobalKey> sceneKeys;
  final editor_bloc.EditorBloc editorBloc;
  final Function(String) parseDocumentSafely;

  @override
  State<_LazySceneLoader> createState() => _LazySceneLoaderState();
}

class _LazySceneLoaderState extends State<_LazySceneLoader> {
  bool _isVisible = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // 如果是活动场景，立即初始化
    if (widget.isActive) {
      _initializeControllers();
      _isInitialized = true;
      _isVisible = true;
    } else {
      // 延迟初始化非活动场景
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkVisibility();
      });
    }
  }
  
  @override
  void didUpdateWidget(_LazySceneLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果活动状态变化，检查可见性
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initializeControllers();
        setState(() {
          _isInitialized = true;
          _isVisible = true;
        });
      } else {
        _checkVisibility();
      }
    }
  }
  
  // 检查是否在可视范围内
  void _checkVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // 获取全局Key，如果没有则创建
      if (!widget.sceneKeys.containsKey(widget.sceneId)) {
        widget.sceneKeys[widget.sceneId] = GlobalKey();
      }

      // 创建一个占位的全局Key，用于检测可见性
      final renderContext = context.findRenderObject()?.paintBounds;
      final viewportHeight = MediaQuery.of(context).size.height;
      
      // 如果在视口内，初始化控制器并显示完整内容
      if (renderContext != null) {
        final shouldBeVisible = true; // 简化逻辑，默认显示所有内容
        
        if (shouldBeVisible && !_isInitialized) {
          _initializeControllers();
          setState(() {
            _isInitialized = true;
            _isVisible = true;
          });
        } else if (shouldBeVisible != _isVisible) {
          setState(() {
            _isVisible = shouldBeVisible;
          });
        }
      }
    });
  }
  
  // 初始化控制器
  void _initializeControllers() {
    // 只在控制器不存在时创建
    if (!widget.sceneControllers.containsKey(widget.sceneId)) {
      try {
        widget.sceneControllers[widget.sceneId] = QuillController(
          document: widget.parseDocumentSafely(widget.scene.content),
          selection: const TextSelection.collapsed(offset: 0),
        );

        widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
          text: widget.scene.summary.content,
        );
      } catch (e) {
        AppLogger.e('EditorMainArea', '创建场景控制器失败: ${widget.sceneId}', e);
        widget.sceneControllers[widget.sceneId] = QuillController(
          document: Document.fromJson([
            {'insert': '\n'}
          ]),
          selection: const TextSelection.collapsed(offset: 0),
        );
        widget.sceneSummaryControllers[widget.sceneId] =
            TextEditingController(text: '');
      }
    }
    
    // 确保有GlobalKey
    if (!widget.sceneKeys.containsKey(widget.sceneId)) {
      widget.sceneKeys[widget.sceneId] = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果还没有初始化，先显示占位
    if (!_isInitialized) {
      return _buildPlaceholder();
    }
    
    // 如果初始化了但不可见，显示轻量级占位
    if (!_isVisible && !widget.isActive) {
      return _buildPlaceholder();
    }
    
    // 可见或活动则显示完整场景编辑器
    return RepaintBoundary(
      child: SceneEditor(
        key: widget.sceneKeys[widget.sceneId],
        title: 'Scene ${widget.scene.id.hashCode % 100 + 1}',
        wordCount: '${widget.scene.wordCount} 字',
        isActive: widget.isActive,
        actId: widget.actId,
        chapterId: widget.chapterId,
        sceneId: widget.scene.id,
        isFirst: widget.isFirst,
        controller: widget.sceneControllers[widget.sceneId]!,
        summaryController: widget.sceneSummaryControllers[widget.sceneId]!,
        editorBloc: widget.editorBloc,
      ),
    );
  }
  
  // 构建占位内容
  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      height: 100, // 占位高度
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scene ${widget.scene.id.hashCode % 100 + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.scene.wordCount} 字',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
