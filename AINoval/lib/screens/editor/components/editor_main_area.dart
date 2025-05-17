import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/logger.dart';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/screens/editor/components/act_section.dart';
import 'package:ainoval/screens/editor/components/chapter_section.dart';

import 'package:ainoval/screens/editor/components/volume_navigation_buttons.dart';
import 'package:ainoval/screens/editor/components/fullscreen_loading_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';

// 引入提取出的组件
import 'package:ainoval/screens/editor/components/add_act_button.dart';
import 'package:ainoval/screens/editor/components/virtualized_scene_loader.dart';
import 'package:ainoval/screens/editor/components/loading_overlay.dart';
import 'package:ainoval/screens/editor/components/boundary_indicator.dart';
import 'package:ainoval/screens/editor/utils/document_parser.dart';

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
  
  // 添加章节位置跟踪 - 修改为缓存章节布局信息
  final Map<String, Rect> _chapterLayouts = {}; // 新的：存储章节的 Rect (offset and size)
  bool _novelStructureChanged = true; // 标记小说结构是否变化，需要重新计算布局

  // 添加视口管理相关属性
  final Map<String, bool> _visibleActs = {};
  final Map<String, bool> _visibleChapters = {};
  final Map<String, bool> _renderedScenes = {};
  bool _isScrollingDrivenFocus = false; 
  
  bool _isFullscreenLoading = false;
  String _loadingMessage = '正在加载...';
  
  double _estimatedPageHeight = 800.0; 
  double get _preloadDistance => _estimatedPageHeight * 4.0; // 从 2.5 增加到 4.0
  ScrollMetrics? _lastReportedPosition;
  final ValueNotifier<List<String>> _visibleItemsNotifier = ValueNotifier<List<String>>([]);
  
  String? _focusChapterId; 
  
  bool _isNavigatingToAct = false;
  String? _targetActId;
  String? _targetChapterId;
  
  bool _isLoadingPreviousAct = false;
  bool _isLoadingNextAct = false;

  // 用于检测结构性变化的计数器
  int? _previousActsCount;
  int? _previousTotalChaptersCount;
  int? _previousTotalScenesCount;
  
  @override
  void initState() {
    super.initState();
    
    _setupBlocListener();
    
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // 确保组件仍然挂载
        _calculatePageHeight();
        _scheduleChapterLayoutCalculation(); // 初始计算章节布局
        
        Timer.periodic(const Duration(minutes: 10), (timer) {
          if (mounted) {
            _cleanupInvisibleScenes();
          } else {
            timer.cancel();
          }
        });
        
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            // _updateVisibleItemsBasedOnActiveScene(); // 改为基于缓存
            _updateVisibleItemsBasedOnCache();
            // _updateAllChapterPositions(); // 已被 _updateAllChapterLayouts 替代
            _updateFocusChapterBasedOnCache(true); // Force update on init
          }
        });
      }
    });
    
    _setupScrollListener();
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusUpdateTimer?.cancel();
    _layoutCalculationDebounceTimer?.cancel();
    super.dispose();
  }
  
  Timer? _focusUpdateTimer;
  Timer? _layoutCalculationDebounceTimer;
  
  bool _enforceSingleActMode = true;
  
  final Map<String, DateTime> _lastVisibleTime = {};
  
  void _scheduleChapterLayoutCalculation() {
    _layoutCalculationDebounceTimer?.cancel();
    _layoutCalculationDebounceTimer = Timer(const Duration(milliseconds: 150), () { // 稍作延迟以等待布局稳定
        if (mounted) {
            _updateAllChapterLayouts();
            _updateVisibleItemsBasedOnCache(); 
            _updateFocusChapterBasedOnCache(); 
        }
    });
  }

  void _setupBlocListener() {
    widget.editorBloc.stream.listen((state) {
      if (!mounted) return;
      
      bool structurePotentiallyChanged = false;
      
      if (state is editor_bloc.EditorLoaded) {
        int currentActsCount = state.novel.acts.length;
        int currentTotalChaptersCount = 0;
        int currentTotalScenesCount = 0;

        for (final act in state.novel.acts) {
          currentTotalChaptersCount += act.chapters.length;
          for (final chapter in act.chapters) {
            currentTotalScenesCount += chapter.scenes.length;
          }
        }

        if (_previousActsCount != null && _previousActsCount != currentActsCount) {
          structurePotentiallyChanged = true;
          AppLogger.i('EditorMainArea', 'BlocListener: Acts count changed $_previousActsCount -> $currentActsCount');
        }
        if (_previousTotalChaptersCount != null && _previousTotalChaptersCount != currentTotalChaptersCount) {
          structurePotentiallyChanged = true;
          AppLogger.i('EditorMainArea', 'BlocListener: Total chapters count changed $_previousTotalChaptersCount -> $currentTotalChaptersCount');
        }
        // 场景数量变化也可能影响布局，但更细微，暂时以章节为主要依据
        // if (_previousTotalScenesCount != null && _previousTotalScenesCount != currentTotalScenesCount) {
        //   structurePotentiallyChanged = true;
        // }

        _previousActsCount = currentActsCount;
        _previousTotalChaptersCount = currentTotalChaptersCount;
        _previousTotalScenesCount = currentTotalScenesCount;

        if (structurePotentiallyChanged) {
          AppLogger.i('EditorMainArea', 'BlocListener: Novel structure potentially changed, scheduling layout recalculation.');
          _novelStructureChanged = true; // 标记需要重新计算布局
          _scheduleChapterLayoutCalculation();
        } else if (!state.isLoading) {
          // 如果只是加载状态变化，但结构未变，则可能只需要更新可见项
          AppLogger.i('EditorMainArea', 'BlocListener: Load complete (no structural change), refreshing visible items.');
          if (widget.scrollController.hasClients) {
            _updateVisibleItemsBasedOnCache();
          }
          _updateFocusChapterBasedOnCache(true); // 强制更新焦点，因为activeChapterId可能已改变
        }

        // 原有的UI刷新逻辑，例如当焦点由BLoC改变时
        if (state.focusChapterId != null && _focusChapterId != state.focusChapterId) {
            AppLogger.i('EditorMainArea', 'BlocListener: focusChapterId updated by BLoC to ${state.focusChapterId}. Current local focus is $_focusChapterId.');
            // 如果BLoC的焦点与本地计算的焦点不同，且不是由滚动主导的，则采纳BLoC的焦点
            if (!_isScrollingDrivenFocus) {
                 _focusChapterId = state.focusChapterId;
                 // 可能需要滚动到该章节
                 // scrollToChapter(state.activeActId, state.focusChapterId);
            }
        }

      }
    });
  }

  void _updateAllChapterLayouts() {
    if (!mounted || !widget.scrollController.hasClients || !_novelStructureChanged) {
        // AppLogger.d('EditorMainArea', 'Skipping chapter layout calculation - not mounted, no clients, or no structure change.');
        return;
    }

    AppLogger.d('EditorMainArea', 'Recalculating all chapter layouts...');
    _chapterLayouts.clear();
    
    // 获取Scrollable的RenderObject作为共同的祖先
    // final scrollableRenderObject = Scrollable.of(context)?.context.findRenderObject(); // 旧的方式

    if (!widget.scrollController.hasClients) {
        AppLogger.w('EditorMainArea', 'No scroll client for layout calculation.');
        _novelStructureChanged = false; // Prevent re-triggering if this is the issue
        return;
    }
    final BuildContext? scrollableContext = widget.scrollController.position.context.storageContext;

    if (scrollableContext == null) {
        AppLogger.w('EditorMainArea', 'Scrollable storageContext is null for layout calculation.');
        _novelStructureChanged = false;
        return;
    }

    final ScrollableState? scrollableState = Scrollable.of(scrollableContext);
    if (scrollableState == null) {
        AppLogger.w('EditorMainArea', 'Scrollable.of(scrollableContext) returned null for layout calculation.');
        _novelStructureChanged = false;
        return;
    }
    final RenderObject? scrollableRenderObject = scrollableState.context.findRenderObject();

    if (scrollableRenderObject == null) {
        AppLogger.w('EditorMainArea', 'Scrollable RenderObject is null for layout calculation.');
        _novelStructureChanged = false;
        return;
    }

    for (final act in widget.novel.acts) {
        for (final chapter in act.chapters) {
            final chapterKeyString = 'chapter_${act.id}_${chapter.id}';
            final globalKey = widget.sceneKeys[chapterKeyString];
            if (globalKey?.currentContext != null) {
                final renderBox = globalKey!.currentContext!.findRenderObject() as RenderBox?;
                if (renderBox != null && renderBox.hasSize) {
                    try {
                      // 计算相对于Scrollable视口的位置
                      final position = renderBox.localToGlobal(Offset.zero, ancestor: scrollableRenderObject);
                      final size = renderBox.size;
                      _chapterLayouts[chapter.id] = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
                    } catch (e) {
                      AppLogger.e('EditorMainArea', 'Error calculating layout for chapter ${chapter.id}: $e');
                    }
                } else {
                   // AppLogger.w('EditorMainArea', 'RenderBox for chapter ${chapter.id} is null or has no size.');
                }
            } else {
                // AppLogger.w('EditorMainArea', 'GlobalKey context for chapter ${chapter.id} is null.');
            }
        }
    }
    _novelStructureChanged = false; // Reset flag after calculation
    AppLogger.d('EditorMainArea', 'Chapter layouts updated: ${_chapterLayouts.length} entries found.');
  }
  
  void _forceRefreshRenderedScenes() {
    if (!mounted) {
      AppLogger.w('EditorMainArea', '尝试强制刷新场景时组件已卸载');
      return;
    }
    
    AppLogger.i('EditorMainArea', '强制刷新已渲染场景...');
    
    final oldRenderedCount = _renderedScenes.length;
    
    setState(() {
      _renderedScenes.clear();
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      AppLogger.i('EditorMainArea', '延迟更新章节位置...');
      // _updateAllChapterPositions(); // 改为布局计算
      _novelStructureChanged = true; // Force layout recalc
      _scheduleChapterLayoutCalculation();
      
      AppLogger.i('EditorMainArea', '场景刷新完成: 清理前渲染场景数 $oldRenderedCount，当前渲染场景数 ${_renderedScenes.length}');
    });
  }

  void _setupScrollListener() {
    widget.scrollController.addListener(() {
      _isScrollingDrivenFocus = true; 
      if (_focusUpdateTimer == null || !_focusUpdateTimer!.isActive) {
        _focusUpdateTimer = Timer(const Duration(milliseconds: 200), () { // 保持200ms节流
          if (mounted) {
            // _updateAllChapterPositions(); // 已被 _updateAllChapterLayouts 替代，且按需调用
            _updateFocusChapterBasedOnCache(); 
            _updateVisibleItemsBasedOnCache();
            _isScrollingDrivenFocus = false; 
          }
        });
      }
      
      if (_cleanupTimer == null || !_cleanupTimer!.isActive) {
        _cleanupTimer = Timer(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _cleanupUnusedControllers();
          }
        });
      }
      
      _checkScrollBoundariesForLoading();
    });
  }
  
  Timer? _cleanupTimer;
  
  void _cleanupUnusedControllers() {
    if (!mounted || !_enforceSingleActMode) return;
    
    String? focusActId = _getCurrentFocusActId();
    if (focusActId == null) return;
    
    final controllersToRemove = <String>[];
    final now = DateTime.now();
    int removedCount = 0;
    
    for (final entry in _lastVisibleTime.entries) {
      final sceneId = entry.key;
      final lastSeenTime = entry.value;
      
      final parts = sceneId.split('_');
      if (parts.length < 3) continue;
      
      final actId = parts[0];
      
      if (actId != focusActId && now.difference(lastSeenTime).inSeconds > 30) {
        controllersToRemove.add(sceneId);
      }
      else if (now.difference(lastSeenTime).inMinutes > 5) {
        controllersToRemove.add(sceneId);
      }
    }
    
    for (final sceneId in controllersToRemove) {
      if (widget.sceneControllers.containsKey(sceneId)) {
        try {
          widget.sceneControllers[sceneId]?.dispose();
          widget.sceneControllers.remove(sceneId);
          
          widget.sceneSummaryControllers[sceneId]?.dispose();
          widget.sceneSummaryControllers.remove(sceneId);
          
          _renderedScenes.remove(sceneId);
          _lastVisibleTime.remove(sceneId);
          
          removedCount++;
        } catch (e) {
          AppLogger.e('EditorMainArea', '清理控制器失败: $sceneId', e);
        }
      }
    }
    
    if (removedCount > 0) {
      AppLogger.i('EditorMainArea', '强化清理：移除了 $removedCount 个非当前Act的场景控制器');
    }
  }
  
  void _cleanupInvisibleScenes() {
    if (!mounted) return;
    
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    if (_enforceSingleActMode) {
      String? focusActId = _getCurrentFocusActId();
      if (focusActId != null) {
        for (final sceneId in _renderedScenes.keys) {
          final parts = sceneId.split('_');
          if (parts.length >= 3 && parts[0] != focusActId) {
            if (_lastVisibleTime.containsKey(sceneId) && 
                now.difference(_lastVisibleTime[sceneId]!).inMinutes >= 1) {
              keysToRemove.add(sceneId);
            }
          }
        }
      }
    }
    
    _renderedScenes.forEach((sceneId, isVisible) {
      if (!isVisible && 
          _lastVisibleTime.containsKey(sceneId) &&
          now.difference(_lastVisibleTime[sceneId]!).inMinutes > 5) {
        keysToRemove.add(sceneId);
      }
    });
    
    for (final sceneId in keysToRemove) {
      widget.sceneControllers.remove(sceneId);
      widget.sceneSummaryControllers.remove(sceneId);
      _renderedScenes.remove(sceneId);
      _lastVisibleTime.remove(sceneId);
    }
    
    if (keysToRemove.isNotEmpty) {
      AppLogger.i('EditorMainArea', '定期清理：移除了 ${keysToRemove.length} 个长时间不可见场景');
    }
  }
  

  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final veryLightGrey = Colors.grey.shade100; 

    bool isLoadingMore = false;
    if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
      final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
      isLoadingMore = state.isLoading;
    }

    return BlocListener<editor_bloc.EditorBloc, editor_bloc.EditorState>(
      bloc: widget.editorBloc,
      listener: (context, state) {
        // _setupBlocListener 中已包含大部分逻辑，这里可以简化或移除重复部分
        // 主要保留用于响应非结构性但需要UI即时响应的状态变化
        if (state is editor_bloc.EditorLoaded) {
          if (!state.isLoading && _novelStructureChanged) {
            // 如果在加载完成后发现结构已标记为更改（可能由其他事件触发），则重新计算
            _scheduleChapterLayoutCalculation();
          }
        }
      },
      listenWhen: (previous, current) {
        // 这个 listenWhen 可以简化，因为结构变化已在 _setupBlocListener 中处理
        // 主要关注加载状态、边界标志和保存状态的变化
        if (previous is editor_bloc.EditorLoaded && current is editor_bloc.EditorLoaded) {
          if (previous.isLoading != current.isLoading) return true;
          if (previous.hasReachedEnd != current.hasReachedEnd || 
              previous.hasReachedStart != current.hasReachedStart) return true;
          if (previous.isSaving != current.isSaving) return true;
          // 焦点章节变化由 BLoC 主导时，也可能需要刷新
          if (previous.focusChapterId != current.focusChapterId && !_isScrollingDrivenFocus) return true;

        }
        // 如果 novel 对象本身发生了变化 (例如通过引用比较)，也应该重建
        if (previous is editor_bloc.EditorLoaded && current is editor_bloc.EditorLoaded) {
            if (!identical(previous.novel, current.novel)) {
                 _novelStructureChanged = true; // Mark structure as changed if novel instance differs
                 return true;
            }
        }
        return false;
      },
      child: Stack(
        children: [
          Container(
            color: veryLightGrey,
            child: _buildVirtualizedScrollView(context, isLoadingMore),
          ),
          if (_isFullscreenLoading)
            FullscreenLoadingOverlay(
              loadingMessage: _loadingMessage,
              showProgressIndicator: true,
            ),
        ],
      ),
    );
  }
  
  Widget _buildVirtualizedScrollView(BuildContext context, bool isLoadingMore) {
    final hasReachedStart = widget.editorBloc.state is editor_bloc.EditorLoaded && 
                           (widget.editorBloc.state as editor_bloc.EditorLoaded).hasReachedStart;
    final hasReachedEnd = widget.editorBloc.state is editor_bloc.EditorLoaded && 
                         (widget.editorBloc.state as editor_bloc.EditorLoaded).hasReachedEnd;
    
    final isFirstAct = _isInFirstAct();
    final isLastAct = _isInLastAct();
    
    AppLogger.i('EditorMainArea', '当前卷状态：isFirstAct=$isFirstAct, isLastAct=$isLastAct, hasReachedStart=$hasReachedStart, hasReachedEnd=$hasReachedEnd');
    
    return CustomScrollView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      clipBehavior: Clip.hardEdge,
      slivers: [
        SliverToBoxAdapter(
          child: VolumeNavigationButtons(
            isTop: true,
            hasReachedStart: hasReachedStart,
            hasReachedEnd: false,
            isLoadingMore: _isLoadingPreviousAct,
            isFirstAct: isFirstAct,
            isLastAct: false,
            onPreviousAct: (isFirstAct && hasReachedStart) ? null : _navigateToPreviousAct,
            onNextAct: () {}, 
            onAddNewAct: () {}, 
          ),
        ),
        
        if (hasReachedStart)
          SliverToBoxAdapter(child: _buildEndOfContentIndicator(true)),
        
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<List<String>>(
                        valueListenable: _visibleItemsNotifier,
                        builder: (context, visibleItems, child) {
                          return Column(
                            children: [
                              ...widget.novel.acts
                                  .where((act) => _shouldRenderAct(act))
                                  .map((act) => _buildVirtualizedActSection(act, visibleItems)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        if (hasReachedEnd)
          SliverToBoxAdapter(child: _buildEndOfContentIndicator(false)),
          
        SliverToBoxAdapter(
          child: VolumeNavigationButtons(
            isTop: false,
            hasReachedStart: false,
            hasReachedEnd: hasReachedEnd,
            isLoadingMore: _isLoadingNextAct,
            isFirstAct: false,
            isLastAct: isLastAct,
            onPreviousAct: () {}, 
            onNextAct: _navigateToNextAct,
            onAddNewAct: _addNewAct,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEndOfContentIndicator(bool isTop) {
    return BoundaryIndicator(isTop: isTop);
  }
  
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      _lastReportedPosition = notification.metrics;
      // _updateVisibleItems 和 _updateFocusChapter 由 _setupScrollListener 中的节流调用处理
    }
    return false;
  }
  
  // 使用缓存的布局信息更新可见项
  void _updateVisibleItemsBasedOnCache() {
      if (!mounted || !widget.scrollController.hasClients || _chapterLayouts.isEmpty) {
          // AppLogger.d('EditorMainArea', 'Skipping visible items update - conditions not met.');
          return;
      }

      final scrollPosition = widget.scrollController.position;
      final viewportStart = scrollPosition.pixels;
      final viewportEnd = viewportStart + scrollPosition.viewportDimension;
      
      final double preloadStart = viewportStart - _preloadDistance;
      final double preloadEnd = viewportEnd + _preloadDistance;

      final Set<String> newVisibleItems = {};
      int visibleActCount = 0;
      int visibleChapterCount = 0;
      int visibleSceneCount = 0;
      
      // AppLogger.d('EditorMainArea', 'Updating visible items based on cache. Preload: $preloadStart - $preloadEnd');

      for (final act in widget.novel.acts) {
          // Act的可见性判断可以粗略一些，或者也为其创建GlobalKey和缓存Rect
          // 简单起见，如果其下有任何可见章节，则认为Act可见
          bool isActConsideredVisible = false;

          for (final chapter in act.chapters) {
              final chapterRect = _chapterLayouts[chapter.id];
              if (chapterRect != null) {
                  // 使用缓存的章节顶部和底部（相对于Scrollable）
                  final chapterTop = chapterRect.top;
                  final chapterBottom = chapterRect.bottom;
                  
                  final bool isChapterVisibleInPreload = chapterBottom >= preloadStart && chapterTop <= preloadEnd;

                  if (isChapterVisibleInPreload) {
                      isActConsideredVisible = true;
                      newVisibleItems.add('chapter_${act.id}_${chapter.id}');
                      visibleChapterCount++;
                      _visibleChapters['${act.id}_${chapter.id}'] = true;
                      
                      for (final scene in chapter.scenes) {
                          final sceneId = '${act.id}_${chapter.id}_${scene.id}';
                          newVisibleItems.add(sceneId); // 标记场景的 "可见性" key
                          visibleSceneCount++;
                          _lastVisibleTime[sceneId] = DateTime.now(); // 更新最后可见时间
                          _renderedScenes[sceneId] = true; // 标记为已渲染/应渲染
                          // AppLogger.d('EditorMainArea', 'Scene ${scene.id} in visible chapter, marked for render.');
                      }
                  } else {
                      _visibleChapters['${act.id}_${chapter.id}'] = false;
                  }
              } else {
                  // AppLogger.w('EditorMainArea', 'No layout cache for chapter ${chapter.id}');
              }
          }

          if (isActConsideredVisible) {
              newVisibleItems.add('act_${act.id}');
              visibleActCount++;
              _visibleActs[act.id] = true;
              // AppLogger.d('EditorMainArea', 'Act ${act.title} considered visible.');
          } else {
              _visibleActs[act.id] = false;
          }
      }
      
      // AppLogger.i('EditorMainArea', 'Visible items stats (cache) - Acts: $visibleActCount, Chapters: $visibleChapterCount, Scenes: $visibleSceneCount');
      
      if (!const DeepCollectionEquality().equals(
          _visibleItemsNotifier.value.toSet(), newVisibleItems.toSet())) { // Compare sets for order-insensitivity
        AppLogger.i('EditorMainArea', 'Visible items changed (cache), updating UI. New count: ${newVisibleItems.length}');
        _visibleItemsNotifier.value = newVisibleItems.toList();
      }
  }
  
  bool _shouldRenderAct(novel_models.Act act) {
    final String actId = act.id;
    
    final hasRendered = _renderedScenes.entries.any((entry) => entry.key.startsWith('${actId}_'));
    
    if (_isLoadingPreviousAct || _isLoadingNextAct) {
      if (_targetActId != null && actId == _targetActId) {
        AppLogger.d('EditorMainArea', '允许渲染目标卷: $actId (正在加载)');
        return true;
      } else if (widget.activeActId != null && actId == widget.activeActId) {
        AppLogger.d('EditorMainArea', '允许渲染当前焦点卷: $actId (正在加载其他卷)');
        return true;
      } else {
        if (_enforceSingleActMode) {
          AppLogger.d('EditorMainArea', '加载状态下严格单卷模式: 阻止渲染非目标卷: $actId');
          return false;
        }
        return hasRendered;
      }
    }
    
    if (_enforceSingleActMode) {
      final String? focusActId = _getCurrentFocusActId(); // 使用 _getCurrentFocusActId 获取当前应关注的 Act
      
      if (focusActId == null) { // 初始加载或无焦点时，允许渲染
        return true;
      }
      
      final bool isCurrentFocusAct = (actId == focusActId);
      
      if (!isCurrentFocusAct) {
        // AppLogger.d('EditorMainArea', '严格单卷模式: 阻止渲染非焦点卷: $actId (当前焦点卷: $focusActId)');
      }
      return isCurrentFocusAct;
    }
    
    return true; // 非严格模式下始终渲染
  }
  
  String? _getCurrentFocusActId() {
    // 优先使用BLoC提供的activeActId，因为它通常代表了用户的意图或最新的状态
    if (widget.activeActId != null) return widget.activeActId;

    // 其次，如果本地计算的焦点章节存在，则查找它所在的Act
    if (_focusChapterId != null) {
      for (final currentAct in widget.novel.acts) {
        if (currentAct.chapters.any((chapter) => chapter.id == _focusChapterId)) {
          return currentAct.id;
        }
      }
    }
    // 如果都没有，可能返回第一个Act的ID或null
    return widget.novel.acts.isNotEmpty ? widget.novel.acts.first.id : null;
  }
  
  Widget _buildVirtualizedActSection(novel_models.Act act, List<String> visibleItems) {
    if (!widget.sceneKeys.containsKey('act_${act.id}')) {
      widget.sceneKeys['act_${act.id}'] = GlobalKey();
    }
    
    final actIndex = widget.novel.acts.indexOf(act) + 1;
    final totalChaptersCount = act.chapters.length;
    final loadedChaptersCount = act.chapters.length; //  全量加载模式

    return ActSection(
      key: widget.sceneKeys['act_${act.id}'], // Act的Key
      title: act.title,
      actId: act.id,
      editorBloc: widget.editorBloc,
      actIndex: actIndex, 
      totalChaptersCount: totalChaptersCount, 
      loadedChaptersCount: loadedChaptersCount, 
      chapters: [
        ...act.chapters.map((chapter) {
          final chapterKeyString = 'chapter_${act.id}_${chapter.id}';
          if (!widget.sceneKeys.containsKey(chapterKeyString)) {
            widget.sceneKeys[chapterKeyString] = GlobalKey();
          }
          
          final chapterIndex = act.chapters.indexOf(chapter) + 1;

          // isParentVisuallyNearby 的判断基于 visibleItems (由 _updateVisibleItemsBasedOnCache 更新)
          bool areScenesInChapterVisuallyNearby = 
              visibleItems.contains('chapter_${act.id}_${chapter.id}') ||
              chapter.id == widget.activeChapterId || // BLoC 活动章节
              chapter.id == _focusChapterId; // 本地计算的焦点章节

          return ChapterSection(
            key: widget.sceneKeys[chapterKeyString], // Chapter的Key
            title: chapter.title,
            chapterId: chapter.id,
            actId: act.id,
            editorBloc: widget.editorBloc,
            chapterIndex: chapterIndex, 
            scenes: [
              ...chapter.scenes.asMap().entries.map((entry) {
                final index = entry.key;
                final scene = entry.value;
                final sceneIdForVSL = '${act.id}_${chapter.id}_${scene.id}';
                
                return VirtualizedSceneLoader(
                  key: ValueKey('vsl_$sceneIdForVSL'),
                  sceneId: scene.id,
                  actId: act.id,
                  chapterId: chapter.id,
                  scene: scene,
                  isFirst: index == 0,
                  isActive: scene.id == widget.activeSceneId && chapter.id == widget.activeChapterId && act.id == widget.activeActId,
                  sceneControllers: widget.sceneControllers,
                  sceneSummaryControllers: widget.sceneSummaryControllers,
                  sceneKeys: widget.sceneKeys, // 传递 sceneKeys 给 VSL
                  editorBloc: widget.editorBloc,
                  parseDocumentSafely: DocumentParser.parseDocumentSafely,
                  sceneIndex: index + 1,
                  isParentVisuallyNearby: areScenesInChapterVisuallyNearby,
                  onVisibilityChanged: (isVisible) {
                    final sceneIdKey = '${act.id}_${chapter.id}_${scene.id}';
                    _renderedScenes[sceneIdKey] = isVisible;
                    if (isVisible) {
                      _lastVisibleTime[sceneIdKey] = DateTime.now();
                    }
                  },
                );
              }).toList(),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  bool _isInFirstAct() {
    final currentFocusActId = _getCurrentFocusActId();
    if (currentFocusActId == null || widget.novel.acts.isEmpty) {
      return true; 
    }
    return currentFocusActId == widget.novel.acts.first.id;
  }
  
  bool _isInLastAct() {
    final currentFocusActId = _getCurrentFocusActId();
    if (currentFocusActId == null || widget.novel.acts.isEmpty) {
      return true; 
    }
    return currentFocusActId == widget.novel.acts.last.id;
  }
  
  void _navigateToPreviousAct() {
    if (!mounted) return;
    AppLogger.i('EditorMainArea', '尝试导航到上一卷');
    final currentFocusActId = _getCurrentFocusActId();
    if (currentFocusActId == null) {
      AppLogger.w('EditorMainArea', '无法导航到上一卷：当前没有活动/焦点卷');
      return;
    }
    final currentActIndex = widget.novel.acts.indexWhere((act) => act.id == currentFocusActId);
    if (currentActIndex > 0) {
      _navigateToAct(widget.novel.acts[currentActIndex - 1].id);
    } else {
      AppLogger.i('EditorMainArea', '已经是第一卷，无法继续向上导航');
    }
  }
  
  void _navigateToNextAct() {
    if (!mounted) return;
    AppLogger.i('EditorMainArea', '尝试导航到下一卷');
    final currentFocusActId = _getCurrentFocusActId();
     if (currentFocusActId == null) {
      AppLogger.w('EditorMainArea', '无法导航到下一卷：当前没有活动/焦点卷');
      return;
    }
    final currentActIndex = widget.novel.acts.indexWhere((act) => act.id == currentFocusActId);
    if (currentActIndex != -1 && currentActIndex < widget.novel.acts.length - 1) {
      _navigateToAct(widget.novel.acts[currentActIndex + 1].id);
    } else {
      AppLogger.i('EditorMainArea', '已经是最后一卷，无法继续向下导航');
    }
  }
  
  void _navigateToAct(String actId) {
    if (!mounted) return;
    
    AppLogger.i('EditorMainArea', '导航到卷: $actId');
    
    _targetActId = actId;
    _isNavigatingToAct = true;
    
    final targetAct = widget.novel.acts.firstWhereOrNull((act) => act.id == actId);
    if (targetAct == null || targetAct.chapters.isEmpty) {
      AppLogger.w('EditorMainArea', '目标卷 $actId 不存在或没有章节');
      _isNavigatingToAct = false;
      _targetActId = null;
      if(mounted) setState(() {});
      return;
    }
    
    _targetChapterId = targetAct.chapters.first.id;
    
    // 让 BLoC 更新 activeActId 和 activeChapterId (可能还有 focusChapterId)
    // BLoC 应该负责更新状态，然后 UI 响应这些状态变化进行滚动
    widget.editorBloc.add(editor_bloc.SetActiveChapter(
      actId: actId,
      chapterId: _targetChapterId!,
      shouldScroll: true, // 指示 BLoC 或 Controller 进行滚动
    ));
    // BLoC 状态更新后，新的 activeActId 会通过 _getCurrentFocusActId 反映到 _shouldRenderAct
    // 并且新的 focusChapterId 会被 scrollToChapter 使用

    // 标记UI正在加载，以便显示加载指示器
    final currentFocusActId = _getCurrentFocusActId();
    if (currentFocusActId != null && _targetActId != currentFocusActId) {
        final targetIndex = widget.novel.acts.indexWhere((a) => a.id == _targetActId);
        final currentIndex = widget.novel.acts.indexWhere((a) => a.id == currentFocusActId);
        if (targetIndex < currentIndex) {
            _isLoadingPreviousAct = true;
        } else {
            _isLoadingNextAct = true;
        }
    }
    if(mounted) setState(() {}); // 更新UI以显示加载状态

    // 滚动逻辑现在应该由 BLoC 状态变化触发，或者通过 EditorScreenController 协调
    // 这里移除直接的 Scrollable.ensureVisible 调用，依赖 BLoC 更新后的UI重建和可能的自动滚动
    
    // 延迟清除导航状态，等待滚动和UI更新完成
    Future.delayed(const Duration(milliseconds: 800), () { // 增加延迟给滚动留足时间
      if (mounted) {
        setState(() {
          _isNavigatingToAct = false;
          _targetActId = null;
          _targetChapterId = null;
          _isLoadingPreviousAct = false;
          _isLoadingNextAct = false;
        });
      }
    });
  }
  
  void _addNewAct() {
    if (!mounted) return;
    AppLogger.i('EditorMainArea', '添加新卷');
    final editorState = widget.editorBloc.state;
    if (editorState is! editor_bloc.EditorLoaded) {
      AppLogger.w('EditorMainArea', '无法添加新卷：编辑器尚未加载');
      return;
    }
    widget.editorBloc.add(editor_bloc.AddNewAct(
      title: '新卷 ${widget.novel.acts.length + 1}', // 使用更简洁的默认标题
    ));
  }
  
  // _updateAllChapterPositions 已被 _updateAllChapterLayouts 替代
  
  void _calculatePageHeight() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final viewportHeight = widget.scrollController.position.viewportDimension;
    if (viewportHeight > 100) { 
      _estimatedPageHeight = viewportHeight;
      AppLogger.d('EditorMainArea', '更新估计页面高度: $_estimatedPageHeight');
    }
  }
  
  // _updateVisibleItemsBasedOnActiveScene 已被 _updateVisibleItemsBasedOnCache 替代和合并逻辑
  
  // 使用缓存的布局信息更新焦点章节
  void _updateFocusChapterBasedOnCache([bool forceUpdate = false]) {
      if (!widget.scrollController.hasClients || !mounted || _chapterLayouts.isEmpty) {
          // AppLogger.d('EditorMainArea', 'Skipping focus chapter update - conditions not met.');
          return;
      }

      final editorState = widget.editorBloc.state;
      String? blocIntendedFocusId;
      if (editorState is editor_bloc.EditorLoaded) {
          blocIntendedFocusId = editorState.focusChapterId ?? editorState.activeChapterId;
      }

      // 如果强制更新，并且BLoC有指定的焦点ID，则优先使用BLoC的焦点
      if (forceUpdate && blocIntendedFocusId != null) {
          bool blocFocusIsValidInNovel = _chapterLayouts.containsKey(blocIntendedFocusId);
          if (blocFocusIsValidInNovel) {
              // AppLogger.i('EditorMainArea', '[_updateFocusChapter forceUpdate] Adopting BLoC intended focusChapterId: $blocIntendedFocusId');
              if (_focusChapterId != blocIntendedFocusId) {
                  _focusChapterId = blocIntendedFocusId;
                  if (mounted) setState(() {}); // 更新UI以反映焦点变化
              }
              return; // 使用了BLoC的焦点，直接返回
          }
      }

      final scrollMiddle = widget.scrollController.offset + (widget.scrollController.position.viewportDimension / 2);
      String? closestChapterId;
      double minDistance = double.infinity;

      _chapterLayouts.forEach((chapterId, rect) {
          // 使用章节的中心点进行比较
          final chapterCenterY = rect.top + rect.height / 2;
          final distance = (chapterCenterY - scrollMiddle).abs();
          
          if (distance < minDistance) {
              minDistance = distance;
              closestChapterId = chapterId;
          }
      });
      
      if (closestChapterId != null && (forceUpdate || _focusChapterId != closestChapterId)) {
          final prevFocusChapterId = _focusChapterId;
          _focusChapterId = closestChapterId;
          // AppLogger.i('EditorMainArea', '[_updateFocusChapterBasedOnCache] Focus chapter updated to: $_focusChapterId (distance: $minDistance)');
          
          if (_isScrollingDrivenFocus && prevFocusChapterId != _focusChapterId) {
              // AppLogger.i('EditorMainArea', '[_updateFocusChapterBasedOnCache] Scrolling driven focus change: $prevFocusChapterId -> $_focusChapterId');
              
              if (editorState is editor_bloc.EditorLoaded && _focusChapterId != null) {
                  String? actIdForFocusChapter = editorState.novel.acts.firstWhereOrNull((act) => act.chapters.any((ch) => ch.id == _focusChapterId))?.id;
                  
                  if (actIdForFocusChapter != null) {
                      widget.editorBloc.add(editor_bloc.SetFocusChapter(
                          chapterId: _focusChapterId!,
                          // actId: actIdForFocusChapter, // SetFocusChapter可能不需要actId，看其定义
                      ));
                       // 通常 SetFocusChapter 后会触发 SetActiveChapter
                       // widget.editorBloc.add(editor_bloc.SetActiveChapter(
                       //   actId: actIdForFocusChapter,
                       //   chapterId: _focusChapterId!,
                       //   shouldScroll: false, 
                       // ));
                  }
              }
          }
          if (mounted) setState(() {}); // 更新UI
      }
  }
  
  void _checkScrollBoundariesForLoading() {
    // 全量加载模式下，此方法逻辑可以简化或移除，因为没有动态分页加载
    // 但保留对 hasReachedStart/End 的检查和更新是有益的
    if (!widget.scrollController.hasClients || _chapterLayouts.isEmpty) return;

    final state = widget.editorBloc.state;
    if (state is! editor_bloc.EditorLoaded) return;

    final offset = widget.scrollController.offset;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final minScroll = widget.scrollController.position.minScrollExtent;
    final viewportHeight = widget.scrollController.position.viewportDimension;
    final dynamicPreloadDistance = viewportHeight * 0.3; // 较小的阈值用于边界判断

    // 检查是否滚动到非常接近顶部
    if (offset <= minScroll + dynamicPreloadDistance && !state.hasReachedStart) {
        // 进一步确认是否真的是内容的开始
        final firstChapterId = widget.novel.acts.firstOrNull?.chapters.firstOrNull?.id;
        if (_focusChapterId == firstChapterId || _chapterLayouts.keys.first == _focusChapterId) { // 粗略判断
             AppLogger.i('EditorMainArea', 'Near top & focus on first chapter, setting hasReachedStart=true');
             widget.editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedStart: true));
        }
    }

    // 检查是否滚动到非常接近底部
    if (offset >= maxScroll - dynamicPreloadDistance && !state.hasReachedEnd) {
        final lastChapterId = widget.novel.acts.lastOrNull?.chapters.lastOrNull?.id;
         if (_focusChapterId == lastChapterId || _chapterLayouts.keys.last == _focusChapterId) { // 粗略判断
            AppLogger.i('EditorMainArea', 'Near bottom & focus on last chapter, setting hasReachedEnd=true');
            widget.editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedEnd: true));
        }
    }
  }
  
  
  void refreshUI() {
    if (mounted) {
      setState(() {
        AppLogger.i('EditorMainArea', '执行UI刷新 (manual)');
        // 强制重新计算布局和可见项
        _novelStructureChanged = true;
        _scheduleChapterLayoutCalculation();
      });
    }
  }

  void scrollToActiveScene() {
    // 滚动到活动场景的逻辑应该由EditorScreenController或EditorBloc协调，
    // 它们拥有更全局的视图和控制能力。
    // EditorMainArea主要负责渲染。
    // 如果确实需要在这里滚动，确保使用缓存的布局信息来定位。
    if (!mounted || widget.activeSceneId == null || widget.activeChapterId == null) return;
    
    AppLogger.i('EditorMainArea', 'Request to scroll to active scene: ${widget.activeSceneId}');
    
    // 查找活动场景所在的章节
    final chapterRect = _chapterLayouts[widget.activeChapterId!];
    if (chapterRect != null && widget.scrollController.hasClients) {
        // 这是一个简化的滚动，实际可能需要滚动到场景的具体位置
        // 而不是仅仅章节的开始。这需要场景级别的 GlobalKey 和布局缓存。
        widget.scrollController.animateTo(
            chapterRect.top, // 滚动到章节顶部
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
        );
        AppLogger.i('EditorMainArea', 'Scrolled towards active chapter containing active scene.');
    } else {
        AppLogger.w('EditorMainArea', 'Cannot scroll to active scene: chapter layout not found or no scroll client.');
    }
  }
  
  void scrollToActiveSceneSmooth() {
    // 类似 scrollToActiveScene，应由更高级别的控制器管理
    scrollToActiveScene(); // 暂时调用非平滑版本
  }
  
  void setActiveChapter(String actId, String chapterId) {
    // 这个方法主要是由外部（如目录点击）调用来设置活动章节并滚动到它
    if (!mounted) return;
    
    AppLogger.i('EditorMainArea', 'Setting active chapter (external request): actId=$actId, chapterId=$chapterId');
    
    // 1. 更新BLoC状态，让BLoC成为主要状态源
    widget.editorBloc.add(editor_bloc.SetActiveChapter(
        actId: actId,
        chapterId: chapterId,
        shouldScroll: true // 指示需要滚动
    ));

    // 2. BLoC状态更新后，会触发UI重建和可能的滚动逻辑
    // （例如在EditorScreenController中监听BLoC状态，然后调用此处的滚动方法，
    // 或者直接让EditorMainArea在BLoC更新后自行滚动）

    // 为了确保布局计算是最新的，可以触发一次
    _novelStructureChanged = true;
    _scheduleChapterLayoutCalculation();

    // 延迟确保布局计算完成，然后尝试滚动
    Future.delayed(const Duration(milliseconds: 250), () { // 增加延迟
        if (!mounted) return;
        final chapterLayout = _chapterLayouts[chapterId];
        if (chapterLayout != null && widget.scrollController.hasClients) {
            final targetScrollOffset = chapterLayout.top.clamp(
                widget.scrollController.position.minScrollExtent,
                widget.scrollController.position.maxScrollExtent
            );
            widget.scrollController.animateTo(
                targetScrollOffset,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
            );
            AppLogger.i('EditorMainArea', 'Successfully animated to chapter: $chapterId at $targetScrollOffset');
        } else {
            AppLogger.w('EditorMainArea', 'Cannot scroll to chapter $chapterId: layout not found or no scroll client.');
        }
    });
  }
}
