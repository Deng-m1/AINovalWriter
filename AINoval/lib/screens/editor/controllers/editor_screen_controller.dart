import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/blocs/plan/plan_bloc.dart' as plan_bloc;
import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/components/editor_main_area.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/prompt_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/services/sync_service.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' hide EditorState;
import 'package:collection/collection.dart'; // Add this line

// 添加这些顶层定义，放在import语句之后，类定义之前
// 滚动状态枚举
enum ScrollState { idle, userScrolling, inertialScrolling }

// 滚动信息类，包含速度和是否快速滚动的标志
class _ScrollInfo {
  final double speed;
  final bool isRapid;
  
  _ScrollInfo(this.speed, this.isRapid);
}

/// 编辑器屏幕控制器
/// 负责管理编辑器屏幕的状态和逻辑
class EditorScreenController extends ChangeNotifier {
  EditorScreenController({
    required this.novel,
    required this.vsync,
  }) {
    _init();
  }

  final NovelSummary novel;
  final TickerProvider vsync;

  // BLoC实例
  late final editor_bloc.EditorBloc editorBloc;
  late final plan_bloc.PlanBloc planBloc;

  // 服务实例
  late final ApiClient apiClient;
  late final EditorRepositoryImpl editorRepository;
  late final PromptRepository promptRepository;
  late final LocalStorageService localStorageService;
  late final SyncService syncService;

  // 控制器
  late final TabController tabController;
  final ScrollController scrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  // GlobalKey for EditorMainArea
  final GlobalKey<EditorMainAreaState> editorMainAreaKey = GlobalKey<EditorMainAreaState>();

  // 编辑器状态
  bool isPlanViewActive = false;
  bool isNextOutlineViewActive = false;
  String? currentUserId;
  String? lastActiveSceneId; // 记录最后活动的场景ID，用于判断场景是否发生变化

  // 控制器集合
  final Map<String, QuillController> sceneControllers = {};
  final Map<String, TextEditingController> sceneTitleControllers = {};
  final Map<String, TextEditingController> sceneSubtitleControllers = {};
  final Map<String, TextEditingController> sceneSummaryControllers = {};
  final Map<String, GlobalKey> sceneKeys = {};

  // 标记是否处于初始加载阶段，用于防止组件过早触发加载请求
  bool _initialLoadFlag = false;

  // 获取初始加载标志，用于外部组件(如ChapterSection)判断是否应该触发加载
  bool get isInInitialLoading => _initialLoadFlag;

  // 新增变量
  double? _currentScrollSpeed;
  // 调整预加载距离使其更合理
  static const double _preloadDistance = 600.0;

  // 滚动相关变量
  DateTime? _lastScrollHandleTime;
  DateTime? _lastScrollTime;
  double? _lastScrollPosition;
  static const Duration _scrollHandleInterval = Duration(milliseconds: 250); // 增加到250ms
  static const Duration _scrollThrottleInterval = Duration(milliseconds: 800); // 增加到800ms
  // 添加惯性滚动控制变量
  bool _isInertialScrolling = false;
  Timer? _inertialScrollTimer;
  // 添加滚动状态变量
  ScrollState _scrollState = ScrollState.idle;
  // 动态调整节流间隔
  int _currentThrottleMs = 350; // 默认节流时间

  // 防抖变量，避免频繁触发加载
  DateTime? _lastLoadTime;
  String? _lastDirection;
  String? _lastFromChapterId;
  bool _isLoadingMore = false;

  // 公共 getter，用于 UI 访问加载状态
  bool get isLoadingMore => _isLoadingMore;

  // 用于滚动事件的节流控制
  DateTime? _lastScrollProcessTime;

  // 添加摘要加载状态管理
  bool _isLoadingSummaries = false;
  DateTime? _lastSummaryLoadTime;
  static const Duration _summaryLoadThrottleInterval = Duration(seconds: 60); // 1分钟内不重复加载

  // 新增：在EditorScreenController中添加
  bool get hasReachedEnd => 
      editorBloc.state is editor_bloc.EditorLoaded && 
      (editorBloc.state as editor_bloc.EditorLoaded).hasReachedEnd;

  bool get hasReachedStart => 
      editorBloc.state is editor_bloc.EditorLoaded && 
      (editorBloc.state as editor_bloc.EditorLoaded).hasReachedStart;

  // 用于EditorBloc状态监听的字段
  int? _lastScenesCount;
  int? _lastChaptersCount;

  // 添加更多的状态变量
  bool _isFullscreenLoading = false;
  String _loadingMessage = '正在加载编辑器...';
  double _loadingProgress = 0.0;
  int _initializationStep = 0;
  final int _totalInitializationSteps = 5;

  // 提供getter供UI使用
  bool get isFullscreenLoading => _isFullscreenLoading;
  String get loadingMessage => _loadingMessage;
  double get loadingProgress => _loadingProgress;

  // 检查是否有任何加载正在进行
  bool _isAnyLoading() {
    // 检查编辑器状态
    if (editorBloc.state is editor_bloc.EditorLoaded) {
      final state = editorBloc.state as editor_bloc.EditorLoaded;
      if (state.isLoading) return true;
    }

    // 检查控制器状态
    if (_isLoadingMore) return true;

    // 检查加载冷却时间
    if (_lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!).inSeconds < 1) {
      return true;
    }

