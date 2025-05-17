import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/quill_helper.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';
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
import 'package:ainoval/screens/editor/components/scene_editor.dart';
import 'package:ainoval/screens/editor/components/volume_navigation_buttons.dart';
import 'package:ainoval/screens/editor/components/fullscreen_loading_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:visibility_detector/visibility_detector.dart';
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
  
  // 用于跟踪正在加载的章节，避免重复加载请求
  final Set<String> _loadingChapterIds = {};
  
  // 添加章节位置跟踪
  final Map<String, double> _chapterPositions = {};

  // 添加视口管理相关属性
  final Map<String, bool> _visibleActs = {};
  final Map<String, bool> _visibleChapters = {};
  final Map<String, bool> _renderedScenes = {};
  bool _isScrollingDrivenFocus = false; // 新增标志，用于判断焦点是否由滚动主导
  
  // 添加全屏加载状态
  bool _isFullscreenLoading = false;
  String _loadingMessage = '正在加载...';
  
  // 虚拟列表配置
  double _estimatedPageHeight = 800.0; // 默认估计值
  double get _preloadDistance => _estimatedPageHeight * 2.5; // 动态计算预加载距离为2.5个页面高度
  ScrollMetrics? _lastReportedPosition;
  final ValueNotifier<List<String>> _visibleItemsNotifier = ValueNotifier<List<String>>([]);
  
  // 添加新的状态变量
  String? _focusChapterId; // 当前视口中心的章节ID
  
  // 添加卷导航状态变量
  bool _isNavigatingToAct = false;
  String? _targetActId;
  String? _targetChapterId;
  
  // 添加以下用于管理卷轴切换的变量
  bool _isLoadingPreviousAct = false;
  bool _isLoadingNextAct = false;
  
  @override
  void initState() {
    super.initState();
    
    // 延迟执行，确保滚动监听器生效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isInitialized = true;
      
      // 计算页面高度
      _calculatePageHeight();
      
      // 添加日志记录可见区域信息
      AppLogger.i('EditorMainArea', '初始化完成，屏幕高度: ${MediaQuery.of(context).size.height}px');
      AppLogger.i('EditorMainArea', '估计页面高度: ${_estimatedPageHeight}px, 预加载范围: ${_preloadDistance}px');
      
      // 只检查活动章节和周围的章节，而不是所有空章节
      _checkForVisibleEmptyChapters();
      
      // 添加滚动监听器，在滚动停止时检查可见章节
      _setupScrollListener();
      
      // 添加Bloc状态监听以更新_loadingChapterIds
      _listenToEditorBlocState();
      
      // 添加定期清理不可见场景的定时器
      Timer.periodic(const Duration(seconds: 30), (_) {
        _cleanupInvisibleScenes();
      });
      
      // 初始评估可见项目
      _updateVisibleItemsBasedOnActiveScene();
      
      // 初始化时设置焦点章节为活动章节
      _focusChapterId = widget.activeChapterId;
      
      // 初始化时更新所有章节位置信息
      _updateAllChapterPositions();
      
      // 首次渲染后更新焦点章节
      // 使用短暂延迟确保位置信息已更新
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _updateFocusChapter(true); // 强制更新焦点
        }
      });
    });
  }
  
  // 监听EditorBloc状态更新，用于跟踪加载状态变更
  void _listenToEditorBlocState() {
    widget.editorBloc.stream.listen((state) {
      if (state is editor_bloc.EditorLoaded) {
        bool shouldRefreshUI = false;
        if (!state.isLoading && _loadingChapterIds.isNotEmpty) {
          _loadingChapterIds.clear();
          shouldRefreshUI = true;
          AppLogger.i('EditorMainArea', '加载完成，准备刷新UI显示新章节');
        }

        // 如果焦点章节从BLoC状态变化，并且与当前滚动驱动的焦点不同，或者本地焦点为空时，才更新
        // 避免在用户滚动时被BLoC的activeChapterId覆盖当前视口的焦点
        if (mounted && state.activeChapterId != null && _focusChapterId != state.activeChapterId && !_isScrollingDrivenFocus) {
            // 仅当BLoC的activeChapterId和当前_focusChapterId不在同一个Act，
            // 或者_focusChapterId为空时，才接受来自BLoC的更新。
            // 这允许用户在当前Act内滚动时，焦点由滚动逻辑主导。
            String? currentFocusActFromLocal = _getCurrentFocusActId(); // 基于当前的 _focusChapterId
            String? blocActiveAct;
            for (final act in widget.novel.acts) {
                if (act.chapters.any((ch) => ch.id == state.activeChapterId)) {
                    blocActiveAct = act.id;
                    break;
                }
            }

            if (_focusChapterId == null || currentFocusActFromLocal != blocActiveAct) {
                AppLogger.d('EditorMainArea', 'BLoC状态更新焦点章节: $_focusChapterId -> ${state.activeChapterId}');
                _focusChapterId = state.activeChapterId; 
                // 如果焦点章节变化了，可能需要重新评估可见内容和UI
                shouldRefreshUI = true; 
            }
        }
        
        if (shouldRefreshUI) {
            if (mounted) {
              setState(() {
                AppLogger.i('EditorMainArea', '状态变更或加载完成，刷新UI');
                _updateAllChapterPositions();
                // _updateVisibleItemsBasedOnActiveScene(); // 使用更通用的更新方式
                if (widget.scrollController.hasClients) {
                    final scrollPosition = widget.scrollController.position;
                    final viewportStart = scrollPosition.pixels;
                    final viewportEnd = viewportStart + scrollPosition.viewportDimension;
                    _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
                } else {
                    _updateVisibleItemsBasedOnActiveScene();
                }
                _updateFocusChapter(true); // 强制更新焦点
                
                // _forceRefreshRenderedScenes(); // 移除这里的强制刷新，让列表自行更新
              });
            }
        }
      }
    });
  }
  
  // 新增方法：强制刷新所有已加载场景的渲染状态
  void _forceRefreshRenderedScenes() {
    if (!mounted) {
      AppLogger.w('EditorMainArea', '尝试强制刷新场景时组件已卸载');
      return;
    }
    
    AppLogger.i('EditorMainArea', '强制刷新已渲染场景...');
    
    // 记录当前渲染状态
    final oldRenderedCount = _renderedScenes.length;
    
    setState(() {
      // 清空临时渲染状态并触发重建
      _renderedScenes.clear();
    });
    
    // 延迟后更新章节位置
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      AppLogger.i('EditorMainArea', '延迟更新章节位置...');
      _updateAllChapterPositions();
      
      // 记录更新后的状态
      AppLogger.i('EditorMainArea', '场景刷新完成: 清理前渲染场景数 $oldRenderedCount，当前渲染场景数 ${_renderedScenes.length}');
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
          chaptersLimit: 10,
          actId: activeActId,  // 添加actId参数
          preventFocusChange: true,  // 防止焦点自动变化
        ));
      }
    }
    
    // 不再主动检查和加载视口中的其他空章节
    // 改为在滚动检测边界时加载
  }

  // 添加滚动监听器
  void _setupScrollListener() {
    widget.scrollController.addListener(() {
      _isScrollingDrivenFocus = true; // 标记滚动开始
      // 使用计时器节流更新焦点，避免高频率更新
      if (_focusUpdateTimer == null || !_focusUpdateTimer!.isActive) {
        _focusUpdateTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            _updateAllChapterPositions(); // _updateFocusChapter 和 _updateVisibleItems 可能依赖最新的位置
            _updateFocusChapter();

            // 将 _updateVisibleItems 移到这里
            if (widget.scrollController.hasClients) {
                final scrollPosition = widget.scrollController.position;
                final viewportStart = scrollPosition.pixels;
                final viewportEnd = viewportStart + scrollPosition.viewportDimension;
                _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
            }

            _isScrollingDrivenFocus = false; // 标记滚动相关的焦点更新结束
          }
        });
      }
      
      // 添加滚动停止时的清理逻辑
      if (_cleanupTimer == null || !_cleanupTimer!.isActive) {
        _cleanupTimer = Timer(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _cleanupUnusedControllers();
          }
        });
      }
      
      // 同时检查滚动到边界的情况，以便加载更多内容
      _checkScrollBoundariesForLoading();
    });
  }
  
  // 清理定时器
  Timer? _cleanupTimer;
  
  // 强化版清理控制器方法，主动清理不在当前焦点Act中的控制器
  void _cleanupUnusedControllers() {
    if (!mounted || !_enforceSingleActMode) return;
    
    // 获取当前焦点Act
    String? focusActId = _getCurrentFocusActId();
    if (focusActId == null) return;
    
    final controllersToRemove = <String>[];
    final now = DateTime.now();
    int removedCount = 0;
    
    // 1. 查找所有不在当前焦点Act中且最后可见时间超过30秒的控制器
    for (final entry in _lastVisibleTime.entries) {
      final sceneId = entry.key;
      final lastSeenTime = entry.value;
      
      // 提取Act ID
      final parts = sceneId.split('_');
      if (parts.length < 3) continue;
      
      final actId = parts[0];
      
      // 如果不是当前焦点Act，且上次可见时间超过30秒
      if (actId != focusActId && now.difference(lastSeenTime).inSeconds > 30) {
        controllersToRemove.add(sceneId);
      }
      // 或者是任何超过5分钟未见的场景（无论哪个Act）
      else if (now.difference(lastSeenTime).inMinutes > 5) {
        controllersToRemove.add(sceneId);
      }
    }
    
    // 2. 移除这些控制器
    for (final sceneId in controllersToRemove) {
      if (widget.sceneControllers.containsKey(sceneId)) {
        try {
          // 尝试销毁控制器
          widget.sceneControllers[sceneId]?.dispose();
          widget.sceneControllers.remove(sceneId);
          
          // 移除摘要控制器
          widget.sceneSummaryControllers[sceneId]?.dispose();
          widget.sceneSummaryControllers.remove(sceneId);
          
          // 清理渲染和时间记录
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
  
  // 清理长时间不可见的场景控制器，释放内存
  void _cleanupInvisibleScenes() {
    if (!mounted) return;
    
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    // 单卷模式下，更激进地清理不可见场景
    if (_enforceSingleActMode) {
      // 获取当前焦点Act
      String? focusActId = _getCurrentFocusActId();
      if (focusActId != null) {
        // 遍历所有场景，标记不在当前Act中的场景
        for (final sceneId in _renderedScenes.keys) {
          final parts = sceneId.split('_');
          if (parts.length >= 3 && parts[0] != focusActId) {
            // 非当前Act的场景，降低清理阈值到1分钟
            if (_lastVisibleTime.containsKey(sceneId) && 
                now.difference(_lastVisibleTime[sceneId]!).inMinutes >= 1) {
              keysToRemove.add(sceneId);
            }
          }
        }
      }
    }
    
    // 常规清理：找出超过5分钟未见的场景
    _renderedScenes.forEach((sceneId, isVisible) {
      if (!isVisible && 
          _lastVisibleTime.containsKey(sceneId) &&
          now.difference(_lastVisibleTime[sceneId]!).inMinutes > 5) {
        keysToRemove.add(sceneId);
      }
    });
    
    // 释放资源
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
  
  // 防抖定时器，用于在滚动停止后再检查
  Timer? _scrollDebounceTimer;
  
  // 检查滚动边界，决定是否需要向上或向下加载更多内
  // 记录上次加载方向的时间，用于防抖
  DateTime? _lastLoadUpTime;
  DateTime? _lastLoadDownTime;
  
  // 加载指定方向的更多内容
  void _loadMoreInDirection(String direction, {bool priority = false}) {
    // 更新最后滚动方向
    _lastScrollDirection = direction;
    
    // 防抖处理 - 控制加载频率
    final now = DateTime.now();
    int secondsThreshold = 2; // 默认防抖时间阈值
    
    // 如果是优先加载，减少防抖时间
    if (priority) {
      secondsThreshold = 1; // 优先加载时仅需1秒
    }
    
    if (direction == 'up' && _lastLoadUpTime != null) {
      final secondsSinceLastLoad = now.difference(_lastLoadUpTime!).inSeconds;
      if (secondsSinceLastLoad < secondsThreshold) {
        AppLogger.d('EditorMainArea', '向上加载过于频繁(${secondsSinceLastLoad}秒前刚加载)，跳过此次请求');
        return;
      }
    } else if (direction == 'down' && _lastLoadDownTime != null) {
      final secondsSinceLastLoad = now.difference(_lastLoadDownTime!).inSeconds;
      if (secondsSinceLastLoad < secondsThreshold) {
        AppLogger.d('EditorMainArea', '向下加载过于频繁(${secondsSinceLastLoad}秒前刚加载)，跳过此次请求');
        return;
      }
    }
    
    // 检查是否有正在进行的加载
    if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
      final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
      if (state.isLoading) {
        AppLogger.d('EditorMainArea', 'EditorBloc正在加载中，跳过此次加载请求');
        return;
      }
    }
    
    // 确定要加载章节的ID
    String? fromChapterId;
    String? actId; // 添加actId变量，用于记录章节所属的卷
    
    if (direction == 'up') {
      // 向上加载时，从找到的第一个非空章节开始
      fromChapterId = _findFirstNonEmptyChapterId();
      
      // 找到章节所属的卷ID
      if (fromChapterId != null) {
        if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
          final editorState = widget.editorBloc.state as editor_bloc.EditorLoaded;
          actId = editorState.chapterToActMap[fromChapterId];
        } else {
          AppLogger.w('EditorMainArea', '_loadMoreInDirection (up): EditorBloc state is not EditorLoaded. Falling back to iterating acts.');
          for (final actLoop in widget.novel.acts) {
            for (final chapterLoop in actLoop.chapters) {
              if (chapterLoop.id == fromChapterId) {
                actId = actLoop.id;
                break;
              }
            }
            if (actId != null) break;
          }
        }
      }
      
      _lastLoadUpTime = now;
    } else {
      // 向下加载时，从找到的最后一个非空章节开始
      fromChapterId = _findLastNonEmptyChapterId();
      
      // 找到章节所属的卷ID
      if (fromChapterId != null) {
        if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
          final editorState = widget.editorBloc.state as editor_bloc.EditorLoaded;
          actId = editorState.chapterToActMap[fromChapterId];
        } else {
          AppLogger.w('EditorMainArea', '_loadMoreInDirection (down): EditorBloc state is not EditorLoaded. Falling back to iterating acts.');
          for (final actLoop in widget.novel.acts) {
            for (final chapterLoop in actLoop.chapters) {
              if (chapterLoop.id == fromChapterId) {
                actId = actLoop.id;
                break;
              }
            }
            if (actId != null) break;
          }
        }
      }
      
      _lastLoadDownTime = now;
    }
    
    if (fromChapterId != null && actId != null) {
      AppLogger.i('EditorMainArea', '加载${direction == 'up' ? '上方' : '下方'}内容，卷ID: $actId，起始章节: $fromChapterId');
      
      // 标记章节为加载中状态，避免重复请求
      _markChapterAsLoading(fromChapterId);
      
      // 发送加载请求
      widget.editorBloc.add(editor_bloc.LoadMoreScenes(
        fromChapterId: fromChapterId,
        actId: actId,
        direction: direction,
        chaptersLimit: 10, // 增加到10个章节，确保加载更多内容
        preventFocusChange: true, // 防止焦点改变
      ));
      
      // 强制刷新UI以显示加载状态
      setState(() {});
    } else {
      AppLogger.w('EditorMainArea', '无法找到适合加载的章节ID或卷ID');
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
            // 检查 novel 结构是否真的改变 (acts数量, chapters总数, scenes总数)
            // 这一步可以省略，因为 buildWhen 应该会处理
            
            setState(() {
              _loadingChapterIds.clear();
              AppLogger.i('EditorMainArea', 'BlocListener: 加载完成，刷新UI显示新章节');
              
              // _forceRefreshRenderedScenes(); // 移除
              
              // 更新所有章节位置信息
              _updateAllChapterPositions();
              
              // 更新可见项目范围
              if (widget.scrollController.hasClients) {
                final scrollPosition = widget.scrollController.position;
                final viewportStart = scrollPosition.pixels;
                final viewportEnd = viewportStart + scrollPosition.viewportDimension;
                _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
              } else {
                _updateVisibleItemsBasedOnActiveScene();
              }
              
              _updateFocusChapter(true); // 强制更新焦点

              // 设置一个短暂延迟后重新扫描可见区域 (这个可能不需要了，因为上面已经更新了)
              // Future.delayed(const Duration(milliseconds: 100), () {
              //   if (mounted) {
              //     final scrollPosition = widget.scrollController.position;
              //     final viewportStart = scrollPosition.pixels;
              //     final viewportEnd = viewportStart + scrollPosition.viewportDimension;
              //     _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
                  
              //     AppLogger.i('EditorMainArea', '已完成延迟扫描可见区域');
              //   }
              // });
            });
          }
        }
      },
      // 添加新的监听条件以检测加载完成和场景变化
      listenWhen: (previous, current) {
        // 检测加载状态变化
        if (previous is editor_bloc.EditorLoaded && 
            current is editor_bloc.EditorLoaded) {
          
          // 加载状态变化
          if (previous.isLoading != current.isLoading) {
            AppLogger.i('EditorMainArea', 
                '加载状态变化: ${previous.isLoading} -> ${current.isLoading}，触发UI更新');
            return true;
          }
            
          // 检查Acts数量是否变化
          final prevActsCount = previous.novel.acts.length;
          final currentActsCount = current.novel.acts.length;
          
          if (prevActsCount != currentActsCount) {
            AppLogger.i('EditorMainArea', 
                'Acts数量变化: $prevActsCount -> $currentActsCount，触发UI更新');
            return true;
          }
          
          // 检查章节总数是否变化
          int prevChaptersCount = 0;
          int currentChaptersCount = 0;
          
          for (final act in previous.novel.acts) {
            prevChaptersCount += act.chapters.length;
          }
          
          for (final act in current.novel.acts) {
            currentChaptersCount += act.chapters.length;
          }
          
          if (prevChaptersCount != currentChaptersCount) {
            AppLogger.i('EditorMainArea', 
                '章节总数变化: $prevChaptersCount -> $currentChaptersCount，触发UI更新');
            return true;
          }
          
          // 检查场景总数是否变化
          int prevScenesCount = 0;
          int currentScenesCount = 0;
          
          for (final act in previous.novel.acts) {
            for (final chapter in act.chapters) {
              prevScenesCount += chapter.scenes.length;
            }
          }
          
          for (final act in current.novel.acts) {
            for (final chapter in act.chapters) {
              currentScenesCount += chapter.scenes.length;
            }
          }
          
          if (prevScenesCount != currentScenesCount) {
            AppLogger.i('EditorMainArea', 
                '场景总数变化: $prevScenesCount -> $currentScenesCount，触发UI更新');
            return true;
          }
          
          // 检查hasReachedEnd或hasReachedStart标志变化
          if (previous.hasReachedEnd != current.hasReachedEnd || 
              previous.hasReachedStart != current.hasReachedStart) {
            AppLogger.i('EditorMainArea', 
                '内容边界状态变化，触发UI更新');
            return true;
          }
          
          // 检查保存状态变化
          if (previous.isSaving != current.isSaving) {
            return true;
          }
        }
        
        return false;
      },
      child: Stack(
        children: [
          Container(
            // 1. 使用更柔和的背景色
            color: veryLightGrey,
            child: _buildVirtualizedScrollView(context, isLoadingMore),
          ),
          
          // 添加加载动画覆盖层
          // if (isLoadingMore && !_isFullscreenLoading)  // Removed this line and the next
          //   _buildLoadingOverlay(), // Removed this line
            
          // 添加全屏加载覆盖层
          if (_isFullscreenLoading)
            FullscreenLoadingOverlay(
              loadingMessage: _loadingMessage,
              showProgressIndicator: true,
            ),
        ],
      ),
    );
  }
  
  // 替换原来的_buildOptimizedScrollView方法
  Widget _buildVirtualizedScrollView(BuildContext context, bool isLoadingMore) {
    // 获取状态
    final hasReachedStart = widget.editorBloc.state is editor_bloc.EditorLoaded && 
                           (widget.editorBloc.state as editor_bloc.EditorLoaded).hasReachedStart;
    final hasReachedEnd = widget.editorBloc.state is editor_bloc.EditorLoaded && 
                         (widget.editorBloc.state as editor_bloc.EditorLoaded).hasReachedEnd;
    
    // 确定是否第一卷/最后一卷
    final isFirstAct = _isInFirstAct();
    final isLastAct = _isInLastAct();
    
    // 日志记录当前卷状态，帮助调试
    AppLogger.i('EditorMainArea', '当前卷状态：isFirstAct=$isFirstAct, isLastAct=$isLastAct, hasReachedStart=$hasReachedStart, hasReachedEnd=$hasReachedEnd');
    
    return CustomScrollView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      clipBehavior: Clip.hardEdge,
      slivers: [
        // 顶部导航按钮 - 上一卷
        SliverToBoxAdapter(
          child: VolumeNavigationButtons(
            isTop: true,
            hasReachedStart: hasReachedStart,
            hasReachedEnd: false,
            isLoadingMore: _isLoadingPreviousAct,
            isFirstAct: isFirstAct,
            isLastAct: false,
            onPreviousAct: (isFirstAct && hasReachedStart) ? null : _navigateToPreviousAct, // 如果是第一卷顶部，则禁用
            onNextAct: () {}, // 不需要处理
            onAddNewAct: () {}, // 不需要处理
          ),
        ),
        
        // 如果已到顶部，显示顶部提示
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
                      // 使用ValueListenableBuilder来优化重建
                      ValueListenableBuilder<List<String>>(
                        valueListenable: _visibleItemsNotifier,
                        builder: (context, visibleItems, child) {
                          return Column(
                            children: [
                              // 只构建需要显示的Act - 严格单卷模式，只渲染当前焦点Act
                              ...widget.novel.acts
                                  .where((act) => _shouldRenderAct(act))
                                  .map((act) => _buildVirtualizedActSection(act, visibleItems)),
                            ],
                          );
                        },
                      ),
                      
                      
                      // 添加新Act按钮 - 修改显示逻辑
                      // if (_shouldShowAddActButton())
                      //   const AddActButton(),
                      
                      // 底部空间
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // 如果已到底部，显示底部提示
        if (hasReachedEnd)
          SliverToBoxAdapter(child: _buildEndOfContentIndicator(false)),
          
        // 底部导航按钮 - 下一卷或添加新卷
        SliverToBoxAdapter(
          child: VolumeNavigationButtons(
            isTop: false,
            hasReachedStart: false,
            hasReachedEnd: hasReachedEnd,
            isLoadingMore: _isLoadingNextAct,
            isFirstAct: false,
            isLastAct: isLastAct,
            onPreviousAct: () {}, // 不需要处理
            onNextAct: _navigateToNextAct,
            onAddNewAct: _addNewAct,
          ),
        ),
      ],
    );
  }
  
  // 添加一个方法来创建"已到达内容边界"的指示器
  Widget _buildEndOfContentIndicator(bool isTop) {
    return BoundaryIndicator(isTop: isTop);
  }
  
  // 处理滚动通知，更新可见项目
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      
      // 存储滚动位置信息
      _lastReportedPosition = metrics;
      
      // 计算视口边界
      // final viewportStart = metrics.pixels; // 这行不再需要
      // final viewportEnd = metrics.pixels + metrics.viewportDimension; // 这行不再需要
      
      // 更新可见项目 // 这整块将被移除
      // SchedulerBinding.instance.addPostFrameCallback((_) {
      //   if (mounted) {
      //     // 先更新可见项目
      //     _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
      //     
      //     // 然后确定焦点章节
      //     _updateFocusChapter(); // 移除错误的double参数
      //   }
      // });
    }
    return false;
  }
  
  // 更新可见项目列表
  void _updateVisibleItems(double preloadStart, double preloadEnd) {
    // 找出当前在预加载区域内的Act和Chapter
    final Set<String> newVisibleItems = {};
    int visibleActCount = 0;
    int visibleChapterCount = 0;
    int visibleSceneCount = 0;
    
    AppLogger.d('EditorMainArea', '开始更新可见项目，预加载范围: $preloadStart ~ $preloadEnd');
    
    // 查找所有带有GlobalKey的Act和Chapter并检查其位置
    for (final act in widget.novel.acts) {
      final actKey = widget.sceneKeys['act_${act.id}'];
      if (actKey?.currentContext != null) {
        final RenderBox box = actKey!.currentContext!.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        final actTop = position.dy;
        final actBottom = actTop + box.size.height;
        
        // 检查Act是否在预加载范围内
        final bool isActVisible = actBottom >= preloadStart && actTop <= preloadEnd;
        if (isActVisible) {
          newVisibleItems.add('act_${act.id}');
          visibleActCount++;
          _visibleActs[act.id] = true;
          
          // 日志记录可见Act
          AppLogger.d('EditorMainArea', '可见Act: ${act.title} (${act.id}), 位置: $actTop ~ $actBottom');
          
          // 检查此Act中的Chapter
          for (final chapter in act.chapters) {
            final chapterKey = widget.sceneKeys['chapter_${act.id}_${chapter.id}'];
            if (chapterKey?.currentContext != null) {
              final chapterBox = chapterKey!.currentContext!.findRenderObject() as RenderBox;
              final chapterPosition = chapterBox.localToGlobal(Offset.zero);
              final chapterTop = chapterPosition.dy;
              final chapterBottom = chapterTop + chapterBox.size.height;
              
              // 检查Chapter是否在预加载范围内
              final bool isChapterVisible = chapterBottom >= preloadStart && chapterTop <= preloadEnd;
              if (isChapterVisible) {
                newVisibleItems.add('chapter_${act.id}_${chapter.id}');
                visibleChapterCount++;
                _visibleChapters['${act.id}_${chapter.id}'] = true;
                
                // 关键修改：如果章节可见，则将其所有场景标记为可见，不再单独判断每个场景
                for (final scene in chapter.scenes) {
                  final sceneId = '${act.id}_${chapter.id}_${scene.id}';
                  newVisibleItems.add(sceneId);
                  visibleSceneCount++;
                  _lastVisibleTime[sceneId] = DateTime.now();
                  _renderedScenes[sceneId] = true;
                  
                  // 记录章节所有场景均被标记为可见
                  AppLogger.d('EditorMainArea', '章节可见，自动将场景标记为可见: ${scene.id}');
                }
              } else {
                _visibleChapters['${act.id}_${chapter.id}'] = false;
              }
            }
          }
        } else {
          _visibleActs[act.id] = false;
        }
      }
    }
    
    // 日志记录可见统计
    AppLogger.i('EditorMainArea', '可见项目统计 - Acts: $visibleActCount, Chapters: $visibleChapterCount, Scenes: $visibleSceneCount');
    
    // 只有在可见项目发生变化时才更新通知器
    if (!const DeepCollectionEquality().equals(
        _visibleItemsNotifier.value.toSet(), newVisibleItems)) {
      AppLogger.i('EditorMainArea', '可见项目发生变化，更新UI');
      _visibleItemsNotifier.value = newVisibleItems.toList();
    }
  }
  
  // 修改_shouldRenderAct方法，添加更严格的检查确保当前Act的所有章节已加载
  bool _shouldRenderAct(novel_models.Act act) {
    final String actId = act.id;
    
    // 检查当前卷是否已经有渲染状态
    final hasRendered = _renderedScenes.entries.any((entry) => entry.key.startsWith('${actId}_'));
    
    // 如果加载章节的BLoC事件还没完成，确保至少当前章节所在的Act能正确渲染
    if (_isLoadingPreviousAct || _isLoadingNextAct) {
      // 正在加载其他卷的内容，只渲染目标卷和当前卷
      if (_targetActId != null && actId == _targetActId) {
        // 允许渲染目标卷
        AppLogger.d('EditorMainArea', '允许渲染目标卷: $actId (正在加载)');
        return true;
      } else if (widget.activeActId != null && actId == widget.activeActId) {
        // 允许渲染当前焦点卷
        AppLogger.d('EditorMainArea', '允许渲染当前焦点卷: $actId (正在加载其他卷)');
        return true;
      } else {
        // 严格模式下不允许渲染其他卷
        if (_enforceSingleActMode) {
          AppLogger.d('EditorMainArea', '加载状态下严格单卷模式: 阻止渲染非目标卷: $actId');
          return false;
        }
        // 保持已渲染的卷
        return hasRendered;
      }
    }
    
    // 严格单卷模式下，只渲染当前焦点卷
    if (_enforceSingleActMode) {
      final String? focusActId = widget.activeActId;
      
      // 如果焦点卷ID为空，则允许渲染（初始加载）
      if (focusActId == null) {
        return true;
      }
      
      // 仅渲染当前焦点卷
      final bool isCurrentFocusAct = (actId == focusActId);
      
      if (!isCurrentFocusAct) {
        AppLogger.d('EditorMainArea', '严格单卷模式: 阻止渲染非焦点卷: $actId (当前焦点卷: $focusActId)');
      }
      
      return isCurrentFocusAct;
    }
    
    // 非严格模式下的原始逻辑
    return true;
  }
  
  // 获取当前焦点Act ID的辅助方法
  String? _getCurrentFocusActId() {
    // 优先使用本地焦点章节
    if (_focusChapterId != null) {
      for (final currentAct in widget.novel.acts) {
        for (final chapter in currentAct.chapters) {
          if (chapter.id == _focusChapterId) {
            return currentAct.id;
          }
        }
      }
    }
    
    // 其次使用活动章节
    if (widget.activeChapterId != null) {
      for (final currentAct in widget.novel.acts) {
        for (final chapter in currentAct.chapters) {
          if (chapter.id == widget.activeChapterId) {
            return currentAct.id;
          }
        }
      }
    }
    
    return null;
  }
  
  // 强制单卷模式开关 - 默认启用
  final bool _enforceSingleActMode = true;
  
  // 判断章节是否应该被渲染，使用简单的距离判断
  bool _shouldRenderChapter(String actId, String chapterId) {
    // 如果章节所在Act没有章节或章节数很少，渲染全部
    final act = widget.novel.acts.firstWhere((a) => a.id == actId, orElse: () {
      AppLogger.w('EditorMainArea', '在 _shouldRenderChapter 中找不到 Act: $actId');
      return novel_models.Act(id: '', title: '', chapters: [], order: 0); 
    });
    if (act.id.isEmpty) return false;

    if (act.chapters.isEmpty || act.chapters.length <= 5) {
      return true;
    }
    
    // 始终渲染活动章节和焦点章节
    if (widget.activeChapterId == chapterId || _focusChapterId == chapterId) {
      AppLogger.d('EditorMainArea', '章节$chapterId是${widget.activeChapterId == chapterId ? "活动" : (_focusChapterId == chapterId ? "焦点" : "未知")}章节，渲染');
      return true;
    }
    
    // 获取用于判断的参考章节ID（优先使用焦点章节，其次是活动章节）
    final referenceChapterId = _focusChapterId ?? widget.activeChapterId;
    if (referenceChapterId == null) {
      // 如果没有参考章节，默认渲染所有章节 (或者只渲染前几个)
      // 为了性能，如果没有参考点，可以考虑只渲染每个Act的前几个
      // 但目前行为是渲染所有，如果滚动后没有焦点，可能会导致全部渲染
      final chapterIndexInAct = act.chapters.indexWhere((ch) => ch.id == chapterId);
      if (chapterIndexInAct != -1 && chapterIndexInAct < 3) { // 如果没有参考，默认渲染每个Act的前3章
          AppLogger.d('EditorMainArea', '无参考章节，章节$chapterId 是Act ${act.title} 的前3章之一，渲染');
          return true;
      }
      AppLogger.d('EditorMainArea', '无参考章节，章节$chapterId 不在前3章，不渲染');
      return false; // 修改：如果没有参考章节，不渲染所有，而是不渲染（或只渲染少量）
    }
    
    // 查找参考章节所在的Act和索引位置
    String? referenceActId;
    int referenceGlobalIndex = -1;
    int currentGlobalIndex = -1;

    // 从 BLoC 状态获取预计算的映射
    if (widget.editorBloc.state is! editor_bloc.EditorLoaded) {
      AppLogger.w('EditorMainArea', '_shouldRenderChapter: EditorBloc state is not EditorLoaded. Defaulting to false.');
      return false;
    }
    final state = widget.editorBloc.state as editor_bloc.EditorLoaded;

    // 假设 EditorLoaded 状态中包含 chapterGlobalIndices 和 chapterToActMap
    // 您需要在 EditorBloc 的 EditorLoaded state 中定义并维护这些映射。
    // 例如:
    // class EditorLoaded extends EditorState {
    //   // ...其他属性
    //   final Map<String, int> chapterGlobalIndices;
    //   final Map<String, String> chapterToActMap;
    //   EditorLoaded({required this.novel, ..., required this.chapterGlobalIndices, required this.chapterToActMap});
    // }
    // 然后在 EditorBloc 中更新它们。
    // 请确保 state.chapterGlobalIndices 和 state.chapterToActMap 在您的 EditorLoaded state 中是有效的。
    final Map<String, int> chapterGlobalIndices = state.chapterGlobalIndices; 
    final Map<String, String> chapterToActMap = state.chapterToActMap;

    referenceActId = chapterToActMap[referenceChapterId]; // referenceChapterId 已保证非null
    referenceGlobalIndex = chapterGlobalIndices[referenceChapterId] ?? -1;
    currentGlobalIndex = chapterGlobalIndices[chapterId] ?? -1;

    if (referenceActId == null || referenceGlobalIndex == -1 || currentGlobalIndex == -1) {
      AppLogger.w('EditorMainArea',
          'Chapter $chapterId (current) or $referenceChapterId (reference) not found in global indices/maps or maps are incomplete. Cannot determine render status. Details: refActId: $referenceActId, refGlobalIdx: $referenceGlobalIndex, currentGlobalIdx: $currentGlobalIndex');
      return false;
    }
    
    // 获取参考章节在 novel.acts 中的索引
    int referenceActIndexInNovel = -1;
    if (referenceActId != null) {
      referenceActIndexInNovel = widget.novel.acts.indexWhere((actIter) => actIter.id == referenceActId);
    }
    // 获取当前章节所在 act 在 novel.acts 中的索引
    int currentChapterActIndexInNovel = widget.novel.acts.indexWhere((actIter) => actIter.id == actId);

    final distance = (currentGlobalIndex - referenceGlobalIndex).abs();
    bool shouldRender;

    if (referenceActId == actId) { // 当前章节与参考章节在同一个Act
      int sameActRenderThreshold = 12; 
      
      int chapterIndexOfReferenceInAct = -1;
      if(referenceActIndexInNovel != -1 && referenceActId != null){
          final refAct = widget.novel.acts[referenceActIndexInNovel];
          chapterIndexOfReferenceInAct = refAct.chapters.indexWhere((ch) => ch.id == referenceChapterId);
      }

      int chapterIndexOfCurrentInAct = act.chapters.indexWhere((ch) => ch.id == chapterId);

      // 如果参考章节是当前Act的前3章，或者当前章节是Act的前5章，增大渲染范围
      if (chapterIndexOfReferenceInAct != -1 && chapterIndexOfReferenceInAct < 3 || chapterIndexOfCurrentInAct != -1 && chapterIndexOfCurrentInAct < 5 ) {
         sameActRenderThreshold = 18; // 渲染更多，保证前几章稳定
      } else {
          bool isScrollingTowardsCurrent = (currentGlobalIndex < referenceGlobalIndex && _lastScrollDirection == 'up') ||
                                       (currentGlobalIndex > referenceGlobalIndex && _lastScrollDirection == 'down');
          if (isScrollingTowardsCurrent) {
              sameActRenderThreshold = 15; 
          }
      }
      shouldRender = distance <= sameActRenderThreshold;
      AppLogger.d('EditorMainArea', 
          '章节$chapterId (Act $actId) 与参考章节 (Act $referenceActId) 同卷判断: 距离 $distance, 阈值 $sameActRenderThreshold, 渲染 $shouldRender, 参考章在Act中索引 $chapterIndexOfReferenceInAct, 当前章在Act中索引 $chapterIndexOfCurrentInAct');
    } else { // 跨卷
      int crossActRenderThreshold = 7; 
      bool isScrollingTowardsCurrent = (currentGlobalIndex < referenceGlobalIndex && _lastScrollDirection == 'up') ||
                                     (currentGlobalIndex > referenceGlobalIndex && _lastScrollDirection == 'down');
      
      if (referenceActIndexInNovel != -1 && currentChapterActIndexInNovel != -1 && (referenceActIndexInNovel - currentChapterActIndexInNovel).abs() == 1 && isScrollingTowardsCurrent) {
          crossActRenderThreshold = 10;
      }
      shouldRender = distance <= crossActRenderThreshold;
      AppLogger.d('EditorMainArea', 
          '章节$chapterId (Act $actId) 与参考章节 (Act $referenceActId) 跨卷判断: 距离 $distance, 阈值 $crossActRenderThreshold, 渲染 $shouldRender');
    }
    
    // 确保活动章节总是渲染 (这段逻辑已经在本函数开头处理过了，但为了保险可以保留)
    if (widget.activeChapterId == chapterId) {
        AppLogger.d('EditorMainArea', '章节$chapterId 是活动章节，再次确认强制渲染');
        return true;
    }
    
    return shouldRender;
  }
  
  // 添加跟踪最近滚动方向的变量
  String _lastScrollDirection = 'none';
  
  // 优化的Act Section构建器
  Widget _buildVirtualizedActSection(novel_models.Act act, List<String> visibleItems) {
    final isActVisible = true; // 总是将Act视为可见
    
    // 获取Act索引（从1开始）
    final int actIndex = widget.novel.acts.indexOf(act) + 1;
    
    // 只处理应该渲染的章节
    final visibleChapters = act.chapters
        .where((chapter) => _shouldRenderChapter(act.id, chapter.id))
        .toList();
    
    // 记录日志
    AppLogger.i('EditorMainArea', 'Act ${act.title} 中有${act.chapters.length}个章节，渲染${visibleChapters.length}个章节');
    
    // 无论是否有可渲染章节，都返回完整的ActSection
    // 这样即使是空Act也会显示添加章节的按钮
    return RepaintBoundary(
      key: widget.sceneKeys['act_${act.id}'] ?? GlobalKey(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48.0),
        child: ActSection(
          title: act.title,
          chapters: visibleChapters
              .asMap()
              .map((index, chapter) => MapEntry(
                  index,
                  _buildVirtualizedChapterSection(
                      act.id, 
                      chapter, 
                      visibleItems,
                      index + 1))) // 传递章节索引（从1开始）
              .values
              .toList(),
          actId: act.id,
          editorBloc: widget.editorBloc,
          totalChaptersCount: act.chapters.length,
          loadedChaptersCount: act.chapters.where((chapter) => chapter.scenes.isNotEmpty).length,
          actIndex: actIndex, // 传递Act索引
        ),
      ),
    );
  }
  
  // 优化的Chapter Section构建器
  Widget _buildVirtualizedChapterSection(
      String actId, novel_models.Chapter chapter, List<String> visibleItems, int chapterIndex) {
    // 创建章节Key
    final chapterKeyString = 'chapter_${actId}_${chapter.id}';
    // 使用 putIfAbsent 确保 Key 的创建和获取是原子性的，更稳定
    final chapterKey = widget.sceneKeys.putIfAbsent(chapterKeyString, () => GlobalKey());
    
    // 使用PostFrameCallback记录章节位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && chapterKey.currentContext != null) {
        try {
          final RenderBox box = chapterKey.currentContext!.findRenderObject() as RenderBox;
          final position = box.localToGlobal(Offset.zero);
          _recordChapterPosition(chapter.id, position.dy);
        } catch (e) {
          AppLogger.w('EditorMainArea', '在构建后记录章节位置失败: $chapterKeyString, 错误: $e');
        }
      }
    });
    
    // 直接渲染章节的所有内容，不再使用可见性判断
    return RepaintBoundary(
      key: chapterKey,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32.0),
        child: ChapterSection(
          title: chapter.title,
          scenes: chapter.scenes.isEmpty ? [] : 
              _buildVirtualizedSceneList(actId, chapter, visibleItems, chapterIndex),
          actId: actId,
          chapterId: chapter.id,
          editorBloc: widget.editorBloc,
          chapterIndex: chapterIndex, // 传递章节索引
        ),
      ),
    );
  }
  
  // 优化的Scene列表构建器
  List<Widget> _buildVirtualizedSceneList(
      String actId, novel_models.Chapter chapter, List<String> visibleItems, int chapterIndex) {
    final scenes = <Widget>[];
    
    // 获取当前活动章节和场景ID
    final String? currentActiveChapterId = widget.activeChapterId;
    final String? currentActiveSceneId = widget.activeSceneId;
    
    // 判断当前章节是否为活动章节
    final bool isActiveChapter = (currentActiveChapterId == chapter.id);
    
    AppLogger.d('EditorMainArea', '构建Chapter ${chapter.id} (${chapter.title}) 的场景列表，'
        '共${chapter.scenes.length}个场景，活动章节=${isActiveChapter}，'
        '活动场景ID=$currentActiveSceneId');
    
    // 强制渲染章节内所有场景
    for (int i = 0; i < chapter.scenes.length; i++) {
      final scene = chapter.scenes[i];
      final isFirst = i == 0;
      final sceneId = '${actId}_${chapter.id}_${scene.id}';
      
      // 场景索引（从1开始）
      final int sceneIndex = i + 1;
      
      // 判断场景是否为活动场景
      final bool isActiveScene = isActiveChapter && currentActiveSceneId == scene.id;
      
      if (isActiveScene) {
        AppLogger.i('EditorMainArea', '章节${chapter.id}中的场景${scene.id}是活动场景');
      }
      
      scenes.add(
        VirtualizedSceneLoader(
          key: ValueKey('loader_$sceneId'),
          sceneId: sceneId,
          actId: actId,
          chapterId: chapter.id,
          scene: scene,
          isFirst: isFirst,
          isActive: isActiveScene,
          sceneIndex: sceneIndex, // 传递场景索引
          sceneControllers: widget.sceneControllers,
          sceneSummaryControllers: widget.sceneSummaryControllers,
          sceneKeys: widget.sceneKeys,
          editorBloc: widget.editorBloc,
          parseDocumentSafely: DocumentParser.parseDocumentSafely,
          onVisibilityChanged: (isVisible) {
            // 记录时间以便清理
            _lastVisibleTime[sceneId] = DateTime.now();
          },
        ),
      );
    }
    
    return scenes;
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
  
  // 添加更平滑的滚动方法
  void scrollToActiveSceneSmooth() {
    if (widget.activeActId != null && 
        widget.activeChapterId != null && 
        widget.activeSceneId != null) {
      
      final sceneId = '${widget.activeActId}_${widget.activeChapterId}_${widget.activeSceneId}';
      final key = widget.sceneKeys[sceneId];
      
      if (key != null && key.currentContext != null) {
        try {
          // 获取目标场景的位置信息
          final RenderBox renderBox = key.currentContext!.findRenderObject() as RenderBox;
          final targetPosition = renderBox.localToGlobal(Offset.zero);
          
          // 计算目标滚动位置（考虑视口对齐）
          final scrollPosition = widget.scrollController.position;
          final viewportHeight = scrollPosition.viewportDimension;
          
          // 将目标定位到视口的1/3位置
          final targetOffset = targetPosition.dy - (viewportHeight * 0.3);
          
          // 获取当前滚动位置
          final currentOffset = scrollPosition.pixels;
          
          // 计算滚动距离
          final scrollDistance = (targetOffset - currentOffset).abs();
          
          // 根据滚动距离动态调整滚动时间，使滚动感觉更自然
          final scrollDuration = scrollDistance < 500 
              ? const Duration(milliseconds: 300) 
              : Duration(milliseconds: 300 + (scrollDistance / 10).clamp(0, 500).toInt());
          
          // 使用动画曲线使滚动更平滑
          widget.scrollController.animateTo(
            targetOffset,
            duration: scrollDuration,
            curve: Curves.easeOutCubic, // 使用更平滑的缓动曲线
          );
          
          AppLogger.i('EditorMainArea', '平滑滚动到活动场景: $sceneId，距离: ${scrollDistance.toInt()}px，时长: ${scrollDuration.inMilliseconds}ms');
        } catch (e) {
          AppLogger.e('EditorMainArea', '平滑滚动计算失败，回退到标准滚动', e);
          // 回退到标准滚动方法
          scrollToActiveScene();
        }
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

  // 清理长时间不可见的场景控制器，释放内存
  
  // 记录场景最后可见时间
  final Map<String, DateTime> _lastVisibleTime = {};

  // 根据活动场景更新可见项目
  void _updateVisibleItemsBasedOnActiveScene() {
    if (widget.activeActId == null || widget.activeChapterId == null) return;
    
    AppLogger.i('EditorMainArea', '根据活动场景更新可见项目');
    
    // 添加活动场景所在的Act和Chapter到可见项目
    _visibleActs[widget.activeActId!] = true;
    _visibleChapters['${widget.activeActId!}_${widget.activeChapterId!}'] = true;
    
    // 如果有活动场景，也将其标记为可见
    if (widget.activeSceneId != null) {
      final sceneId = '${widget.activeActId!}_${widget.activeChapterId!}_${widget.activeSceneId!}';
      _renderedScenes[sceneId] = true;
      _lastVisibleTime[sceneId] = DateTime.now();
    }
    
    // 强制更新UI
    setState(() {});
  }

  // 计算并更新估算的页面高度
  void _calculatePageHeight() {
    // 使用屏幕高度作为基础
    final screenHeight = MediaQuery.of(context).size.height;
    // 估算单个页面高度 (去除应用栏等UI元素高度)
    _estimatedPageHeight = screenHeight * 0.85;
    AppLogger.d('EditorMainArea', '计算页面高度: $_estimatedPageHeight');
  }

  // 新增方法：确定焦点章节
  void _updateFocusChapter([bool forceUpdate = false]) {
    if (!widget.scrollController.hasClients || !mounted) return;
    
    // 获取当前视口的中心点
    final scrollPosition = widget.scrollController.position;
    final viewportCenter = scrollPosition.pixels + (scrollPosition.viewportDimension / 2);
    
    // 记录最小距离和对应的章节
    double minDistance = double.infinity;
    String? closestChapterId;
    String? closestActId;
    
    // 临时记录每个Act中最近的章节，用于优化跨卷逻辑
    final Map<String, Map<String, double>> actToClosestChapters = {};
    
    // 如果启用了单卷模式且不是强制更新，则优先考虑当前焦点Act中的章节
    if (_enforceSingleActMode && _focusChapterId != null && !forceUpdate) {
      String? currentFocusActId;
      if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
        final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
        currentFocusActId = state.chapterToActMap[_focusChapterId!];
      } else {
        AppLogger.w('EditorMainArea', '_updateFocusChapter (single act mode): EditorBloc state is not EditorLoaded. Skipping optimization.');
      }

      if (currentFocusActId != null) {
        // 记录当前焦点Act中的章节和距离
        for (final entry in _chapterPositions.entries) {
          final chapterId = entry.key;
          final position = entry.value;
          
          // 查找章节所在的Act
          for (final act in widget.novel.acts) {
            if (act.id == currentFocusActId) {
              for (final chapter in act.chapters) {
                if (chapter.id == chapterId) {
                  // 计算距离
                  final distance = (position - viewportCenter).abs();
                  
                  // 如果是当前Act中的章节，并且距离更小，更新最近章节
                  if (distance < minDistance) {
                    minDistance = distance;
                    closestChapterId = chapterId;
                    closestActId = currentFocusActId;
                  }
                  
                  // 确保Act的记录存在
                  if (!actToClosestChapters.containsKey(currentFocusActId)) {
                    actToClosestChapters[currentFocusActId] = {};
                  }
                  
                  // 记录当前Act中的章节距离
                  actToClosestChapters[currentFocusActId]![chapterId] = distance;
                  
                  break;
                }
              }
              break;
            }
          }
        }
        
        // 如果在当前Act中找到了合适的章节，直接使用
        if (closestChapterId != null) {
          AppLogger.i('EditorMainArea', '单卷模式：保持在当前Act, 使用最近章节: $closestChapterId');
          
          // 如果找到了最近的章节且与当前焦点章节不同，更新焦点章节
          if (closestChapterId != _focusChapterId) {
            AppLogger.i('EditorMainArea', '更新本地焦点章节: ${_focusChapterId ?? '无'} -> $closestChapterId');
            setState(() {
              _focusChapterId = closestChapterId;
            });
            
            // 仅发送SetFocusChapter事件，不触发UI重建
            widget.editorBloc.add(editor_bloc.SetFocusChapter(
              chapterId: closestChapterId,
            ));
          }
          
          return;
        }
      }
    }
    
    // 如果单卷模式下没有找到合适的章节，或者未启用单卷模式，则常规查找
    // 统计每个章节的全局位置
    for (final entry in _chapterPositions.entries) {
      final chapterId = entry.key;
      final position = entry.value;
      
      // 找到章节所在的Act
      String? actId;
      if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
        final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
        actId = state.chapterToActMap[chapterId];
      } else {
        AppLogger.w('EditorMainArea', '_updateFocusChapter: EditorBloc state is not EditorLoaded. Skipping optimization.');
      }
      
      // 跳过没找到Act的章节
      if (actId == null) continue;
      
      // 确保Act的记录存在
      if (!actToClosestChapters.containsKey(actId)) {
        actToClosestChapters[actId] = {};
      }
      
      // 计算与视口中心的距离
      final distance = (position - viewportCenter).abs();
      
      // 记录当前Act中的章节距离
      actToClosestChapters[actId]![chapterId] = distance;
      
      // 如果距离更小，更新全局最近章节
      if (distance < minDistance) {
        minDistance = distance;
        closestChapterId = chapterId;
        closestActId = actId;
      }
    }
    
    // ===== 跨卷优化逻辑 =====
    // 如果当前焦点章节不为空，且启用了单卷模式，强制阻止跨卷切换
    if (_enforceSingleActMode && _focusChapterId != null && !forceUpdate) {
      // 获取当前焦点章节对应的Act
      String? currentFocusActId;
      final editorStateSnapshot = widget.editorBloc.state; // Use a snapshot to avoid race conditions with state changes
      if (editorStateSnapshot is editor_bloc.EditorLoaded) {
        currentFocusActId = editorStateSnapshot.chapterToActMap[_focusChapterId!];
      } else {
        AppLogger.w('EditorMainArea', '_updateFocusChapter (single act mode cross-volume check): EditorBloc state is not EditorLoaded. Skipping optimization.');
      }

      if (currentFocusActId != null) {
        // 如果有不同的Act，且都有可见章节
        if (currentFocusActId != closestActId &&
            actToClosestChapters.containsKey(currentFocusActId) &&
            actToClosestChapters[currentFocusActId]!.isNotEmpty) {
          
          // 查找当前焦点Act中最近的章节
          String? closestChapterInCurrentAct;
          double minDistanceInCurrentAct = double.infinity;
          
          actToClosestChapters[currentFocusActId]!.forEach((chapId, dist) {
            if (dist < minDistanceInCurrentAct) {
              minDistanceInCurrentAct = dist;
              closestChapterInCurrentAct = chapId;
            }
          });
          
          // 如果当前Act有在视图中的章节，则不切换Act
          if (closestChapterInCurrentAct != null) {
            // 单卷模式下，只要当前Act有可见章节，就强制保持在当前Act
            AppLogger.i('EditorMainArea', '单卷模式：强制保持在当前Act (${currentFocusActId})，不允许跨卷');
            closestChapterId = closestChapterInCurrentAct;
            minDistance = minDistanceInCurrentAct;
            closestActId = currentFocusActId;
          }
        }
      }
    }
    
    // 如果找到了最近的章节且与当前焦点章节不同，更新焦点章节
    if (closestChapterId != null && (closestChapterId != _focusChapterId || forceUpdate)) {
      AppLogger.i('EditorMainArea', '更新本地焦点章节: ${_focusChapterId ?? '无'} -> $closestChapterId (强制更新: $forceUpdate)');
      final bool focusActuallyChanged = closestChapterId != _focusChapterId;
      
      // 只有在焦点真正改变时才调用 setState
      if (focusActuallyChanged) {
        setState(() {
            _focusChapterId = closestChapterId;
        });
      } else if (forceUpdate && _focusChapterId == null && closestChapterId != null) {
        // 处理初始强制更新且之前焦点为空的情况
         setState(() {
            _focusChapterId = closestChapterId;
        });
      } // else if (forceUpdate and _focusChapterId == closestChapterId) no setState needed.
      
      // 只有在焦点真正改变时才通知 BLoC，或者在强制更新时
      if (focusActuallyChanged || forceUpdate) {
        widget.editorBloc.add(editor_bloc.SetFocusChapter(
          chapterId: closestChapterId,
        ));
      }
    } else if (closestChapterId == null && _focusChapterId != null) {
      // 如果没有找到最近章节（例如列表为空），但之前有焦点，清空它
      AppLogger.i('EditorMainArea', '未找到可见章节，清空焦点章节: $_focusChapterId -> null');
      setState(() {
        _focusChapterId = null;
      });
      // 通知 BLoC 焦点已清空
      widget.editorBloc.add(const editor_bloc.SetFocusChapter(chapterId: '')); // 使用空字符串或特定ID表示空
    }
  }

  // 新增：公共刷新方法，允许外部触发UI刷新
  void refreshUI() {
    AppLogger.i('EditorMainArea', '接收到强制刷新UI通知');
    
    // 强制刷新所有已渲染场景的状态
    _forceRefreshRenderedScenes();
    
    // 设置一个短暂延迟，确保在状态更新后进行UI刷新
    Future.microtask(() {
      if (mounted) {
        setState(() {
          // 刷新可见项目范围
          final scrollPosition = widget.scrollController.position;
          final viewportStart = scrollPosition.pixels;
          final viewportEnd = viewportStart + scrollPosition.viewportDimension;
          _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
          
          // 更新加载状态
          _loadingChapterIds.clear();
        });
      }
    });
  }
  
  // 修改：滚动监听器，优化以提高性能并及时更新焦点章节
  Timer? _focusUpdateTimer;
  
  // 修改：章节位置记录函数
  void _recordChapterPosition(String chapterId, double position) {
    _chapterPositions[chapterId] = position;
  }
  
  // 增加：更新可见项基于滚动边界的加载逻辑
  void _checkScrollBoundariesForLoading() {
    if (!widget.scrollController.hasClients) return;
    
    final scrollPosition = widget.scrollController.position;
    final currentOffset = scrollPosition.pixels;
    final maxScroll = scrollPosition.maxScrollExtent;
    
    // 判断是否接近顶部或底部
    const loadThreshold = 800.0; // 增加阈值，确保在接近边界时就开始加载
    
    if (currentOffset >= maxScroll - loadThreshold) {
      // 接近底部，加载更多下方内容
      _loadMoreInDirection('down'); // 使用已存在的_loadMoreInDirection方法
    } else if (currentOffset <= loadThreshold) {
      // 接近顶部，加载更多上方内容
      _loadMoreInDirection('up'); // 使用已存在的_loadMoreInDirection方法
    }
  }

  // 添加新方法：更新所有章节位置
  void _updateAllChapterPositions() {
    if (!mounted) return;
    
    AppLogger.d('EditorMainArea', '开始更新所有章节位置信息');
    
    // 记录原有的章节数
    final oldPositionsCount = _chapterPositions.length;
    
    for (final act in widget.novel.acts) {
      for (final chapter in act.chapters) {
        final chapterKeyString = 'chapter_${act.id}_${chapter.id}';
        final chapterKey = widget.sceneKeys[chapterKeyString];
        
        if (chapterKey != null) {
          try {
            // 添加额外安全检查
            if (!mounted || 
                chapterKey.currentContext == null || 
                !chapterKey.currentContext!.mounted) {
              continue;
            }
              
            final renderObject = chapterKey.currentContext!.findRenderObject();
            if (renderObject == null || !renderObject.attached) {
              continue;
            }
            
            final RenderBox box = renderObject as RenderBox;
            final position = box.localToGlobal(Offset.zero);
            _recordChapterPosition(chapter.id, position.dy);
          } catch (e) {
            // 使用try-catch包装，防止错误导致崩溃
            AppLogger.w('EditorMainArea', '在构建后记录章节位置失败: $chapterKeyString, 错误: ${e.toString()}');
          }
        }
      }
    }
    
    // 记录更新后的章节数
    final newPositionsCount = _chapterPositions.length;
    if (newPositionsCount > oldPositionsCount) {
      AppLogger.i('EditorMainArea', '章节位置信息已更新: $oldPositionsCount -> $newPositionsCount');
    }
  }

  // 新增方法：判断是否应该显示"添加新卷"按钮
  bool _shouldShowAddActButton() {
    if (widget.editorBloc.state is! editor_bloc.EditorLoaded) return false;
    
    final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
    
    // 如果没有Act，始终显示添加按钮
    if (widget.novel.acts.isEmpty) return true;
    
    // 检查是否是最后一个Act，且已经加载完毕
    if (state.hasReachedEnd && _focusChapterId != null) {
      // 查找焦点章节所在的Act
      String? focusActId;
      if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
        final editorStateLoaded = widget.editorBloc.state as editor_bloc.EditorLoaded;
        focusActId = editorStateLoaded.chapterToActMap[_focusChapterId!];
      } else {
        AppLogger.w('EditorMainArea', '_shouldShowAddActButton: EditorBloc state is not EditorLoaded.');
        for (final actLoop in widget.novel.acts) {
          for (final chapterLoop in actLoop.chapters) {
            if (chapterLoop.id == _focusChapterId) {
              focusActId = actLoop.id;
              break;
            }
          }
          if (focusActId != null) break;
        }
      }
      
      // 判断焦点Act是否是最后一个Act
      if (focusActId != null && focusActId == widget.novel.acts.last.id) {
        AppLogger.i('EditorMainArea', '当前焦点在最后一个Act且已到底部，显示添加新卷按钮');
        return true;
      }
    }
    
    return false;
  }

  // 添加新方法：明确设置活动章节
  void setActiveChapter(String actId, String chapterId) {
    AppLogger.i('EditorMainArea', '明确设置活动章节: $chapterId (ActId: $actId)');
    
    // 更新本地焦点章节
    setState(() {
      _focusChapterId = chapterId;
    });
    
    // 发送事件给EditorBloc更新活动章节
    widget.editorBloc.add(editor_bloc.SetActiveChapter(
      actId: actId,
      chapterId: chapterId,
    ));
  }

  // 判断当前所在Act是否为第一卷
  bool _isInFirstAct() {
    String? currentActId = _getCurrentFocusActId();
    if (currentActId == null || widget.novel.acts.isEmpty) return true;
    
    return currentActId == widget.novel.acts.first.id;
  }
  
  // 判断当前所在Act是否为最后一卷
  bool _isInLastAct() {
    String? currentActId = _getCurrentFocusActId();
    if (currentActId == null || widget.novel.acts.isEmpty) return true;
    
    // 修复：确保正确判断是否为最后一卷
    if (widget.novel.acts.length <= 1) return true;
    
    // 检查是否是最后一个非空卷
    return currentActId == widget.novel.acts.last.id;
  }

  // 获取当前所在Act的索引
  int _getCurrentActIndex() {
    String? currentActId = _getCurrentFocusActId();
    if (currentActId == null || widget.novel.acts.isEmpty) return -1;
    
    for (int i = 0; i < widget.novel.acts.length; i++) {
      if (widget.novel.acts[i].id == currentActId) {
        return i;
      }
    }
    
    return -1;
  }

  // 添加导航到上一卷的方法
  void _navigateToPreviousAct() {
    if (_isLoadingPreviousAct || _isLoadingNextAct) {
      AppLogger.i('EditorMainArea', '正在处理卷轴切换，忽略导航请求');
      return;
    }
    
    int currentActIndex = _getCurrentActIndex();
    if (currentActIndex <= 0 || currentActIndex >= widget.novel.acts.length) {
      AppLogger.w('EditorMainArea', '无法导航到上一卷：当前卷索引无效 ($currentActIndex)');
      return;
    }
    
    _isLoadingPreviousAct = true;
    setState(() {
      _isFullscreenLoading = true;
      _loadingMessage = '正在加载上一卷内容...';
    });
    
    final previousAct = widget.novel.acts[currentActIndex - 1];
    _targetActId = previousAct.id;

    // 如果上一卷有章节，则目标是最后一个章节；否则目标章节ID为null
    if (previousAct.chapters.isNotEmpty) {
      _targetChapterId = previousAct.chapters.last.id;
      AppLogger.i('EditorMainArea', '开始导航到上一卷: ${previousAct.title}, 目标章节: ${previousAct.chapters.last.title}');
    } else {
      _targetChapterId = null;
      AppLogger.i('EditorMainArea', '开始导航到上一卷: ${previousAct.title}, 该卷没有章节');
    }
    
    _isNavigatingToAct = true;
    widget.editorBloc.add(const editor_bloc.ResetActLoadingFlags());
    _cleanupCurrentActResources(exceptActId: previousAct.id);

    // 提前设置活动章节和焦点章节，确保导航目标明确
    // chapterId 传递 '' 如果 _targetChapterId 是 null
    widget.editorBloc.add(editor_bloc.SetActiveChapter(
      actId: _targetActId!,
      chapterId: _targetChapterId ?? '', 
    ));
    setState(() {
      _focusChapterId = _targetChapterId;
    });

    // 如果目标章节ID存在，则以此为中心加载；否则，尝试加载目标卷的开头
    // 注意: LoadMoreScenes 的 fromChapterId 需要有效值，这里用 _targetActId 作为 fallback
    // Bloc 需要能处理这种情况，即 fromChapterId 可能是一个 actId
    widget.editorBloc.add(editor_bloc.LoadMoreScenes(
      fromChapterId: _targetChapterId ?? _targetActId!, 
      direction: 'center', 
      chaptersLimit: 10, 
      actId: _targetActId!,  // 添加actId参数
      preventFocusChange: true, // 对于上一卷，我们通常希望保持在加载内容的末尾附近，所以阻止焦点自动改变
    ));
    
    _listenForActNavigationComplete();
  }
  
  // 添加导航到下一卷的方法
  void _navigateToNextAct() {
    if (_isLoadingPreviousAct || _isLoadingNextAct) {
      AppLogger.i('EditorMainArea', '正在处理卷轴切换，忽略导航请求');
      return;
    }
    
    int currentActIndex = _getCurrentActIndex();
    if (currentActIndex < 0 || currentActIndex >= widget.novel.acts.length - 1) {
      AppLogger.w('EditorMainArea', '无法导航到下一卷：当前卷索引无效或已是最后一卷 ($currentActIndex)');
      return;
    }
    
    _isLoadingNextAct = true;
    setState(() {
      _isFullscreenLoading = true;
      _loadingMessage = '正在加载下一卷内容...';
    });
    
    final nextAct = widget.novel.acts[currentActIndex + 1];
    _targetActId = nextAct.id;

    if (nextAct.chapters.isNotEmpty) {
      _targetChapterId = nextAct.chapters.first.id;
      AppLogger.i('EditorMainArea', '开始导航到下一卷: ${nextAct.title}, 目标章节: ${nextAct.chapters.first.title}');
    } else {
      _targetChapterId = null;
      AppLogger.i('EditorMainArea', '开始导航到下一卷: ${nextAct.title}, 该卷没有章节');
    }
    
    _isNavigatingToAct = true;
    widget.editorBloc.add(const editor_bloc.ResetActLoadingFlags());
    _cleanupCurrentActResources(exceptActId: nextAct.id);
    
    widget.editorBloc.add(editor_bloc.LoadMoreScenes(
      fromChapterId: _targetChapterId ?? _targetActId!, 
      direction: 'center', 
      chaptersLimit: 10,
      actId: _targetActId!,  // 添加actId参数
      preventFocusChange: _targetChapterId == null, 
    ));
    
    // chapterId 传递 '' 如果 _targetChapterId 是 null
    widget.editorBloc.add(editor_bloc.SetActiveChapter(
      actId: _targetActId!,
      chapterId: _targetChapterId ?? '', 
    ));
    
    setState(() {
      _focusChapterId = _targetChapterId;
    });
    
    _listenForActNavigationComplete();
  }

  // 添加新方法：清理当前卷资源
  void _cleanupCurrentActResources({String? exceptActId}) {
    if (!mounted) return;
    
    AppLogger.i('EditorMainArea', '开始清理当前卷资源，保留卷ID: ${exceptActId ?? "无"}');
    
    // 获取当前焦点Act
    final String? currentActId = _getCurrentFocusActId();
    if (currentActId == null || currentActId == exceptActId) return;
    
    int removedCount = 0;
    
    // 1. 清理当前卷的所有控制器
    final controllersToRemove = <String>[];
    final summaryControllersToRemove = <String>[];
    final keysToRemove = <String>[];
    
    // 遍历所有控制器找出当前卷的
    for (final entry in widget.sceneControllers.entries) {
      final sceneId = entry.key;
      final parts = sceneId.split('_');
      if (parts.length >= 3 && parts[0] == currentActId) {
        controllersToRemove.add(sceneId);
        summaryControllersToRemove.add(sceneId);
        
        // 同时也清理可见性记录
        _renderedScenes.remove(sceneId);
        _lastVisibleTime.remove(sceneId);
        
        removedCount++;
      }
    }
    
    // 清理场景控制器
    for (final sceneId in controllersToRemove) {
      try {
        widget.sceneControllers[sceneId]?.dispose();
        widget.sceneControllers.remove(sceneId);
      } catch (e) {
        AppLogger.e('EditorMainArea', '清理场景控制器失败: $sceneId', e);
      }
    }
    
    // 清理摘要控制器
    for (final sceneId in summaryControllersToRemove) {
      try {
        widget.sceneSummaryControllers[sceneId]?.dispose();
        widget.sceneSummaryControllers.remove(sceneId);
      } catch (e) {
        AppLogger.e('EditorMainArea', '清理摘要控制器失败: $sceneId', e);
      }
    }
    
    // 清理与当前卷相关的全局Key
    for (final entry in widget.sceneKeys.entries) {
      final keyId = entry.key;
      if (currentActId != null && (keyId.contains('act_$currentActId') || 
          keyId.contains('chapter_$currentActId') ||
          keyId.startsWith(currentActId + '_'))) {
        keysToRemove.add(keyId);
      }
    }
    
    // 清理全局Key，使用安全移除的方式
    for (final keyId in keysToRemove) {
      widget.sceneKeys.remove(keyId);
    }
    
    // 2. 清理章节位置记录
    final positionsToRemove = <String>[];
    for (final act in widget.novel.acts) {
      if (act.id == currentActId) {
        for (final chapter in act.chapters) {
          positionsToRemove.add(chapter.id);
        }
      }
    }
    
    for (final chapterId in positionsToRemove) {
      _chapterPositions.remove(chapterId);
    }
    
    // 3. 清理可见状态记录
    _visibleActs.remove(currentActId);
    final chaptersVisibilityToRemove = <String>[];
    for (final key in _visibleChapters.keys) {
      if (key.startsWith('${currentActId}_')) {
        chaptersVisibilityToRemove.add(key);
      }
    }
    
    for (final key in chaptersVisibilityToRemove) {
      _visibleChapters.remove(key);
    }
    
    // 4. 清理临时渲染记录
    final tempRenderToRemove = <String>[];
    _renderedScenes.forEach((key, _) {
      if (currentActId != null && key.startsWith(currentActId)) {
        tempRenderToRemove.add(key);
      }
    });
    
    for (final key in tempRenderToRemove) {
      _renderedScenes.remove(key);
    }
    
    // 5. 强制刷新UI
    setState(() {
      // 清空UI状态，强制重建
    });
    
    AppLogger.i('EditorMainArea', '已清理当前卷资源: 移除了 $removedCount 个控制器');
    
    // 确保将当前焦点从当前卷移除，有助于垃圾回收
    if (exceptActId != null && exceptActId != currentActId) {
      // 确保当前无焦点Act
      _visibleActs.remove(currentActId);
      
      // 强制刷新可见项目列表
      final List<String> newItems = _visibleItemsNotifier.value
          .where((item) => currentActId == null || !item.contains(currentActId))
          .toList();
      
      if (newItems.length != _visibleItemsNotifier.value.length) {
        AppLogger.i('EditorMainArea', '更新可见项目列表，移除当前卷项目');
        _visibleItemsNotifier.value = newItems;
      }
    }
  }
  
  // 添加创建新卷的方法
  void _addNewAct() {
    if (_isLoadingPreviousAct || _isLoadingNextAct) {
      AppLogger.i('EditorMainArea', '正在处理卷轴切换，忽略添加新卷请求');
      return;
    }
    
    AppLogger.i('EditorMainArea', '开始创建新卷');
    
    // 获取Context的祖先EditorScreenController实例
    final editorScreenController = Provider.of<EditorScreenController>(context, listen: false);
    
    // 使用EditorScreenController中的createNewAct方法
    editorScreenController.createNewAct().then((_) {
      if (mounted) {
        setState(() {
          _isFullscreenLoading = false;
        });
      }
    }).catchError((error) {
       AppLogger.e('EditorMainArea', '调用createNewAct失败', error);
       if (mounted) {
        setState(() {
          _isFullscreenLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: ${error.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }
  
  
  // 添加新方法：重置边界检查标志
  void _resetBoundaryFlags() {
    if (!mounted) return;
    
    AppLogger.i('EditorMainArea', '重置边界检查标志');
    
    // 重置hasReachedStart和hasReachedEnd标志
    widget.editorBloc.add(const editor_bloc.ResetActLoadingFlags());
    
    // 获取当前焦点Act的位置信息
    String? focusActId;
    if (widget.editorBloc.state is! editor_bloc.EditorLoaded) {
        AppLogger.w('EditorMainArea', '_resetBoundaryFlags: EditorBloc state is not EditorLoaded.');
        focusActId = _getCurrentFocusActId(); // Fallback if state not loaded
    } else {
        final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
        if (_focusChapterId != null && state.chapterToActMap.containsKey(_focusChapterId)) {
            focusActId = state.chapterToActMap[_focusChapterId!];
        } else if (widget.activeChapterId != null && state.chapterToActMap.containsKey(widget.activeChapterId)) {
            focusActId = state.chapterToActMap[widget.activeChapterId!];
        } else {
             focusActId = _getCurrentFocusActId(); // Fallback if no focus/active chapter or key not in map
        }
    }
    
    if (focusActId == null) return;
    
    int actIndex = widget.novel.acts.indexWhere((act) => act.id == focusActId);
    if (actIndex == -1) return;

    final novel_models.Act currentAct = widget.novel.acts[actIndex];
    
    // 如果是第一个Act，并且其第一个章节有内容，则设置hasReachedStart为true
    if (actIndex == 0) {
      if (currentAct.chapters.isNotEmpty && currentAct.chapters.first.scenes.isNotEmpty) {
        widget.editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedStart: true));
        AppLogger.i('EditorMainArea', '已设置hasReachedStart=true，当前卷是第一卷且首章有内容');
      } else {
        AppLogger.i('EditorMainArea', '当前卷是第一卷但首章无内容或无章节，hasReachedStart将由滚动加载逻辑确定');
      }
    }
    
    // 如果是最后一个Act，并且其最后一个章节有内容，则设置hasReachedEnd为true
    if (actIndex == widget.novel.acts.length - 1) {
      if (currentAct.chapters.isNotEmpty && currentAct.chapters.last.scenes.isNotEmpty) {
        widget.editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedEnd: true));
        AppLogger.i('EditorMainArea', '已设置hasReachedEnd=true，当前卷是最后一卷且末章有内容');
      } else {
        AppLogger.i('EditorMainArea', '当前卷是最后一卷但末章无内容或无章节，hasReachedEnd将由滚动加载逻辑确定');
      }
    }
  }
  
  // 新增辅助方法：滚动结束后更新可见项
  void _updateVisibleItemsAfterScroll() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if(mounted && widget.scrollController.hasClients){
             final scrollPosition = widget.scrollController.position;
             final viewportStart = scrollPosition.pixels;
             final viewportEnd = viewportStart + scrollPosition.viewportDimension;
             _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
             AppLogger.d('EditorMainArea', '滚动/导航结束后更新可见项目');
         }
      });
  }

  // 监听卷轴导航完成的方法
  void _listenForActNavigationComplete() {
    late StreamSubscription<editor_bloc.EditorState> subscription;

    subscription = widget.editorBloc.stream.listen((state) {
      if (state is editor_bloc.EditorLoaded && !state.isLoading) {
        subscription.cancel();

        // state 更新后，等待下一帧完成 UI 构建
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isNavigatingToAct) {
            _isNavigatingToAct = false; // 标记导航结束
            _isLoadingPreviousAct = false;
            _isLoadingNextAct = false;

            final targetActId = _targetActId; // 捕获当前目标ID
            final targetChapterId = _targetChapterId;

            // 清除导航状态变量 *之前* 异步操作
            _targetActId = null;
            _targetChapterId = null;

            if (targetActId != null && targetChapterId != null) {
              AppLogger.d('EditorMainArea', '导航加载完成，准备滚动到目标: Act=$targetActId, Chapter=$targetChapterId');

              // 再次确保焦点正确 (理论上 preventFocusChange=true 应该保证了，但多一步确认无妨)
              if (_focusChapterId != targetChapterId) {
                setState(() {
                  _focusChapterId = targetChapterId;
                });
                 widget.editorBloc.add(editor_bloc.SetActiveChapter(
                    actId: targetActId,
                    chapterId: targetChapterId,
                  ));
              }

              // 等待下一帧，确保目标 Widget 及其 Key 可用
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  final chapterKeyString = 'chapter_${targetActId}_$targetChapterId';
                  final chapterKey = widget.sceneKeys[chapterKeyString];

                  if (chapterKey?.currentContext != null) {
                    try {
                      Scrollable.ensureVisible(
                        chapterKey!.currentContext!,
                        alignment: 1.0, // 对齐到底部
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutCubic,
                      );
                      AppLogger.i('EditorMainArea',
                          '已成功滚动到目标卷的章节: Act=$targetActId, Chapter=$targetChapterId');

                      // 滚动动画完成后隐藏加载
                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (mounted) {
                          setState(() { _isFullscreenLoading = false; });
                          _resetBoundaryFlags();
                          // 滚动完成后，再次更新可见项目，以获得准确状态
                          _updateVisibleItemsAfterScroll();
                        }
                      });
                    } catch (e) {
                       AppLogger.e('EditorMainArea', '滚动到目标章节时出错 (Act=$targetActId, Chapter=$targetChapterId): ${e.toString()}');
                       if (mounted) {
                           setState(() { _isFullscreenLoading = false; });
                           _resetBoundaryFlags();
                           _updateVisibleItemsAfterScroll(); // 即使滚动失败也要更新
                       }
                    }
                  } else {
                     AppLogger.w('EditorMainArea', '无法滚动到目标章节，未找到Key或Context: Key=$chapterKeyString (Act=$targetActId, Chapter=$targetChapterId)');
                     if (mounted) {
                         setState(() { _isFullscreenLoading = false; });
                         _resetBoundaryFlags();
                         _updateVisibleItemsAfterScroll(); // 即使找不到Key也要更新
                     }
                  }
                }
              }); // End inner postFrameCallback
            } else {
              // 没有目标章节，直接隐藏加载
              AppLogger.w('EditorMainArea', '导航完成但没有目标章节ID，直接隐藏加载');
              if (mounted) {
                setState(() { _isFullscreenLoading = false; });
                _resetBoundaryFlags();
                _updateVisibleItemsAfterScroll();
              }
            }
          } // End if (mounted && _isNavigatingToAct)
        }); // End outer postFrameCallback
      } // End if (state is EditorLoaded && !state.isLoading)
    }); // End listen

    // 超时处理
    Future.delayed(const Duration(seconds: 10), () {
      subscription.cancel();
      if (mounted && _isNavigatingToAct) {
        setState(() {
          _isNavigatingToAct = false;
          _isLoadingPreviousAct = false;
          _isLoadingNextAct = false;
          _isFullscreenLoading = false;
        });
        AppLogger.w('EditorMainArea', '卷轴导航超时，已重置状态');
      }
    });
  }
}

