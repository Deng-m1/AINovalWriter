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
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
  
  // 虚拟列表配置
  double _estimatedPageHeight = 800.0; // 默认估计值
  double get _preloadDistance => _estimatedPageHeight * 2.5; // 动态计算预加载距离为2.5个页面高度
  ScrollMetrics? _lastReportedPosition;
  final ValueNotifier<List<String>> _visibleItemsNotifier = ValueNotifier<List<String>>([]);
  
  // 添加新的状态变量
  String? _focusChapterId; // 当前视口中心的章节ID
  
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
                
                // 更新所有章节位置信息
                _updateAllChapterPositions();
                
                // 更新可见项目
                _updateVisibleItemsBasedOnActiveScene();
                
                // 重新评估焦点章节，并强制更新
                _updateFocusChapter(true);
                
                // 确保所有新加载的场景都被标记为可见
                _forceRefreshRenderedScenes();
              });
            }
          });
        }
        
        // 如果焦点章节从BLoC状态变化，更新本地_focusChapterId
        if (mounted && _focusChapterId != state.activeChapterId && state.activeChapterId != null) {
          AppLogger.d('EditorMainArea', 'BLoC状态更新焦点章节: $_focusChapterId -> ${state.activeChapterId}');
          _focusChapterId = state.activeChapterId;
        }
      }
    });
  }
  
  // 新增方法：强制刷新所有已加载场景的渲染状态
  void _forceRefreshRenderedScenes() {
    // 记录已加载的场景总数，用于日志
    int scenesCount = 0;
    
    // 遍历所有Act、Chapter和Scene
    for (final act in widget.novel.acts) {
      for (final chapter in act.chapters) {
        for (final scene in chapter.scenes) {
          // 为每个场景生成ID
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';
          
          // 如果场景不在已渲染列表中，将其标记为已渲染并更新可见时间
          if (!_renderedScenes.containsKey(sceneId)) {
            _renderedScenes[sceneId] = true;
            _lastVisibleTime[sceneId] = DateTime.now();
            scenesCount++;
          }
        }
      }
    }
    
    if (scenesCount > 0) {
      AppLogger.i('EditorMainArea', '已强制刷新 $scenesCount 个新场景的渲染状态');
    }
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
    widget.scrollController.addListener(() {
      // 使用计时器节流更新焦点，避免高频率更新
      if (_focusUpdateTimer == null || !_focusUpdateTimer!.isActive) {
        _focusUpdateTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            // 先更新所有章节位置，然后再更新焦点
            _updateAllChapterPositions();
            _updateFocusChapter();
          }
        });
      }
      
      // 同时检查滚动到边界的情况，以便加载更多内容
      _checkScrollBoundariesForLoading();
    });
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
    
    // 判断滚动方向
    double? lastPosition = _lastScrollPosition;
    bool isScrollingUp = lastPosition != null && currentPosition < lastPosition;
    
    _lastScrollPosition = currentPosition;
    
    // 如果向上滚动，降低检查阈值，更积极地加载上方内容
    if (isScrollingUp) {
      final threshold = widget.scrollController.position.viewportDimension * 0.3; // 更积极的阈值
      final nearTop = currentPosition <= threshold;
      
      if (nearTop) {
        AppLogger.i('EditorMainArea', '向上滚动接近顶部，主动加载上方内容');
        _loadMoreInDirection('up', priority: true);
      }
    }
    
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
      
      // 如果已经到达内容底部，并且不在第一个Act，也跳过检查
      if (state.hasReachedEnd && _focusChapterId != null) {
        String? focusActId = null;
        for (final act in widget.novel.acts) {
          for (final chapter in act.chapters) {
            if (chapter.id == _focusChapterId) {
              focusActId = act.id;
              break;
            }
          }
          if (focusActId != null) break;
        }
        
        // 如果焦点Act不是最后一个Act，还应该继续加载
        bool isLastAct = false;
        if (focusActId != null) {
          isLastAct = widget.novel.acts.last.id == focusActId;
        }
        
        // 如果不是最后一个Act，查找下一个Act的第一个章节作为加载起点
        if (!isLastAct && focusActId != null) {
          int actIndex = -1;
          for (int i = 0; i < widget.novel.acts.length; i++) {
            if (widget.novel.acts[i].id == focusActId) {
              actIndex = i;
              break;
            }
          }
          
          if (actIndex >= 0 && actIndex + 1 < widget.novel.acts.length) {
            final nextAct = widget.novel.acts[actIndex + 1];
            if (nextAct.chapters.isNotEmpty) {
              final nextChapter = nextAct.chapters.first;
              
              AppLogger.i('EditorMainArea', '已到达当前Act底部，继续加载下一个Act的内容');
              
              widget.editorBloc.add(editor_bloc.LoadMoreScenes(
                fromChapterId: nextChapter.id,
                direction: 'center',
                chaptersLimit: 3,
                preventFocusChange: true,
              ));
              
              // 重置标志，允许加载下一个Act
              if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
                widget.editorBloc.add(editor_bloc.ResetActLoadingFlags());
              }
              
              return;
            }
          }
        }
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
  void _loadMoreInDirection(String direction, {bool priority = false}) {
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
        AppLogger.d('EditorMainArea', '有正在进行的加载，跳过加载请求');
        return;
      }
      
      // 检查是否已到达内容边界
      if ((direction == 'up' && state.hasReachedStart) || 
          (direction == 'down' && state.hasReachedEnd)) {
        
        // 如果已经到达边界但仍有空章节，说明需要加载下一个Act的内容
        if (direction == 'down' && state.hasReachedEnd) {
          AppLogger.i('EditorMainArea', '已到达当前Act底部，尝试加载下一个Act的内容');
          
          // 查找当前焦点章节
          if (_focusChapterId != null) {
            String? focusActId = null;
            for (final act in widget.novel.acts) {
              for (final chapter in act.chapters) {
                if (chapter.id == _focusChapterId) {
                  focusActId = act.id;
                  break;
                }
              }
              if (focusActId != null) break;
            }
            
            // 查找焦点Act之后的第一个Act
            if (focusActId != null) {
              int actIndex = -1;
              for (int i = 0; i < widget.novel.acts.length; i++) {
                if (widget.novel.acts[i].id == focusActId) {
                  actIndex = i;
                  break;
                }
              }
              
              // 如果找到了焦点Act且不是最后一个，尝试加载下一个Act的第一个章节
              if (actIndex >= 0 && actIndex + 1 < widget.novel.acts.length) {
                final nextAct = widget.novel.acts[actIndex + 1];
                if (nextAct.chapters.isNotEmpty) {
                  final nextChapter = nextAct.chapters.first;
                  
                  AppLogger.i('EditorMainArea', 
                      '加载下一个Act的内容: 从 ${nextAct.title} 的第一个章节开始');
                  
                  // 标记章节为加载中状态
                  _markChapterAsLoading(nextChapter.id);
                  
                  // 重置标志并加载下一个Act的内容
                  widget.editorBloc.add(editor_bloc.ResetActLoadingFlags());
                  
                  // 使用center加载模式，确保能获取到足够的内容
                  widget.editorBloc.add(editor_bloc.LoadMoreScenes(
                    fromChapterId: nextChapter.id,
                    direction: 'center',
                    chaptersLimit: 5, // 增加章节数量以获取更多内容
                    preventFocusChange: true,
                  ));
                  
                  // 强制刷新UI以显示加载状态
                  setState(() {});
                  return;
                }
              }
            }
          }
        }
        
        AppLogger.d('EditorMainArea', '已到达${direction == 'up' ? '顶部' : '底部'}，跳过加载请求');
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
              
              // 强制刷新所有渲染的场景
              _forceRefreshRenderedScenes();
              
              // 更新可见项目范围
              _updateVisibleItems(0, double.infinity);
              
              // 设置一个短暂延迟后重新扫描可见区域
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  final scrollPosition = widget.scrollController.position;
                  final viewportStart = scrollPosition.pixels;
                  final viewportEnd = viewportStart + scrollPosition.viewportDimension;
                  _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
                  
                  AppLogger.i('EditorMainArea', '已完成延迟扫描可见区域');
                }
              });
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
          if (isLoadingMore)
            _buildLoadingOverlay(),
        ],
      ),
    );
  }
  
  // 创建一个加载动画覆盖层，类似社交媒体应用
  Widget _buildLoadingOverlay() {
    String loadingMessage = '正在加载更多内容...';
    
    // 检查是否有更具体的加载状态
    if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
      final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
      
      // 确定当前焦点章节所在的Act
      String? focusActTitle;
      if (_focusChapterId != null) {
        for (final act in widget.novel.acts) {
          for (final chapter in act.chapters) {
            if (chapter.id == _focusChapterId) {
              focusActTitle = act.title;
              break;
            }
          }
          if (focusActTitle != null) break;
        }
      }
      
      // 根据已到达边界状态和焦点Act设置更具体的消息
      if (state.hasReachedEnd && focusActTitle != null) {
        loadingMessage = '$focusActTitle 已加载完成，正在加载下一卷内容...';
      } else if (state.hasReachedStart && focusActTitle != null) {
        loadingMessage = '$focusActTitle 顶部内容已加载完成';
      }
    }
    
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
                  loadingMessage,
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
  
  // 替换原来的_buildOptimizedScrollView方法
  Widget _buildVirtualizedScrollView(BuildContext context, bool isLoadingMore) {
    return CustomScrollView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      clipBehavior: Clip.hardEdge,
      slivers: [
        // 如果已到顶部，显示顶部提示
        if (widget.editorBloc.state is editor_bloc.EditorLoaded && 
            (widget.editorBloc.state as editor_bloc.EditorLoaded).hasReachedStart)
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
                              // 只构建需要显示的Act
                              ...widget.novel.acts
                                  .where((act) => _shouldRenderAct(act))
                                  .map((act) => _buildVirtualizedActSection(act, visibleItems)),
                            ],
                          );
                        },
                      ),
                      
                      // 添加新Act按钮
                      _AddActButton(editorBloc: widget.editorBloc),
                      
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
        if (widget.editorBloc.state is editor_bloc.EditorLoaded && 
            (widget.editorBloc.state as editor_bloc.EditorLoaded).hasReachedEnd)
          SliverToBoxAdapter(child: _buildEndOfContentIndicator(false)),
      ],
    );
  }
  
  // 添加一个方法来创建"已到达内容边界"的指示器
  Widget _buildEndOfContentIndicator(bool isTop) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: Text(
          isTop ? '已到达顶部，没有更多内容' : '已到达底部，没有更多内容',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
  
  // 处理滚动通知，更新可见项目
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      
      // 存储滚动位置信息
      _lastReportedPosition = metrics;
      
      // 计算视口边界
      final viewportStart = metrics.pixels;
      final viewportEnd = metrics.pixels + metrics.viewportDimension;
      
      // 更新可见项目
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // 先更新可见项目
          _updateVisibleItems(viewportStart - _preloadDistance, viewportEnd + _preloadDistance);
          
          // 然后确定焦点章节
          _updateFocusChapter(); // 移除错误的double参数
        }
      });
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
    // 获取当前EditorLoaded状态，检查是否正在加载更多场景
    bool isLoadingMore = false;
    bool hasReachedEnd = false;
    if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
      final state = widget.editorBloc.state as editor_bloc.EditorLoaded;
      isLoadingMore = state.isLoading;
      hasReachedEnd = state.hasReachedEnd;
    }

    // 如果正在加载场景，只渲染当前可见的Act
    if (isLoadingMore) {
      // 找到当前活动Act或焦点Act
      String? currentActId = null;
      
      // 如果有焦点章节，找到其所在的Act
      if (_focusChapterId != null) {
        for (final currentAct in widget.novel.acts) {
          for (final chapter in currentAct.chapters) {
            if (chapter.id == _focusChapterId) {
              currentActId = currentAct.id;
              break;
            }
          }
          if (currentActId != null) break;
        }
      }
      
      // 如果没有找到焦点章节的Act，则使用活动章节的Act
      if (currentActId == null && widget.activeChapterId != null) {
        for (final currentAct in widget.novel.acts) {
          for (final chapter in currentAct.chapters) {
            if (chapter.id == widget.activeChapterId) {
              currentActId = currentAct.id;
              break;
            }
          }
          if (currentActId != null) break;
        }
      }
      
      // 如果找到当前Act，则只渲染当前Act
      if (currentActId != null) {
        return act.id == currentActId;
      }
    }

    // 如果没有焦点章节，允许渲染所有Act
    if (_focusChapterId == null) return true;

    // 找到焦点章节所在的Act
    String? focusActId;
    for (final currentAct in widget.novel.acts) {
      for (final chapter in currentAct.chapters) {
        if (chapter.id == _focusChapterId) {
          focusActId = currentAct.id;
          break;
        }
      }
      if (focusActId != null) break;
    }

    // 如果找不到焦点章节所在的Act，允许渲染所有Act
    if (focusActId == null) return true;

    // 如果是焦点章节所在的Act，允许渲染
    if (act.id == focusActId) return true;

    // 获取Acts的顺序索引
    int focusActIndex = -1;
    int currentActIndex = -1;
    for (int i = 0; i < widget.novel.acts.length; i++) {
      if (widget.novel.acts[i].id == focusActId) {
        focusActIndex = i;
      }
      if (widget.novel.acts[i].id == act.id) {
        currentActIndex = i;
      }
      if (focusActIndex >= 0 && currentActIndex >= 0) break;
    }
    
    // 如果是焦点Act之前的Act，允许渲染
    if (currentActIndex < focusActIndex) return true;
    
    // 如果是焦点Act之后的Act，只有在以下条件满足时才渲染：
    // 1. 焦点Act已完全加载完成（所有章节都有场景）
    // 2. 系统状态标记为已到达底部
    
    // 检查焦点Act是否所有章节都已加载
    bool focusActFullyLoaded = true;
    final focusAct = widget.novel.acts[focusActIndex];
    for (final chapter in focusAct.chapters) {
      if (chapter.scenes.isEmpty) {
        focusActFullyLoaded = false;
        break;
      }
    }
    
    // 如果焦点Act未完全加载，不渲染后续Act
    if (!focusActFullyLoaded) return false;
    
    // 如果已到达底部，允许渲染下一个Act
    if (hasReachedEnd && currentActIndex == focusActIndex + 1) {
    return true;
  }
  
    // 检查前面所有的Act是否都已完全加载
    for (int i = 0; i < currentActIndex; i++) {
      final previousAct = widget.novel.acts[i];
      for (final chapter in previousAct.chapters) {
        if (chapter.scenes.isEmpty) {
          // 如果发现任何前面Act的章节未加载，则不渲染当前Act
          return false;
        }
      }
    }

    // 默认情况下不渲染焦点Act之后的Act，除非前面的逻辑已明确允许
    return false;
  }
  
  // 判断章节是否应该被渲染，使用简单的距离判断
  bool _shouldRenderChapter(String actId, String chapterId) {
    // 如果章节所在Act没有章节或章节数很少，渲染全部
    final act = widget.novel.acts.firstWhere((a) => a.id == actId);
    if (act.chapters.isEmpty || act.chapters.length <= 5) {
      return true;
    }
    
    // 始终渲染活动章节和焦点章节
    if (widget.activeChapterId == chapterId || _focusChapterId == chapterId) {
      AppLogger.i('EditorMainArea', '章节$chapterId是${widget.activeChapterId == chapterId ? "活动" : "焦点"}章节，渲染');
      return true;
    }
    
    // 获取用于判断的参考章节ID（优先使用焦点章节，其次是活动章节）
    final referenceChapterId = _focusChapterId ?? widget.activeChapterId;
    if (referenceChapterId == null) {
      // 如果没有参考章节，默认渲染所有章节
      return true;
    }
    
    // 查找参考章节所在的Act和索引位置
    String? referenceActId;
    int referenceGlobalIndex = -1;
    int currentGlobalIndex = -1;
    int globalIndex = 0;
    
    // 第一次遍历：找出所有章节的全局索引
    final Map<String, int> chapterGlobalIndices = {};
    for (final currentAct in widget.novel.acts) {
      for (final chapter in currentAct.chapters) {
        chapterGlobalIndices[chapter.id] = globalIndex++;
        
        if (chapter.id == referenceChapterId) {
          referenceActId = currentAct.id;
          referenceGlobalIndex = chapterGlobalIndices[chapter.id]!;
        }
        
        if (chapter.id == chapterId) {
          currentGlobalIndex = chapterGlobalIndices[chapter.id]!;
        }
      }
    }
    
    // 如果找不到索引，不渲染
    if (referenceGlobalIndex == -1 || currentGlobalIndex == -1) {
      return false;
    }
    
    // 判断是否在参考章节上下距离范围内（使用全局索引，允许跨卷）
    // 增加渲染距离到10章，确保更多章节可见
    final distance = (currentGlobalIndex - referenceGlobalIndex).abs();
    final shouldRender = distance <= 10; // 从5增加到10，增加可见章节范围
    
    // 日志标记是否为跨卷判断
    final isCrossAct = referenceActId != actId;
    AppLogger.i('EditorMainArea', 
        '章节$chapterId与${_focusChapterId == referenceChapterId ? "焦点" : "活动"}章节距离${distance}章${isCrossAct ? "(跨卷)" : ""}，${shouldRender ? "渲染" : "不渲染"}');
    
    return shouldRender;
  }
  
  // 优化的Act Section构建器
  Widget _buildVirtualizedActSection(novel_models.Act act, List<String> visibleItems) {
    final isActVisible = true; // 总是将Act视为可见
    
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
              .map((chapter) => _buildVirtualizedChapterSection(act.id, chapter, visibleItems))
              .toList(),
          actId: act.id,
          editorBloc: widget.editorBloc,
          totalChaptersCount: act.chapters.length,
          loadedChaptersCount: act.chapters.where((chapter) => chapter.scenes.isNotEmpty).length,
        ),
      ),
    );
  }
  
  // 优化的Chapter Section构建器
  Widget _buildVirtualizedChapterSection(
      String actId, novel_models.Chapter chapter, List<String> visibleItems) {
    // 创建章节Key
    final chapterKeyString = 'chapter_${actId}_${chapter.id}';
    if (!widget.sceneKeys.containsKey(chapterKeyString)) {
      widget.sceneKeys[chapterKeyString] = GlobalKey();
    }
    final chapterKey = widget.sceneKeys[chapterKeyString]!;
    
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
              _buildVirtualizedSceneList(actId, chapter, visibleItems),
          actId: actId,
          chapterId: chapter.id,
          editorBloc: widget.editorBloc,
        ),
      ),
    );
  }
  
  // 优化的Scene列表构建器
  List<Widget> _buildVirtualizedSceneList(
      String actId, novel_models.Chapter chapter, List<String> visibleItems) {
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
      
      // 判断场景是否为活动场景
      final bool isActiveScene = isActiveChapter && currentActiveSceneId == scene.id;
      
      if (isActiveScene) {
        AppLogger.i('EditorMainArea', '章节${chapter.id}中的场景${scene.id}是活动场景');
      }
      
      scenes.add(
        _VirtualizedSceneLoader(
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
          isVisible: true, // 强制所有场景可见
          onVisibilityChanged: (isVisible) {
            // 记录时间以便清理
            _lastVisibleTime[sceneId] = DateTime.now();
          },
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
      
      // 检查是否是纯文本（非JSON格式）
      bool isPlainText = false;
      try {
        jsonDecode(content);
      } catch (e) {
        isPlainText = true;
      }
      
      // 如果是纯文本，直接转换为Quill格式
      if (isPlainText) {
        return Document.fromJson([
          {'insert': '$content\n'}
        ]);
      }
      
      // 使用QuillHelper处理内容格式
      final String standardContent = QuillHelper.ensureQuillFormat(content);
      
      try {
        // 解析为JSON，确保正确的格式
        final List<dynamic> delta = jsonDecode(standardContent) as List<dynamic>;
        return Document.fromJson(delta);
      } catch (e) {
        AppLogger.e('EditorMainArea', '解析标准化内容仍然失败，使用安全格式', e);
        // 如果仍然失败，提取内容作为纯文本
        return Document.fromJson([
          {'insert': content.isEmpty ? '\n' : '$content\n'}
        ]);
      }
    } catch (e) {
      AppLogger.e('EditorMainArea', '解析场景内容失败，使用空文档', e);
      // 返回空文档，避免显示错误信息
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

  // 清理长时间不可见的场景控制器，释放内存
  void _cleanupInvisibleScenes() {
    if (!mounted) return;
    
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    // 找出超过5分钟未见的场景
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
      AppLogger.i('EditorMainArea', '清理长时间不可见场景: $sceneId');
    }
  }
  
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
    if (!widget.scrollController.hasClients) return;
    
    // 获取当前视口的中心点
    final scrollPosition = widget.scrollController.position;
    final viewportCenter = scrollPosition.pixels + (scrollPosition.viewportDimension / 2);
    
    // 记录最小距离和对应的章节
    double minDistance = double.infinity;
    String? closestChapterId;
    String? closestActId; // 添加变量，保存找到的章节所属的actId
    
    // 统计每个章节的全局位置
    for (final entry in _chapterPositions.entries) {
      final chapterId = entry.key;
      final position = entry.value;
      
      // 计算与视口中心的距离
      final distance = (position - viewportCenter).abs();
      
      // 如果距离更小，更新最近章节
      if (distance < minDistance) {
        minDistance = distance;
        closestChapterId = chapterId;
      }
    }
    
    // 如果找到了最近的章节，查找对应的actId
    if (closestChapterId != null) {
      for (final act in widget.novel.acts) {
        for (final chapter in act.chapters) {
          if (chapter.id == closestChapterId) {
            closestActId = act.id;
            break;
          }
        }
        if (closestActId != null) break;
      }
    }
    
    // 如果找到了最近的章节且与当前焦点章节不同，更新焦点章节
    if (closestChapterId != null && closestActId != null && 
        (closestChapterId != _focusChapterId || forceUpdate)) {
      AppLogger.i('EditorMainArea', '更新焦点章节: ${_focusChapterId ?? '无'} -> $closestChapterId');
      _focusChapterId = closestChapterId;
      
      // 通知EditorBloc更新活动章节，添加必需的actId参数
      widget.editorBloc.add(SetActiveChapter(
        actId: closestActId,
        chapterId: closestChapterId,
      ));
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
        
        if (chapterKey?.currentContext != null) {
          try {
            final RenderBox box = chapterKey!.currentContext!.findRenderObject() as RenderBox;
            final position = box.localToGlobal(Offset.zero);
            _recordChapterPosition(chapter.id, position.dy);
          } catch (e) {
            AppLogger.w('EditorMainArea', '获取章节位置失败: $chapterKeyString, 错误: $e');
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
}

class _AddActButton extends StatefulWidget {
  const _AddActButton({required this.editorBloc});
  final editor_bloc.EditorBloc editorBloc;

  @override
  State<_AddActButton> createState() => _AddActButtonState();
}

class _AddActButtonState extends State<_AddActButton> {
  bool _isAdding = false;
  DateTime? _lastAddTime;
  
  // 防抖时间间隔（2秒）
  static const Duration _debounceInterval = Duration(seconds: 2);

  void _addNewAct() {
    // 防止频繁点击导致重复添加
    final now = DateTime.now();
    if (_isAdding || (_lastAddTime != null && 
        now.difference(_lastAddTime!) < _debounceInterval)) {
      // 如果正在添加中或最后添加时间在2秒内，忽略此次点击
      AppLogger.i('_AddActButton', '忽略重复点击: 正在添加=${_isAdding}, 距上次点击=${_lastAddTime != null ? now.difference(_lastAddTime!).inMilliseconds : "首次点击"}ms');
      
      // 显示提示（仅在UI上）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('操作正在处理中，请稍候...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    
    // 记录当前时间并标记为添加中
    _lastAddTime = now;
    setState(() {
      _isAdding = true;
    });
    
    // 添加新Act
    AppLogger.i('_AddActButton', '触发添加新Act事件');
    widget.editorBloc.add(const editor_bloc.AddNewAct(title: '新Act'));
    
    // 延迟2秒后重置状态，无论添加是否成功
    Future.delayed(_debounceInterval, () {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: OutlinedButton.icon(
          onPressed: _isAdding ? null : _addNewAct, // 如果正在添加中，禁用按钮
          icon: _isAdding 
              ? SizedBox(
                  width: 18, 
                  height: 18, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                )
              : const Icon(Icons.add, size: 18),
          label: Text(_isAdding ? '添加中...' : '添加新Act'),
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

// 替换原来的_LazySceneLoader组件
class _VirtualizedSceneLoader extends StatefulWidget {
  const _VirtualizedSceneLoader({
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
    required this.isVisible,
    required this.onVisibilityChanged,
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
  final bool isVisible;
  final Function(bool) onVisibilityChanged;

  @override
  State<_VirtualizedSceneLoader> createState() => _VirtualizedSceneLoaderState();
}

class _VirtualizedSceneLoaderState extends State<_VirtualizedSceneLoader> {
  bool _isInitialized = false;
  bool _isControllerInitializing = false; // 添加标志避免重复初始化

  @override
  void initState() {
    super.initState();
    
    // 如果是活动场景或已标记为可见，立即初始化
    if (widget.isActive || widget.isVisible) {
      _initializeControllers();
    }
  }
  
  @override
  void didUpdateWidget(_VirtualizedSceneLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当状态发生变化时初始化控制器
    if (!_isInitialized && !_isControllerInitializing) {
      // 优先检查活动状态变化，这是最重要的
      if (widget.isActive && !oldWidget.isActive) {
        AppLogger.i('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为活动状态，立即初始化');
        _initializeControllers();
      } 
      // 其次检查可见性变化
      else if (widget.isVisible && !oldWidget.isVisible) {
        AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为可见状态，初始化控制器');
        _initializeControllers();
      }
    }
    
    // 当可见性状态变化时，通知父组件
    if (widget.isVisible != oldWidget.isVisible) {
      widget.onVisibilityChanged(widget.isVisible);
    }
    
    // 如果场景变为活动状态，但之前不是活动状态，强制刷新UI
    if (widget.isActive && !oldWidget.isActive && _isInitialized) {
      setState(() {
        AppLogger.i('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为活动状态，刷新UI');
      });
    }
  }
  
  // 初始化控制器
  void _initializeControllers() {
    if (_isInitialized || _isControllerInitializing) return;
    
    _isControllerInitializing = true; // 设置标志防止重复初始化
    
    try {
      // 使用隔离初始化以避免主线程阻塞
      compute<String, Document>(_parseDocumentInIsolate, widget.scene.content)
        .then((document) {
          if (mounted) {
            widget.sceneControllers[widget.sceneId] = QuillController(
              document: document,
              selection: const TextSelection.collapsed(offset: 0),
            );
            
            widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
              text: widget.scene.summary.content,
            );
            
            // 确保更新状态以反映控制器已初始化
            setState(() {
              _isInitialized = true;
              _isControllerInitializing = false;
              AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 控制器初始化完成');
            });
          } else {
            _isControllerInitializing = false;
          }
        })
        .catchError((e) {
          AppLogger.e('VirtualizedSceneLoader', 
              '通过隔离初始化文档失败: ${widget.sceneId}', e);
          
          // 回退到同步初始化
          if (mounted) {
            widget.sceneControllers[widget.sceneId] = QuillController(
              document: widget.parseDocumentSafely(widget.scene.content),
              selection: const TextSelection.collapsed(offset: 0),
            );
            
            widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
              text: widget.scene.summary.content,
            );
            
            setState(() {
              _isInitialized = true;
              _isControllerInitializing = false;
              AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 控制器同步初始化完成');
            });
          } else {
            _isControllerInitializing = false;
          }
        });
    } catch (e) {
      AppLogger.e('VirtualizedSceneLoader', 
          '创建场景控制器失败: ${widget.sceneId}', e);
      
      if (mounted) {
        widget.sceneControllers[widget.sceneId] = QuillController(
          document: Document.fromJson([{'insert': '\n'}]),
          selection: const TextSelection.collapsed(offset: 0),
        );
        
        widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
          text: '',
        );
        
        setState(() {
          _isInitialized = true;
          _isControllerInitializing = false;
        });
      } else {
        _isControllerInitializing = false;
      }
    }
    
    // 确保有GlobalKey
    if (!widget.sceneKeys.containsKey(widget.sceneId)) {
      widget.sceneKeys[widget.sceneId] = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 当场景是活动状态但尚未初始化时，立即初始化
    if (widget.isActive && !_isInitialized && !_isControllerInitializing) {
      AppLogger.i('VirtualizedSceneLoader', '场景 ${widget.sceneId} 在构建时检测到活动状态但未初始化，立即初始化');
      _initializeControllers();
    }
    
    // 使用VisibilityDetector检测真实可见性
    return VisibilityDetector(
      key: ValueKey('visibility_${widget.sceneId}'),
      onVisibilityChanged: (visibilityInfo) {
        // 计算可见比例
        var visiblePercentage = visibilityInfo.visibleFraction * 100;
        
        // 优化日志输出：仅在可见性显著变化时记录
        final bool wasVisible = widget.isVisible;
        bool isNowVisible = false;
        
        // 关键修改：如果当前为活动章节的场景，始终视为可见
        if (widget.actId == widget.editorBloc.state is editor_bloc.EditorLoaded && 
            (widget.editorBloc.state as editor_bloc.EditorLoaded).activeChapterId == widget.chapterId) {
          isNowVisible = true;
          if (!wasVisible) {
            AppLogger.i('VirtualizedSceneLoader', '场景 ${widget.sceneId} 在活动章节中，强制设为可见');
            widget.onVisibilityChanged(true);
          }
        } 
        // 正常可见性检测：当可见性比例大于5%视为可见 (提高比例以减少边缘场景被当作可见)
        else if (visiblePercentage > 5) {
          isNowVisible = true;
          if (!wasVisible) {
            AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为可见 (${visiblePercentage.toStringAsFixed(1)}%)');
            widget.onVisibilityChanged(true);
          }
        } 
        // 当可见性接近0时视为不可见
        else if (visiblePercentage <= 0.1 && wasVisible) {
          isNowVisible = false;
          AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为不可见');
          widget.onVisibilityChanged(false);
        }
        
        // 如果场景可见但未初始化，立即初始化
        if (isNowVisible && !_isInitialized && !_isControllerInitializing) {
          _initializeControllers();
        }
      },
      child: _buildSceneContent(),
    );
  }
  
  Widget _buildSceneContent() {
    // 如果控制器未初始化，显示占位符
    if (!_isInitialized || 
        !widget.sceneControllers.containsKey(widget.sceneId)) {
      return _buildPlaceholder();
    }
    
    // 使用RepaintBoundary包装每个场景编辑器，防止不必要的重绘
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
      height: 100,
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

// 在隔离中解析文档内容
Document _parseDocumentInIsolate(String content) {
  try {
    if (content.isEmpty) {
      return Document.fromJson([{'insert': '\n'}]);
    }
    
    // 检查是否是纯文本
    bool isPlainText = false;
    try {
      jsonDecode(content);
    } catch (e) {
      isPlainText = true;
    }
    
    // 如果是纯文本，直接转换为Quill格式
    if (isPlainText) {
      return Document.fromJson([
        {'insert': '$content\n'}
      ]);
    }
    
    // 解析JSON格式
    try {
      final List<dynamic> delta = jsonDecode(content) as List<dynamic>;
      return Document.fromJson(delta);
    } catch (e) {
      // 如果解析失败，作为纯文本处理
      return Document.fromJson([
        {'insert': content.isEmpty ? '\n' : '$content\n'}
      ]);
    }
  } catch (e) {
    // 返回空文档
    return Document.fromJson([{'insert': '\n'}]);
  }
}