    return false;
  }

  // 初始化方法
  void _init() {
    // 启用全屏加载状态
    _isFullscreenLoading = true;
    _loadingProgress = 0.0;
    _initializationStep = 0;
    _updateLoadingProgress('正在初始化编辑器核心组件...');

    // 创建必要的实例
    apiClient = ApiClient();
    editorRepository = EditorRepositoryImpl();
    promptRepository = PromptRepositoryImpl(apiClient);
    localStorageService = LocalStorageService();

    tabController = TabController(length: 4, vsync: vsync);
    
    _updateLoadingProgress('正在启动编辑器服务...');

    // 初始化EditorBloc
    editorBloc = editor_bloc.EditorBloc(
      repository: editorRepository,
      novelId: novel.id,
    );
    
    // 监听EditorBloc状态变化，用于更新UI
    _setupEditorBlocListener();

    // 初始化PlanBloc
    planBloc = plan_bloc.PlanBloc(
      repository: editorRepository,
      novelId: novel.id,
    );

    _updateLoadingProgress('正在初始化同步服务...');
    
    // 初始化同步服务
    syncService = SyncService(
      apiService: apiClient,
      localStorageService: localStorageService,
    );

    // 初始化同步服务并设置当前小说
    syncService.init().then((_) {
      syncService.setCurrentNovelId(novel.id).then((_) {
        AppLogger.i('EditorScreenController', '已设置当前小说ID: ${novel.id}');
        _updateLoadingProgress('正在加载小说结构...');
      });
    });

    // 分开大纲和编辑区加载逻辑
    // 1. 为侧边栏和大纲加载完整小说结构（包含所有场景摘要）
    editorRepository.getNovelWithSceneSummaries(novel.id).then((novelWithSummaries) {
      if (novelWithSummaries != null) {
        AppLogger.i('EditorScreenController', '已加载带摘要的小说结构用于大纲和侧边栏');
        _updateLoadingProgress('正在加载大纲内容...');

        // 触发大纲初始化
        planBloc.add(const plan_bloc.LoadPlanContent());
      } else {
        AppLogger.w('EditorScreenController', '加载带摘要的小说结构失败');
      }
    }).catchError((error) {
      AppLogger.e('EditorScreenController', '加载带摘要的小说结构出错', error);
    });

    // 2. 主编辑区使用分页加载，仅加载必要的章节场景内容
    String? lastEditedChapterId = novel.lastEditedChapterId;
    AppLogger.i('EditorScreenController', '使用分页加载初始化编辑器，最后编辑章节ID: $lastEditedChapterId');

    _updateLoadingProgress('正在加载编辑区内容...');
    
    // 添加延迟以避免初始化同时发送大量请求
    Future.delayed(const Duration(milliseconds: 500), () {
      if (lastEditedChapterId != null && lastEditedChapterId.isNotEmpty) {
        // 如果有最后编辑的章节，从该章节开始加载
        AppLogger.i('EditorScreenController', '从最后编辑的章节加载: $lastEditedChapterId');
        editorBloc.add(editor_bloc.LoadMoreScenes(
          fromChapterId: lastEditedChapterId,
          direction: 'center', // 从中间加载，包括上下章节
          chaptersLimit: 3, // 减少初始加载的章节数量
          preventFocusChange: false, // 允许焦点变化，因为这是初始加载
        ));
      } else {
        // 如果没有最后编辑的章节，使用常规分页加载，但限制章节数量
        AppLogger.i('EditorScreenController', '没有最后编辑的章节，使用常规分页加载');
        editorBloc.add(editor_bloc.LoadEditorContentPaginated(
          novelId: novel.id,
          chaptersLimit: 3, // 减少初始加载的章节数量
          loadAllSummaries: false, // 不加载所有摘要，减少初始加载量
        ));
      }
      
      // 设置一个延迟关闭加载动画，确保至少显示一定时间
      Future.delayed(const Duration(seconds: 2), () {
        _updateLoadingProgress('编辑器加载完成，准备就绪!', isComplete: true);
        Future.delayed(const Duration(milliseconds: 500), () {
          _isFullscreenLoading = false;
          notifyListeners();
        });
      });
    });

    // 防止在初始化时ChapterSection组件触发大量加载
    _initialLoadFlag = true;
    Future.delayed(const Duration(seconds: 3), () {
      _initialLoadFlag = false;
      AppLogger.i('EditorScreenController', '初始加载限制已解除，允许正常分页加载');
    });

    // 添加滚动监听，实现滚动加载更多场景
    scrollController.addListener(_onScroll);

    currentUserId = AppConfig.userId;
    if (currentUserId == null) {
      AppLogger.e(
          'EditorScreenController', 'User ID is null. Some features might be limited.');
    }

    // 设置性能监控
    _setupPerformanceMonitoring();
  }

  // 监听EditorBloc状态变化
  void _setupEditorBlocListener() {
    editorBloc.stream.listen((state) {
      if (state is editor_bloc.EditorLoaded) {
        // 检查加载状态和章节/场景计数
        
        // 计算当前场景和章节总数
        int currentScenesCount = 0;
        int currentChaptersCount = 0;
        
        for (final act in state.novel.acts) {
          currentChaptersCount += act.chapters.length;
          for (final chapter in act.chapters) {
            currentScenesCount += chapter.scenes.length;
          }
        }
        
        // 如果章节或场景数量发生变化，通知UI更新
        if (_lastScenesCount != null && _lastScenesCount != currentScenesCount) {
          AppLogger.i('EditorScreenController', 
              '检测到章节或场景数量变化: 章节 ${_lastChaptersCount}->$currentChaptersCount, 场景 ${_lastScenesCount}->$currentScenesCount');
          
          // 通知UI刷新
          _notifyMainAreaToRefresh();
        }
        
        // 如果加载状态为false且之前记录的isLoadingMore为true，表示刚完成加载
        if (!state.isLoading && _isLoadingMore) {
          AppLogger.i('EditorScreenController', '加载完成，通知UI刷新');
          
          // 更新加载状态
          _isLoadingMore = false;
          
          // 通知UI刷新
          _notifyMainAreaToRefresh();
        }
        
        // 更新记录的数量
        _lastScenesCount = currentScenesCount;
        _lastChaptersCount = currentChaptersCount;
        
        // 记录加载状态
        _isLoadingMore = state.isLoading;
      }
    });
  }
  
  // 通知EditorMainArea刷新UI
  void _notifyMainAreaToRefresh() {
    if (editorMainAreaKey.currentState != null) {
      // 直接调用EditorMainArea的refreshUI方法
      editorMainAreaKey.currentState!.refreshUI();
      AppLogger.i('EditorScreenController', '通知EditorMainArea刷新UI');
    } else {
      AppLogger.w('EditorScreenController', '无法获取EditorMainArea实例，无法刷新UI');
      
      // 通过重建整个编辑区来强制刷新
      notifyListeners();
    }
  }

  // 添加性能监控
  void _setupPerformanceMonitoring() {
    if (!kDebugMode) return;

    // 滚动性能监控
    _scrollPerformanceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_scrollPerformanceStats.isNotEmpty) {
        final avgFrameDuration = _scrollPerformanceStats.reduce((a, b) => a + b) / _scrollPerformanceStats.length;
        AppLogger.d('EditorScreenController', '滚动性能统计: 平均帧耗时 ${avgFrameDuration.toStringAsFixed(2)}ms, 最大帧耗时 ${_maxFrameDuration.toStringAsFixed(2)}ms');
        _scrollPerformanceStats.clear();
        _maxFrameDuration = 0;
      }
    });
  }

  // 性能监控变量
  Timer? _scrollPerformanceTimer;
  final List<double> _scrollPerformanceStats = [];
  double _maxFrameDuration = 0;
  Stopwatch _scrollStopwatch = Stopwatch();

  // 滚动监听函数，用于实现无限滚动加载
  void _onScroll() {
    // 性能监控 - 滚动帧耗时统计
    if (!_scrollStopwatch.isRunning) {
      _scrollStopwatch.start();
    } else {
      final frameDuration = _scrollStopwatch.elapsedMilliseconds.toDouble();
      _scrollStopwatch.reset();
      _scrollStopwatch.start();

      // 只记录16ms以上的帧，减少数组操作
      if (frameDuration > 16) {
        _scrollPerformanceStats.add(frameDuration);
        if (frameDuration > _maxFrameDuration) {
          _maxFrameDuration = frameDuration;
        }
      }
    }

    // 取消之前的惯性滚动计时器
    _inertialScrollTimer?.cancel();

    // 1. 改进的快速滚动检测
    final scrollInfo = _calculateScrollInfo();
    final bool isRapidScrolling = scrollInfo.isRapid;
    
    // 在每次滚动事件中更新滚动状态
    if (isRapidScrolling && _scrollState != ScrollState.userScrolling) {
      _scrollState = ScrollState.userScrolling;
      AppLogger.d('EditorScreenController', '检测到用户快速滚动');
    }

    // 2. 根据滚动状态和速度动态决定是否处理此次滚动
    if (_scrollState == ScrollState.userScrolling) {
      // 设置惯性滚动检测计时器，在滚动速度减慢后自动切换状态
      _inertialScrollTimer = Timer(const Duration(milliseconds: 200), () {
        if (scrollInfo.speed < 1.0) {
          _scrollState = ScrollState.inertialScrolling;
          AppLogger.d('EditorScreenController', '切换到惯性滚动状态');
          
          // 在惯性滚动状态下，设置一个延迟来处理边界检查
          Timer(const Duration(milliseconds: 200), () {
            if (!_isAnyLoading()) {
              _checkScrollBoundaries();
            }
          });
        }
      });
      
      // 在用户快速滚动时，不执行边界检查，避免干扰
      return;
    }

    // 3. 优化的节流控制 - 根据滚动状态动态调整节流时间
    final now = DateTime.now();
    if (_lastScrollHandleTime != null) {
      // 根据当前滚动状态动态调整节流时间
      _currentThrottleMs = _scrollState == ScrollState.inertialScrolling ? 180 : 350;
      
      if (now.difference(_lastScrollHandleTime!).inMilliseconds < _currentThrottleMs) {
        return; // 节流期间不处理
      }
    }
    _lastScrollHandleTime = now;

    // 4. 加载状态检查 - 避免重复请求
    if (_isAnyLoading()) {
      return; // 如果有任何加载进行中，跳过处理
    }

    // 5. 惯性滚动结束检测
    if (_scrollState == ScrollState.inertialScrolling && scrollInfo.speed < 0.2) {
      _scrollState = ScrollState.idle;
      AppLogger.d('EditorScreenController', '滚动已停止');
      
      // 滚动停止后执行一次边界检查，确保内容加载
      _checkScrollBoundaries();
      return;
    }

    // 6. 正常滚动状态下的边界检测
    _checkScrollBoundaries();
  }

  // 改进的滚动信息计算
  _ScrollInfo _calculateScrollInfo() {
    if (!scrollController.hasClients) return _ScrollInfo(0, false);

    final now = DateTime.now();
    final currentPosition = scrollController.offset;

    // 如果是第一次滚动，初始化参数并返回默认值
    if (_lastScrollTime == null || _lastScrollPosition == null) {
      _lastScrollTime = now;
      _lastScrollPosition = currentPosition;
      return _ScrollInfo(0, false);
    }

    final elapsed = now.difference(_lastScrollTime!).inMilliseconds;
    // 防止除以零或极小值
    if (elapsed < 10) return _ScrollInfo(_currentScrollSpeed ?? 0, false);

    final distance = (currentPosition - _lastScrollPosition!).abs();
    final speed = distance / elapsed;

    // 更新记录
    _lastScrollPosition = currentPosition;
    _lastScrollTime = now;

    // 缓存滚动速度用于其他判断
    _currentScrollSpeed = speed;

    // 返回完整的滚动信息
    return _ScrollInfo(
      speed, 
      speed > 2.5 // 调整阈值，使判断更准确
    );
  }

  // 检查是否正在缓慢滚动
  bool _isScrollingSlowly() {
    return _currentScrollSpeed != null && _currentScrollSpeed! < 0.5; // 降低阈值使判断更准确
  }

  // 检查滚动边界并触发加载
  void _checkScrollBoundaries() {
    if (!scrollController.hasClients) return;

    final offset = scrollController.offset;
    final maxScroll = scrollController.position.maxScrollExtent;
    final viewportHeight = scrollController.position.viewportDimension;

    // 使用动态预加载距离，根据视口高度调整
    final dynamicPreloadDistance = viewportHeight * 0.7;

    // 检查编辑器状态
    final state = editorBloc.state;
    if (state is editor_bloc.EditorLoaded) {
      // 检查底部边界
      if (offset >= maxScroll - dynamicPreloadDistance) {
        // 如果已经到达底部边界，不再触发加载
        if (state.hasReachedEnd) {
          if (kDebugMode) {
            AppLogger.d('EditorScreenController', '已到达内容底部，不再触发加载');
          }
          return;
        }
        _loadMoreScenes('down');
      } 
      // 检查顶部边界
      else if (offset <= dynamicPreloadDistance) {
        // 如果已经标记为hasReachedStart=true，但需要检查是否真的在第一卷
        if (state.hasReachedStart) {
          // 判断当前活动章节所在卷索引
          int focusActIndex = -1;
          String? currentFocusChapterId = state.activeChapterId;
          
          if (currentFocusChapterId != null) {
            // 遍历查找焦点章节所在Act
            for (int i = 0; i < state.novel.acts.length; i++) {
              final act = state.novel.acts[i];
              for (final chapter in act.chapters) {
                if (chapter.id == currentFocusChapterId) {
                  focusActIndex = i;
                  break;
                }
              }
              if (focusActIndex >= 0) break;
            }
          }
          
          // 如果不是第一卷，强制重置hasReachedStart标志并尝试加载
          if (focusActIndex > 0) {
            AppLogger.i('EditorScreenController', '虽然标记为已到达顶部，但当前在第${focusActIndex + 1}卷，尝试加载上一卷内容');
            
            // 重置标志
            editorBloc.add(const editor_bloc.ResetActLoadingFlags());
            
            // 加载上一卷内容
            _loadPreviousActContent(state, focusActIndex);
            return;
          }
          
          // 如果确实在第一卷，则维持hasReachedStart=true
          if (kDebugMode && focusActIndex == 0) {
            AppLogger.d('EditorScreenController', '确认当前在第一卷，维持已到达顶部状态');
          }
          return;
        }
        
        // 正常触发向上加载
        _loadMoreScenes('up');
      }
    }
  }

  // 判断滚动是否已经稳定一段时间
  bool _isScrollStable(int milliseconds) {
    if (_lastScrollTime == null) return false;
    
    // 1. 检查时间条件
    final now = DateTime.now();
    final timeStable = now.difference(_lastScrollTime!).inMilliseconds >= milliseconds;
    
    // 2. 检查速度条件 - 速度接近0
    final speedStable = _currentScrollSpeed != null && _currentScrollSpeed! < 0.1;
    
    // 同时满足时间和速度条件时，认为滚动稳定
    return timeStable && speedStable;
  }

  // 加载更多场景函数
  void _loadMoreScenes(String direction) {
    final state = editorBloc.state;
    if (state is! editor_bloc.EditorLoaded) {
      AppLogger.w('EditorScreenController', '无法加载更多场景: 编辑器尚未初始化');
      return;
    }

    // 检查是否已达边界，避免重复请求
    if ((direction == 'down' && state.hasReachedEnd) || 
        (direction == 'up' && state.hasReachedStart)) {
      AppLogger.i('EditorScreenController', 
          '已到达${direction == 'down' ? '底部' : '顶部'}边界，不再发送加载请求');
      return;
    }

    // 滚动事件节流 - 避免短时间内频繁处理滚动事件
    final now = DateTime.now();
    if (_lastScrollProcessTime != null &&
        now.difference(_lastScrollProcessTime!) < _scrollThrottleInterval) {
      return; // 在节流间隔内，直接返回不处理
    }
    _lastScrollProcessTime = now;

    // 如果正在加载中，不重复触发
    if (state.isLoading || _isLoadingMore) {
      AppLogger.d('EditorScreenController', '正在加载中，跳过重复请求');
      return;
    }

    // 设置临时标志，避免重复加载
    _isLoadingMore = true;

    // 通知UI显示加载状态
    notifyListeners();

    AppLogger.i('EditorScreenController', '开始加载 $direction 方向的更多场景');

    // 重要优化：检查是否已经加载了足够的内容
    bool alreadyHasEnoughContent = false;

    // 下滑检查是否已经到底
    if (direction == 'down' && _findLastLoadedChapterId(state.novel) == _findLastChapterId(state.novel)) {
      alreadyHasEnoughContent = true;
      // 设置已到达底部标志
      editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedEnd: true));
      AppLogger.i('EditorScreenController', '已经加载到最后一章，设置hasReachedEnd=true');
    }
    // 上滑检查是否已经到顶
    else if (direction == 'up' && _findFirstLoadedChapterId(state.novel) == _findFirstChapterId(state.novel)) {
      // 获取当前焦点章节所在的Act索引
      int focusActIndex = -1;
      String? currentFocusChapterId = state.activeChapterId;
      
      if (currentFocusChapterId != null) {
        // 遍历查找焦点章节所在Act
        for (int i = 0; i < state.novel.acts.length; i++) {
          final act = state.novel.acts[i];
          for (final chapter in act.chapters) {
            if (chapter.id == currentFocusChapterId) {
              focusActIndex = i;
              break;
            }
          }
          if (focusActIndex >= 0) break;
        }
      }
      
      // 只有当焦点章节在第一个Act时才设置hasReachedStart=true
      if (focusActIndex == 0) {
        alreadyHasEnoughContent = true;
        // 设置已到达顶部标志
        editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedStart: true));
        AppLogger.i('EditorScreenController', '已经加载到第一卷的第一章，设置hasReachedStart=true');
      } else if (focusActIndex > 0) {
        // 如果不是第一卷，则继续加载
        AppLogger.i('EditorScreenController', '当前在第${focusActIndex + 1}卷，需要继续向上加载前一卷内容');
        alreadyHasEnoughContent = false;
      } else {
        // 未找到焦点章节信息，保守处理不设置边界
        AppLogger.i('EditorScreenController', '未找到焦点章节所在卷，继续尝试加载');
        alreadyHasEnoughContent = false;
      }
    }

    if (alreadyHasEnoughContent) {
      _isLoadingMore = false;
      notifyListeners(); // 更新UI状态
      return;
    }

    try {
      // 从哪个章节开始加载（向上或向下）
      String? fromChapterId;
      if (direction == 'up') {
        // 找到当前加载的第一个章节ID
        fromChapterId = _findFirstLoadedChapterId(state.novel);
      } else {
        // 找到当前加载的最后一个章节ID
        fromChapterId = _findLastLoadedChapterId(state.novel);
      }

      // 如果没有找到章节ID，则使用活动章节（如果有）
      if (fromChapterId == null) {
        if (state.activeChapterId != null) {
          fromChapterId = state.activeChapterId;
        } else {
          // 找第一个章节ID
          fromChapterId = _findFirstChapterId(state.novel);
          if (fromChapterId == null) {
            // 实在没有章节可加载，发送请求加载小说结构
            AppLogger.w('EditorScreenController', '没有章节可加载，请求加载小说结构');
            editorBloc.add(editor_bloc.LoadEditorContentPaginated(
              novelId: novel.id,
              lastEditedChapterId: novel.lastEditedChapterId
            ));
            _isLoadingMore = false;
            notifyListeners(); // 更新UI状态
            return;
          }
        }
      }

      // 防抖：避免短时间内多次触发相同的加载请求
      if (_lastLoadTime != null &&
          now.difference(_lastLoadTime!).inSeconds < 2 &&  // 降低到2秒
          _lastDirection == direction &&
          _lastFromChapterId == fromChapterId) {
        _isLoadingMore = false;
        notifyListeners(); // 更新UI状态
        AppLogger.d('EditorScreenController', '跳过重复加载请求');
        return;
      }

      _lastLoadTime = now;
      _lastDirection = direction;
      _lastFromChapterId = fromChapterId;

      AppLogger.i('EditorScreenController', '加载更多场景: 方向=$direction, 起始章节=$fromChapterId');

      // 声明订阅变量
      late StreamSubscription<editor_bloc.EditorState> loadCompleteSubscription;
      
      // 创建监听API请求结果的回调
      loadCompleteSubscription = editorBloc.stream.listen((newState) {
        if (newState is editor_bloc.EditorLoaded && !newState.isLoading) {
          // API请求完成
          loadCompleteSubscription.cancel(); // 取消监听
          
          // 检查API是否返回了内容
          bool hasLoadedNewContent = false;
          
          // 通过比较章节数量来判断是否加载了新内容
          if (state.novel.acts.length != newState.novel.acts.length) {
            hasLoadedNewContent = true;
          } else {
            int oldChaptersCount = 0;
            int newChaptersCount = 0;
            
            for (final act in state.novel.acts) {
              oldChaptersCount += act.chapters.length;
            }
            
            for (final act in newState.novel.acts) {
              newChaptersCount += act.chapters.length;
            }
            
            hasLoadedNewContent = newChaptersCount > oldChaptersCount;
          }
          
          // 如果API没有返回新内容，设置已达边界标志
          if (!hasLoadedNewContent) {
            if (direction == 'down') {
              AppLogger.i('EditorScreenController', 'API未返回新内容，设置hasReachedEnd=true');
              editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedEnd: true));
            } else if (direction == 'up') {
              // 获取当前焦点章节所在的Act索引
              int focusActIndex = -1;
              String? currentFocusChapterId = newState.activeChapterId;
              
              if (currentFocusChapterId != null) {
                // 遍历查找焦点章节所在Act
                for (int i = 0; i < newState.novel.acts.length; i++) {
                  final act = newState.novel.acts[i];
                  for (final chapter in act.chapters) {
                    if (chapter.id == currentFocusChapterId) {
                      focusActIndex = i;
                      break;
                    }
                  }
                  if (focusActIndex >= 0) break;
                }
              }
              
              // 只有当焦点章节在第一个Act时才设置hasReachedStart=true
              if (focusActIndex == 0) {
                AppLogger.i('EditorScreenController', 'API未返回新内容且当前在第一卷，设置hasReachedStart=true');
                editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedStart: true));
              } else {
                // 如果不在第一卷但API返回为空，可能需要重新调整加载策略
                AppLogger.i('EditorScreenController', 'API未返回新内容但当前在第${focusActIndex + 1}卷，尝试加载上一卷内容');
                
                // 可以在这里添加额外的加载逻辑，如确保位于上一卷的内容被加载
                if (focusActIndex > 0) {
                  _loadPreviousActContent(newState, focusActIndex);
                }
              }
            }
          }
          
          // 重置加载状态
          _isLoadingMore = false;
          notifyListeners();
        }
      });

      // 触发加载更多事件
      editorBloc.add(editor_bloc.LoadMoreScenes(
        fromChapterId: fromChapterId!,
        direction: direction,
        chaptersLimit: 3,
        preventFocusChange: true,  // 防止焦点变化，避免不必要的滚动
        skipIfLoading: true,  // 如果已经在加载，跳过这次请求
      ));

      // 延时0.5秒后再通知UI刷新，确保能看到加载指示器
      Future.delayed(const Duration(milliseconds: 500), () {
        notifyListeners();
      });
      
      // 设置超时处理，避免监听器永久等待
      Future.delayed(const Duration(seconds: 10), () {
        loadCompleteSubscription.cancel();
        if (_isLoadingMore) {
          _isLoadingMore = false;
          notifyListeners();
          AppLogger.w('EditorScreenController', '加载请求超时，重置加载状态');
        }
      });
    } catch (e) {
      AppLogger.e('EditorScreenController', '加载更多场景出错', e);
      _isLoadingMore = false;
      notifyListeners(); // 更新UI状态
    }
  }
  
  // 新增方法：尝试加载上一卷的内容
  void _loadPreviousActContent(editor_bloc.EditorLoaded state, int currentActIndex) {
    // 确保当前Act索引有效且不是第一个Act
    if (currentActIndex <= 0 || currentActIndex >= state.novel.acts.length) {
      return;
    }
    
    // 获取上一个Act
    final previousAct = state.novel.acts[currentActIndex - 1];
    
    // 如果上一个Act没有章节，不需要加载
    if (previousAct.chapters.isEmpty) {
      return;
    }
    
    // 从上一个Act的最后一个章节开始加载
    final lastChapterInPreviousAct = previousAct.chapters.last;
    
    AppLogger.i('EditorScreenController', '尝试从上一卷的最后一章开始加载: ${lastChapterInPreviousAct.title}');
    
    // 发送加载请求
    editorBloc.add(editor_bloc.LoadMoreScenes(
      fromChapterId: lastChapterInPreviousAct.id,
      direction: 'center', // 使用center方向确保可以加载章节前后的内容
      chaptersLimit: 5,    // 加载多个章节
      preventFocusChange: true,
    ));
  }

  // 辅助函数：找到小说结构中的第一个章节ID，无论是否有场景
  String? _findFirstChapterId(novel_models.Novel novel) {
    if (novel.acts.isEmpty || novel.acts.first.chapters.isEmpty) return null;
    return novel.acts.first.chapters.first.id;
  }

  // 辅助函数：找到小说结构中的最后一个章节ID，无论是否有场景
  String? _findLastChapterId(novel_models.Novel novel) {
    if (novel.acts.isEmpty) return null;
    final lastAct = novel.acts.last;
    if (lastAct.chapters.isEmpty) return null;
    return lastAct.chapters.last.id;
  }

  // 辅助函数：找到当前加载的第一个有场景的章节ID
  String? _findFirstLoadedChapterId(novel_models.Novel novel) {
    if (novel.acts.isEmpty) return null;

    // 记录空章节信息，帮助调试
    _logEmptyChaptersInfo(novel);

    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        // 只有章节包含场景时才考虑它
        if (chapter.scenes.isNotEmpty) {
          return chapter.id;
        }
      }
    }
    return null;
  }

  // 辅助函数：找到当前加载的最后一个有场景的章节ID
  String? _findLastLoadedChapterId(novel_models.Novel novel) {
    if (novel.acts.isEmpty) return null;

    // 从最后一个Act开始反向遍历
    for (int i = novel.acts.length - 1; i >= 0; i--) {
      final act = novel.acts[i];
      // 从最后一个Chapter开始反向遍历
      for (int j = act.chapters.length - 1; j >= 0; j--) {
        final chapter = act.chapters[j];
        // 只有章节包含场景时才考虑它
        if (chapter.scenes.isNotEmpty) {
          return chapter.id;
        }
      }
    }
    return null;
  }

  // 辅助函数：记录空章节信息
  void _logEmptyChaptersInfo(novel_models.Novel novel) {
    int totalChapters = 0;
    int emptyChapters = 0;

    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        totalChapters++;
        if (chapter.scenes.isEmpty) {
          emptyChapters++;
        }
      }
    }

    // 只在有空章节时记录日志
    if (emptyChapters > 0) {
      AppLogger.i('EditorScreenController',
          '当前共有 $totalChapters 个章节，其中 $emptyChapters 个章节没有场景（未加载或空章节）');
    }
  }

  // 为指定章节手动加载场景内容
  void loadScenesForChapter(String chapterId) {
    editorBloc.add(editor_bloc.LoadMoreScenes(
      fromChapterId: chapterId,
      direction: 'center',
      chaptersLimit: 2, // 增加加载章节数量
    ));
  }

  // 为章节目录加载所有场景内容（不分页）
  void loadAllScenesForChapter(String chapterId, {bool disableAutoScroll = true}) {
    AppLogger.i('EditorScreenController', '加载章节的所有场景内容: $chapterId, 禁用自动滚动: $disableAutoScroll');

    // 始终禁用自动跳转，通过不传递targetScene相关参数实现
    editorBloc.add(editor_bloc.LoadMoreScenes(
      fromChapterId: chapterId,
      direction: 'center',
      chaptersLimit: 10, // 设置较大的限制，尝试加载更多场景
    ));
  }

  // 预加载章节场景但不改变焦点
  void preloadChapterScenes(String chapterId) {
    AppLogger.i('EditorScreenController', '预加载章节场景: $chapterId');

    // 检查当前状态，如果场景已经加载，则不需要再次加载
    final state = editorBloc.state;
    if (state is editor_bloc.EditorLoaded) {
      // 检查目标章节是否已经存在场景
      bool hasScenes = false;
      String? targetActId;

      // 先在已加载的Acts中查找章节
      for (final act in state.novel.acts) {
        for (final chapter in act.chapters) {
          if (chapter.id == chapterId) {
            targetActId = act.id;
            hasScenes = chapter.scenes.isNotEmpty;
            break;
          }
        }
        if (targetActId != null) break;
      }

      // 如果未找到章节所属的Act，则在API中查找或创建一个默认Act
      if (targetActId == null) {
        // 使用第一个Act作为目标Act，如果没有Act则创建一个
        if (state.novel.acts.isNotEmpty) {
          targetActId = state.novel.acts.first.id;
          AppLogger.i('EditorScreenController', '找不到章节 $chapterId 所属的Act，使用第一个Act: $targetActId');
        } else {
          // 如果没有任何Act，可能需要先加载小说结构
          AppLogger.w('EditorScreenController', '找不到章节 $chapterId 所属的Act，且小说中没有Act，无法预加载场景');
          return;
        }
      }

      // 如果章节已经有场景，就不需要再次加载
      if (hasScenes) {
        AppLogger.i('EditorScreenController', '章节 $chapterId 已有场景，不需要重新加载');
        return;
      }

      // 使用参数preventFocusChange=true确保不会改变焦点
      editorBloc.add(editor_bloc.LoadMoreScenes(
        fromChapterId: chapterId,
        direction: 'center',
        chaptersLimit: 10,
        preventFocusChange: true, // 设置为true避免改变焦点
        loadFromLocalOnly: true  // 新增参数，仅从本地加载，避免不必要的网络请求
      ));
    } else {
      AppLogger.w('EditorScreenController', '编辑器尚未加载，无法预加载章节场景');
    }
  }

  // 切换Plan视图
  void togglePlanView() {
    AppLogger.i('EditorScreenController', '切换Plan视图，当前状态: $isPlanViewActive');
    final currentState = editorBloc.state;
    final isPlanToWrite = isPlanViewActive; // 如果当前是Plan视图，则将切换到Write视图

    // 切换状态
    isPlanViewActive = !isPlanViewActive;

    // 如果激活Plan视图，关闭剧情推演视图
    if (isPlanViewActive) {
      isNextOutlineViewActive = false;
    }

    // 记录日志
    AppLogger.i('EditorScreenController', '切换后的Plan视图状态: $isPlanViewActive');

    // 如果激活Plan视图，加载Plan数据
    if (isPlanViewActive) {
      AppLogger.i('EditorScreenController', '加载Plan数据');
      planBloc.add(const plan_bloc.LoadPlanContent());
    }
    // 如果从plan视图切换到Write视图，确保编辑器内容正常显示
    else if (isPlanToWrite && currentState is editor_bloc.EditorLoaded) {
      AppLogger.i('EditorScreenController', 'Switched from Plan to Write view. Scroll handled by BlocListener.');
    }

    notifyListeners();
  }

  // 切换剧情推演视图
  void toggleNextOutlineView() {
    AppLogger.i('EditorScreenController', '切换剧情推演视图，当前状态: $isNextOutlineViewActive');

    // 切换状态
    isNextOutlineViewActive = !isNextOutlineViewActive;

    // 如果激活剧情推演视图，关闭Plan视图
    if (isNextOutlineViewActive) {
      isPlanViewActive = false;
    }

    // 记录日志
    AppLogger.i('EditorScreenController', '切换后的剧情推演视图状态: $isNextOutlineViewActive');

    notifyListeners();
  }

  // 获取同步服务并同步当前小说
  Future<void> syncCurrentNovel() async {
    try {
      final editorRepository = EditorRepositoryImpl();
      final localStorageService = editorRepository.getLocalStorageService();

      // 检查是否有要同步的内容
      final novelId = novel.id;
      final novelSyncList = await localStorageService.getSyncList('novel');
      final sceneSyncList = await localStorageService.getSyncList('scene');
      final editorSyncList = await localStorageService.getSyncList('editor');

      final hasNovelToSync = novelSyncList.contains(novelId);
      final hasScenesToSync = sceneSyncList.any((sceneKey) => sceneKey.startsWith(novelId));
      final hasEditorToSync = editorSyncList.any((editorKey) => editorKey.startsWith(novelId));

      if (hasNovelToSync || hasScenesToSync || hasEditorToSync) {
        AppLogger.i('EditorScreenController', '检测到待同步内容，执行退出前同步: ${novel.id}');

        // 使用已初始化的同步服务执行同步
        await syncService.syncAll();

        AppLogger.i('EditorScreenController', '退出前同步完成: ${novel.id}');
      } else {
        AppLogger.i('EditorScreenController', '没有待同步内容，跳过退出前同步: ${novel.id}');
      }
    } catch (e) {
      AppLogger.e('EditorScreenController', '退出前同步失败', e);
    }
  }

  // 清理所有控制器
  void clearAllControllers() {
    AppLogger.i('EditorScreenController', '清理所有控制器');
    for (final controller in sceneControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        AppLogger.e('EditorScreenController', '关闭场景控制器失败', e);
      }
    }
    sceneControllers.clear();

    for (final controller in sceneTitleControllers.values) {
      controller.dispose();
    }
    sceneTitleControllers.clear();
    for (final controller in sceneSubtitleControllers.values) {
      controller.dispose();
    }
    sceneSubtitleControllers.clear();
    for (final controller in sceneSummaryControllers.values) {
      controller.dispose();
    }
    sceneSummaryControllers.clear();
    // Clear GlobalKeys map
    sceneKeys.clear();
  }

  // 获取可见场景ID列表
  List<String> _getVisibleSceneIds() {
    if (editorBloc.state is! editor_bloc.EditorLoaded) return [];

    final state = editorBloc.state as editor_bloc.EditorLoaded;
    final visibleSceneIds = <String>[];

    // 提取所有场景ID
    for (final act in state.novel.acts) {
      for (final chapter in act.chapters) {
        for (final scene in chapter.scenes) {
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';

          // 检查该场景是否可见
          final key = sceneKeys[sceneId];
          if (key?.currentContext != null) {
            final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final scenePosition = renderBox.localToGlobal(Offset.zero);
              final sceneHeight = renderBox.size.height;

              // 计算场景的顶部和底部位置
              final sceneTop = scenePosition.dy;
              final sceneBottom = sceneTop + sceneHeight;

              // 获取屏幕高度
              final screenHeight = MediaQuery.of(key.currentContext!).size.height;

              // 扩展可见区域，预加载前后的场景
              final extendedVisibleTop = -screenHeight;
              final extendedVisibleBottom = screenHeight * 2;

              // 判断场景是否在可见区域内
              if (sceneBottom >= extendedVisibleTop && sceneTop <= extendedVisibleBottom) {
                visibleSceneIds.add(sceneId);
              }
            }
          }
        }
      }
    }

    // 如果没有可见场景（可能还在初始加载），添加活动场景
    if (visibleSceneIds.isEmpty && state.activeActId != null &&
        state.activeChapterId != null && state.activeSceneId != null) {
      visibleSceneIds.add('${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}');
    }

    return visibleSceneIds;
  }

  // 新增：使用更长间隔的节流函数检查可见场景
  void _checkVisibleScenesThrottled() {
    _visibleScenesDebounceTimer?.cancel();
    // 延长防抖时间到1000ms，减少处理频率
    _visibleScenesDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _checkVisibleScenes(logEnabled: false); // 禁用日志
    });
  }

  // 检查可见场景并优化控制器，增加日志控制参数
  void _checkVisibleScenes({bool logEnabled = true}) {
    final visibleSceneIds = _getVisibleSceneIds();

    // 检查是否需要清理不可见场景的控制器
    _cleanupUnusedControllers(visibleSceneIds);

    // 只有在明确启用日志且可见场景少于3个时才记录日志
    if (logEnabled && visibleSceneIds.length < 3 && kDebugMode) {
      AppLogger.d('EditorScreenController', '当前可见场景: ${visibleSceneIds.length}个');
    }
  }

  // 清理不再需要的控制器
  void _cleanupUnusedControllers(List<String> visibleSceneIds) {
    // 如果场景控制器数量低于阈值，不执行清理
    if (sceneControllers.length < 30) return; // 提高阈值到30，减少清理频率

    final controllersToRemove = <String>[];

    // 保留所有可见控制器
    final keysToKeep = <String>{...visibleSceneIds};

    // 添加活动场景控制器(如果有)
    if (editorBloc.state is editor_bloc.EditorLoaded) {
      final state = editorBloc.state as editor_bloc.EditorLoaded;
      if (state.activeActId != null && state.activeChapterId != null && state.activeSceneId != null) {
        keysToKeep.add('${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}');
      }
    }

    // 在保持可见控制器的基础上，如果总数过多，移除最旧的
    if (sceneControllers.length > 60) { // 维持最多60个控制器，提高阈值
      final keysToConsider = sceneControllers.keys.toList()
        ..removeWhere((key) => keysToKeep.contains(key));

      // 只保留25个最近使用的，增加保留数量
      if (keysToConsider.length > 35) { // 如果超过35个不可见控制器
        final keysToRemove = keysToConsider.sublist(0, keysToConsider.length - 25);
        controllersToRemove.addAll(keysToRemove);
      }
    }

    // 安全释放资源
    for (final id in controllersToRemove) {
      try {
        sceneControllers[id]?.dispose();
        sceneControllers.remove(id);
        sceneSummaryControllers.remove(id);
      } catch (e) {
        // 禁用日志以提高性能
        if (kDebugMode) {
          AppLogger.e('EditorScreenController', '释放控制器资源失败: $id', e);
        }
      }
    }

    // 只有在清理了大量控制器时才记录日志
    if (controllersToRemove.length > 10 && kDebugMode) {
      AppLogger.i('EditorScreenController', '已清理 ${controllersToRemove.length} 个不可见场景控制器，当前控制器数: ${sceneControllers.length}');
    }
  }

  // 确保控制器的优化版本
  void ensureControllersForNovel(novel_models.Novel novel) {
    // 获取并处理当前可见场景
    final visibleSceneIds = _getVisibleSceneIds();

    // 仅为可见场景创建控制器
    bool controllersCreated = false;

    // 遍历当前加载的小说数据
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        for (final scene in chapter.scenes) {
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';

          // 如果是可见场景，且控制器不存在，则创建
          if (visibleSceneIds.contains(sceneId) && !sceneControllers.containsKey(sceneId)) {
            _createControllerForScene(act.id, chapter.id, scene);
            controllersCreated = true;
          }
        }
      }
    }

    // 只在创建了新控制器时输出日志
    if (controllersCreated) {
      AppLogger.d('EditorScreenController', '已为可见场景创建控制器，当前控制器数: ${sceneControllers.length}');
    }
  }

  // 为单个场景创建控制器
  void _createControllerForScene(String actId, String chapterId, novel_models.Scene scene) {
    final sceneId = '${actId}_${chapterId}_${scene.id}';

    try {
      // 创建QuillController
      final controller = QuillController(
        document: _parseDocumentSafely(scene.content),
        selection: const TextSelection.collapsed(offset: 0),
      );

      // 创建摘要控制器
      final summaryController = TextEditingController(
        text: scene.summary.content,
      );

      // 存储控制器
      sceneControllers[sceneId] = controller;
      sceneSummaryControllers[sceneId] = summaryController;

      // 创建GlobalKey
      if (!sceneKeys.containsKey(sceneId)) {
        sceneKeys[sceneId] = GlobalKey();
      }
    } catch (e) {
      AppLogger.e('EditorScreenController', '为场景创建控制器失败: $sceneId', e);

      // 创建默认控制器
      sceneControllers[sceneId] = QuillController(
        document: Document.fromJson([{'insert': '\n'}]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      sceneSummaryControllers[sceneId] = TextEditingController(text: '');
    }
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
          AppLogger.e('EditorScreenController', '解析场景内容失败: 不是有效的Quill文档格式 ${decodedContent.runtimeType}');
          return Document.fromJson([{'insert': '\n'}]);
        }
      } else {
        // 不支持的内容格式
        AppLogger.e('EditorScreenController', '解析场景内容失败: 不支持的内容格式 ${decodedContent.runtimeType}');
        return Document.fromJson([{'insert': '\n'}]);
      }
    } catch (e) {
      AppLogger.e('EditorScreenController', '解析场景内容失败', e);
      // 不再返回"内容加载失败"而是返回空文档，避免显示错误信息
      return Document.fromJson([{'insert': '\n'}]);
    }
  }

  // 场景控制器防抖定时器
  Timer? _visibleScenesDebounceTimer;

  // 通知小说列表刷新
  void notifyNovelListRefresh(BuildContext context) {
    try {
      // 尝试获取NovelListBloc并触发刷新
      try {
        context.read<NovelListBloc>().add(LoadNovels());
        AppLogger.i('EditorScreenController', '已触发小说列表刷新');
      } catch (e) {
        AppLogger.w('EditorScreenController', '小说列表Bloc不可用，无法触发刷新');
      }
    } catch (e) {
      AppLogger.e('EditorScreenController', '尝试刷新小说列表时出错', e);
    }
  }

  // 释放资源
  @override
  void dispose() {
    // 停止性能监控
    _scrollPerformanceTimer?.cancel();
    _scrollStopwatch.stop();

    // 清理滚动相关资源
    _visibleScenesDebounceTimer?.cancel();

    // 释放所有控制器
    for (final controller in sceneControllers.values) {
      controller.dispose();
    }
    sceneControllers.clear();

    // 释放其他控制器
    for (final controller in sceneSummaryControllers.values) {
      controller.dispose();
    }
    sceneSummaryControllers.clear();

    // 移除滚动监听
    scrollController.removeListener(_onScroll);
    scrollController.dispose();

    // 释放TabController
    tabController.dispose();

    // 释放FocusNode
    focusNode.dispose();

    // 尝试同步当前小说数据
    syncCurrentNovel();

    // 清理控制器资源
    clearAllControllers();

    // 关闭同步服务
    syncService.dispose();

    // 清理BLoC
    editorBloc.close();

    super.dispose();
  }

  /// 加载所有场景摘要
  void loadAllSceneSummaries() {
    // 防止重复加载，添加节流控制
    final now = DateTime.now();
    if (_isLoadingSummaries) {
      AppLogger.i('EditorScreenController', '正在加载摘要，跳过重复请求');
      return;
    }
    
    if (_lastSummaryLoadTime != null && 
        now.difference(_lastSummaryLoadTime!) < _summaryLoadThrottleInterval) {
      AppLogger.i('EditorScreenController', 
          '摘要加载过于频繁，上次加载时间: ${_lastSummaryLoadTime!.toString()}, 跳过此次请求');
      return;
    }
    
    _isLoadingSummaries = true;
    _lastSummaryLoadTime = now;
    
    AppLogger.i('EditorScreenController', '开始加载所有场景摘要');
    
    // 使用带有场景摘要的API直接加载完整小说数据
    editorRepository.getNovelWithSceneSummaries(novel.id).then((novelWithSummaries) {
      if (novelWithSummaries != null) {
        AppLogger.i('EditorScreenController', '已加载所有场景摘要');

        // 更新编辑器状态
        editorBloc.add(editor_bloc.LoadEditorContentPaginated(
          novelId: novel.id,
          lastEditedChapterId: novel.lastEditedChapterId,
          chaptersLimit: 10,
          loadAllSummaries: true,  // 指示加载所有摘要
        ));
      } else {
        AppLogger.w('EditorScreenController', '加载所有场景摘要失败');
      }
    }).catchError((error) {
      AppLogger.e('EditorScreenController', '加载所有场景摘要出错', error);
    }).whenComplete(() {
      // 无论成功失败，完成后更新状态
      _isLoadingSummaries = false;
    });
  }

  // 在EditorScreenController中添加新方法用于初始化结构边界
  void _initializeNovelStructureBoundaries() {
    final novelModel = editorBloc.state is editor_bloc.EditorLoaded 
        ? (editorBloc.state as editor_bloc.EditorLoaded).novel 
        : null;
    
    if (novelModel == null || novelModel.acts.isEmpty) return;
    
    AppLogger.i('EditorScreenController', '开始初始化小说结构边界，共${novelModel.acts.length}卷');
    
    // 处理起始边界
    final firstAct = novelModel.acts.first;
    if (firstAct.chapters.isEmpty) {
      // 第一个卷是空的，直接标记已到达开始
      editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedStart: true));
      AppLogger.i('EditorScreenController', '小说第一卷为空，标记已到达开始边界');
    } else {
      // 加载第一个卷的第一个章节，确保起始章节被加载
      final firstChapter = firstAct.chapters.first;
      AppLogger.i('EditorScreenController', '加载起始卷第一个章节: ${firstChapter.id} (${firstChapter.title})');
      editorBloc.add(editor_bloc.LoadMoreScenes(
        fromChapterId: firstChapter.id,
        direction: 'center',
        chaptersLimit: 5, // 加载更多章节以减少后续分页
        preventFocusChange: true,
      ));
    }
    
    // 处理结束边界
    final lastAct = novelModel.acts.last;
    if (lastAct.chapters.isEmpty) {
      // 最后一个卷是空的，直接标记已到达末尾
      editorBloc.add(const editor_bloc.SetActLoadingFlags(hasReachedEnd: true));
      AppLogger.i('EditorScreenController', '小说最后一卷为空，标记已到达结束边界');
    } else {
      // 加载最后一个卷的最后一个章节，确保结尾章节被加载
      final lastChapter = lastAct.chapters.last;
      AppLogger.i('EditorScreenController', '加载末尾卷最后一个章节: ${lastChapter.id} (${lastChapter.title})');
      editorBloc.add(editor_bloc.LoadMoreScenes(
        fromChapterId: lastChapter.id,
        direction: 'center',
        chaptersLimit: 5, // 加载更多章节以减少后续分页
        preventFocusChange: true,
      ));
    }
    
    // 预加载空卷和边界卷
    _preloadEmptyActs();
  }

  // 预加载所有空卷的章节和边界卷
  void _preloadEmptyActs() {
    final novelModel = editorBloc.state is editor_bloc.EditorLoaded 
        ? (editorBloc.state as editor_bloc.EditorLoaded).novel 
        : null;
    
    if (novelModel == null) return;
    
    // 用于记录已预加载的章节ID，避免重复加载
    final Set<String> preloadedChapterIds = {};
    
    // 1. 处理所有空卷
    for (int i = 0; i < novelModel.acts.length; i++) {
      final act = novelModel.acts[i];
      
      // 处理完全空的卷
      if (act.chapters.isEmpty) {
        AppLogger.i('EditorScreenController', '检测到空卷: ${act.title}，无需预加载');
        continue;
      }
      
      // 检查卷中是否所有章节都没有场景
      final bool allChaptersEmpty = act.chapters.every((chapter) => chapter.scenes.isEmpty);
      
      if (allChaptersEmpty) {
        // 所有章节都是空的，预加载整个卷
        AppLogger.i('EditorScreenController', '预加载整个空章节卷: ${act.title}，共${act.chapters.length}章');
        
        // 从第一个章节开始加载
        if (act.chapters.isNotEmpty) {
          final startChapterId = act.chapters.first.id;
          editorBloc.add(editor_bloc.LoadMoreScenes(
            fromChapterId: startChapterId,
            direction: 'center',
            chaptersLimit: act.chapters.length > 10 ? 10 : act.chapters.length, // 限制一次最多加载10章
            preventFocusChange: true,
          ));
          
          // 记录已加载的章节
          preloadedChapterIds.add(startChapterId);
          
          // 如果章节超过10个，按批次加载
          if (act.chapters.length > 10) {
            // 从中间位置加载一批
            if (act.chapters.length > 20) {
              final midIndex = act.chapters.length ~/ 2;
              final midChapterId = act.chapters[midIndex].id;
              
              editorBloc.add(editor_bloc.LoadMoreScenes(
                fromChapterId: midChapterId,
                direction: 'center',
                chaptersLimit: 10,
                preventFocusChange: true,
              ));
              
              preloadedChapterIds.add(midChapterId);
            }
            
            // 从末尾加载一批
            final lastChapterId = act.chapters.last.id;
            editorBloc.add(editor_bloc.LoadMoreScenes(
              fromChapterId: lastChapterId,
              direction: 'center',
              chaptersLimit: 10,
              preventFocusChange: true,
            ));
            
            preloadedChapterIds.add(lastChapterId);
          }
        }
      }
    }
    
    // 2. 处理起始和结束卷之间有场景但不完整的卷
    // 如果小说只有1-2卷，则直接全部加载
    if (novelModel.acts.length <= 2) {
      AppLogger.i('EditorScreenController', '小说卷数少于等于2，尝试直接加载所有章节');
      
      for (final act in novelModel.acts) {
        if (act.chapters.isEmpty) continue;
        
        for (final chapter in act.chapters) {
          // 检查是否已经加载过
          if (preloadedChapterIds.contains(chapter.id)) continue;
          
          // 检查章节是否有场景
          if (chapter.scenes.isEmpty) {
            AppLogger.i('EditorScreenController', '预加载空章节: ${chapter.title} (${chapter.id})');
            editorBloc.add(editor_bloc.LoadMoreScenes(
              fromChapterId: chapter.id,
              direction: 'center',
              chaptersLimit: 2,
              preventFocusChange: true,
            ));
            
            preloadedChapterIds.add(chapter.id);
          }
        }
      }
    } else {
      // 如果卷数较多，只处理首尾卷的前几个和后几个章节
      // 处理第一卷的前几个章节
      final firstAct = novelModel.acts.first;
      if (firstAct.chapters.isNotEmpty) {
        // 最多加载前5个章节
        final chaptersToLoad = firstAct.chapters.length <= 5 ? firstAct.chapters : firstAct.chapters.sublist(0, 5);
        
        for (final chapter in chaptersToLoad) {
          if (preloadedChapterIds.contains(chapter.id) || chapter.scenes.isNotEmpty) continue;
          
          AppLogger.i('EditorScreenController', '预加载首卷章节: ${chapter.title} (${chapter.id})');
          editorBloc.add(editor_bloc.LoadMoreScenes(
            fromChapterId: chapter.id,
            direction: 'center',
            chaptersLimit: 2,
            preventFocusChange: true,
          ));
          
          preloadedChapterIds.add(chapter.id);
        }
      }
      
      // 处理最后一卷的最后几个章节
      final lastAct = novelModel.acts.last;
      if (lastAct.chapters.isNotEmpty) {
        // 最多加载后5个章节
        final startIndex = lastAct.chapters.length <= 5 ? 0 : lastAct.chapters.length - 5;
        final chaptersToLoad = lastAct.chapters.sublist(startIndex);
        
        for (final chapter in chaptersToLoad) {
          if (preloadedChapterIds.contains(chapter.id) || chapter.scenes.isNotEmpty) continue;
          
          AppLogger.i('EditorScreenController', '预加载末卷章节: ${chapter.title} (${chapter.id})');
          editorBloc.add(editor_bloc.LoadMoreScenes(
            fromChapterId: chapter.id,
            direction: 'center',
            chaptersLimit: 2,
            preventFocusChange: true,
          ));
          
          preloadedChapterIds.add(chapter.id);
        }
      }
    }
    
    // 标记结构边界已初始化完成
    AppLogger.i('EditorScreenController', '小说结构边界初始化完成，已预加载${preloadedChapterIds.length}个章节');
  }

  // 更新加载进度和消息
  void _updateLoadingProgress(String message, {bool isComplete = false}) {
    _loadingMessage = message;
    
    if (isComplete) {
      _loadingProgress = 1.0;
    } else {
      _initializationStep++;
      _loadingProgress = _initializationStep / _totalInitializationSteps;
    }
    
    AppLogger.i('EditorScreenController', 
        '加载进度更新: ${(_loadingProgress * 100).toInt()}%, 消息: $_loadingMessage');
    
    // 通知UI更新加载状态
    notifyListeners();
  }
  
  // 显示全屏加载动画
  void showFullscreenLoading(String message) {
    _loadingMessage = message;
    _isFullscreenLoading = true;
    notifyListeners();
  }
  
  // 隐藏全屏加载动画
  void hideFullscreenLoading() {
    _isFullscreenLoading = false;
    notifyListeners();
  }
  
  /// 创建新卷，并自动创建一个章节和一个场景
  /// 完成后会将焦点设置到新创建的章节和场景
  Future<void> createNewAct() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final defaultActTitle = '新卷 $timestamp';

    showFullscreenLoading('正在创建新卷...');
    AppLogger.i('EditorScreenController', '开始创建新卷: $defaultActTitle');

    try {
        // Step 1: Create New Act
        final String newActId = await _internalCreateNewAct(defaultActTitle);
        AppLogger.i('EditorScreenController', '新卷创建成功，ID: $newActId');

        _loadingMessage = '正在创建新章节...';
        notifyListeners();

        // Step 2: Create New Chapter
        final String newChapterId = await _internalCreateNewChapter(newActId, '新章节 $timestamp');
        AppLogger.i('EditorScreenController', '新章节创建成功，ID: $newChapterId');

        _loadingMessage = '正在创建新场景...';
        notifyListeners();

        // Step 3: Create New Scene
        final String newSceneId = await _internalCreateNewScene(newActId, newChapterId, 'scene_$timestamp');
        AppLogger.i('EditorScreenController', '新场景创建成功，ID: $newSceneId');

        _loadingMessage = '正在设置编辑焦点...';
        notifyListeners();

        // Step 4: Set Focus
        editorBloc.add(editor_bloc.SetActiveChapter(
            actId: newActId,
            chapterId: newChapterId,
        ));
        editorBloc.add(editor_bloc.SetActiveScene(
            actId: newActId,
            chapterId: newChapterId,
            sceneId: newSceneId,
        ));
        editorBloc.add(editor_bloc.SetFocusChapter(
            chapterId: newChapterId,
        ));

        _notifyMainAreaToRefresh();
        hideFullscreenLoading();
        AppLogger.i('EditorScreenController', '新卷创建流程完成: actId=$newActId, chapterId=$newChapterId, sceneId=$newSceneId');

    } catch (e) {
        AppLogger.e('EditorScreenController', '创建新卷流程失败', e);
        hideFullscreenLoading();
        // Optionally, show an error message to the user
    }
  }

  // Helper method to create Act and wait for completion
  Future<String> _internalCreateNewAct(String title) async {
    final completer = Completer<String>();
    StreamSubscription<editor_bloc.EditorState>? subscription;

    final initialState = editorBloc.state;
    int initialActCount = 0;
    List<String> initialActIds = [];
    if (initialState is editor_bloc.EditorLoaded) {
        initialActCount = initialState.novel.acts.length;
        initialActIds = initialState.novel.acts.map((act) => act.id).toList();
    }

    subscription = editorBloc.stream.listen((state) {
        if (state is editor_bloc.EditorLoaded && !state.isLoading) {
            if (state.novel.acts.length > initialActCount) {
                final newAct = state.novel.acts.firstWhereOrNull(
                    (act) => !initialActIds.contains(act.id)
                );
                if (newAct != null) {
                  subscription?.cancel();
                  if (!completer.isCompleted) {
                      completer.complete(newAct.id);
                  }
                } else if (state.novel.acts.isNotEmpty && state.novel.acts.length > initialActCount) {
                    // Fallback: if specific new act not found but count increased, assume last one
                    final potentialNewAct = state.novel.acts.last;
                    // Basic check to avoid completing with an old act if list got reordered somehow
                    if (!initialActIds.contains(potentialNewAct.id)) {
                        subscription?.cancel();
                        if (!completer.isCompleted) {
                            completer.complete(potentialNewAct.id);
                        }
                    }
                }
            }
        }
    });

    editorBloc.add(editor_bloc.AddNewAct(title: title));

    try {
        return await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
            subscription?.cancel();
            throw Exception('创建新卷超时');
        });
    } catch (e) {
        subscription?.cancel();
        rethrow;
    }
}

// Helper method to create Chapter and wait for completion
Future<String> _internalCreateNewChapter(String actId, String title) async {
    final completer = Completer<String>();
    StreamSubscription<editor_bloc.EditorState>? subscription;

    final initialChapterState = editorBloc.state;
    int initialChapterCountInAct = 0;
    List<String> initialChapterIdsInAct = [];
    if (initialChapterState is editor_bloc.EditorLoaded) {
        final act = initialChapterState.novel.acts.firstWhereOrNull((a) => a.id == actId);
        if (act != null) {
            initialChapterCountInAct = act.chapters.length;
            initialChapterIdsInAct = act.chapters.map((ch) => ch.id).toList();
        }
    }
    
    subscription = editorBloc.stream.listen((state) {
        if (state is editor_bloc.EditorLoaded && !state.isLoading) {
            final currentAct = state.novel.acts.firstWhereOrNull((a) => a.id == actId);
            if (currentAct != null && currentAct.chapters.length > initialChapterCountInAct) {
                 final newChapter = currentAct.chapters.firstWhereOrNull(
                    (ch) => !initialChapterIdsInAct.contains(ch.id)
                );
                if (newChapter != null) {
                    subscription?.cancel();
                    if (!completer.isCompleted) {
                        completer.complete(newChapter.id);
                    }
                } else if (currentAct.chapters.isNotEmpty && currentAct.chapters.length > initialChapterCountInAct) {
                    final potentialNewChapter = currentAct.chapters.last;
                    if (!initialChapterIdsInAct.contains(potentialNewChapter.id)){
                        subscription?.cancel();
                        if (!completer.isCompleted) {
                            completer.complete(potentialNewChapter.id);
                        }
                    }
                }
            }
        }
    });

    editorBloc.add(editor_bloc.AddNewChapter(
        novelId: editorBloc.novelId,
        actId: actId,
        title: title,
    ));

    try {
        return await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
            subscription?.cancel();
            throw Exception('创建新章节超时');
        });
    } catch (e) {
        subscription?.cancel();
        rethrow;
    }
}


// Helper method to create Scene and wait for completion
Future<String> _internalCreateNewScene(String actId, String chapterId, String sceneIdProposal) async {
    final completer = Completer<String>();
    StreamSubscription<editor_bloc.EditorState>? subscription;

    final initialSceneState = editorBloc.state;
    int initialSceneCountInChapter = 0;
    List<String> initialSceneIdsInChapter = [];

    if (initialSceneState is editor_bloc.EditorLoaded) {
        final act = initialSceneState.novel.acts.firstWhereOrNull((a) => a.id == actId);
        if (act != null) {
            final chapter = act.chapters.firstWhereOrNull((c) => c.id == chapterId);
            if (chapter != null) {
                initialSceneCountInChapter = chapter.scenes.length;
                initialSceneIdsInChapter = chapter.scenes.map((sc) => sc.id).toList();
            }
        }
    }

    subscription = editorBloc.stream.listen((state) {
        if (state is editor_bloc.EditorLoaded && !state.isLoading) {
            final currentAct = state.novel.acts.firstWhereOrNull((a) => a.id == actId);
            if (currentAct != null) {
                final currentChapter = currentAct.chapters.firstWhereOrNull((c) => c.id == chapterId);
                if (currentChapter != null && currentChapter.scenes.length > initialSceneCountInChapter) {
                    final newScene = currentChapter.scenes.firstWhereOrNull(
                        (sc) => !initialSceneIdsInChapter.contains(sc.id)
                    );
                    if (newScene != null) {
                        subscription?.cancel();
                        if (!completer.isCompleted) {
                            completer.complete(newScene.id);
                        }
                    } else if (currentChapter.scenes.isNotEmpty && currentChapter.scenes.length > initialSceneCountInChapter){
                        final potentialNewScene = currentChapter.scenes.last;
                        if (!initialSceneIdsInChapter.contains(potentialNewScene.id)) {
                            subscription?.cancel();
                            if (!completer.isCompleted) {
                                completer.complete(potentialNewScene.id);
                            }
                        }
                    }
                }
            }
        }
    });

    editorBloc.add(editor_bloc.AddNewScene(
        novelId: editorBloc.novelId,
        actId: actId,
        chapterId: chapterId,
        sceneId: sceneIdProposal, // Use the proposed ID
    ));

   try {
        return await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
            subscription?.cancel();
            throw Exception('创建新场景超时');
        });
    } catch (e) {
        subscription?.cancel();
        rethrow;
    }
}
}
