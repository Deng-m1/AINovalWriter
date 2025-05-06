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

  // 初始化方法
  void _init() {
    // 创建必要的实例
    apiClient = ApiClient();
    editorRepository = EditorRepositoryImpl();
    promptRepository = PromptRepositoryImpl(apiClient);
    localStorageService = LocalStorageService();

    tabController = TabController(length: 4, vsync: vsync);

    // 初始化EditorBloc
    editorBloc = editor_bloc.EditorBloc(
      repository: editorRepository,
      novelId: novel.id,
    );

    // 初始化PlanBloc
    planBloc = plan_bloc.PlanBloc(
      repository: editorRepository,
      novelId: novel.id,
    );

    // 初始化同步服务
    syncService = SyncService(
      apiService: apiClient,
      localStorageService: localStorageService,
    );

    // 初始化同步服务并设置当前小说
    syncService.init().then((_) {
      syncService.setCurrentNovelId(novel.id).then((_) {
        AppLogger.i('EditorScreenController', '已设置当前小说ID: ${novel.id}');
      });
    });

    // 分开大纲和编辑区加载逻辑
    // 1. 为侧边栏和大纲加载完整小说结构（包含所有场景摘要）
    editorRepository.getNovelWithSceneSummaries(novel.id).then((novelWithSummaries) {
      if (novelWithSummaries != null) {
        AppLogger.i('EditorScreenController', '已加载带摘要的小说结构用于大纲和侧边栏');

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

    // 1. 快速滚动检测 - 使用更高效的方法
    final bool isRapidScrolling = _detectRapidScrolling();
    if (isRapidScrolling) {
      // 在快速滚动时不执行任何耗时操作
      return;
    }

    // 2. 节流控制 - 防止过于频繁处理
    final now = DateTime.now();
    if (_lastScrollHandleTime != null) {
      // 根据当前滚动速度动态调整节流时间
      final minThrottle = _isScrollingSlowly() ? 100 : 180; // 根据滚动速度使用不同的节流时间
      if (now.difference(_lastScrollHandleTime!).inMilliseconds < minThrottle) {
        return; // 节流期间不处理
      }
    }
    _lastScrollHandleTime = now;

    // 3. 加载状态检查 - 避免重复请求
    if (_isAnyLoading()) {
      return; // 如果有任何加载进行中，跳过处理
    }

    // 4. 精简的边界检测逻辑
    _checkScrollBoundaries();

    // 5. 只在滚动稳定后检查可见场景
    if (_isScrollStable(300)) { // 减少稳定时间到300ms提高响应速度
      _checkVisibleScenesThrottled();
    }
  }

  // 优化版快速滚动检测
  bool _detectRapidScrolling() {
    if (!scrollController.hasClients) return false;

    final now = DateTime.now();
    final currentPosition = scrollController.offset;

    // 如果是第一次滚动，初始化参数并返回false
    if (_lastScrollTime == null || _lastScrollPosition == null) {
      _lastScrollTime = now;
      _lastScrollPosition = currentPosition;
      return false;
    }

    final elapsed = now.difference(_lastScrollTime!).inMilliseconds;
    // 防止除以零或极小值
    if (elapsed < 10) return false;

    final distance = (currentPosition - _lastScrollPosition!).abs();
    final speed = distance / elapsed;

    // 更新记录
    _lastScrollPosition = currentPosition;
    _lastScrollTime = now;

    // 缓存滚动速度用于其他判断
    _currentScrollSpeed = speed;

    // 提高阈值到3.0，更积极地判断为快速滚动
    return speed > 3.0;
  }

  // 检查是否正在缓慢滚动
  bool _isScrollingSlowly() {
    return _currentScrollSpeed != null && _currentScrollSpeed! < 0.8;
  }

  // 检查滚动边界并触发加载
  void _checkScrollBoundaries() {
    if (!scrollController.hasClients) return;

    final offset = scrollController.offset;
    final maxScroll = scrollController.position.maxScrollExtent;

    // 只在调试模式下输出日志，减少日志开销
    if (kDebugMode) {
      AppLogger.d('EditorScreenController', '滚动位置: $offset / $maxScroll, 预加载距离: $_preloadDistance');
    }

    // 相比之前的实现，使用更简洁的边界判断
    if (offset >= maxScroll - _preloadDistance) {
      _loadMoreScenes('down');
    } else if (offset <= _preloadDistance) {
      _loadMoreScenes('up');
    }
  }

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

  // 判断滚动是否已经稳定一段时间
  bool _isScrollStable(int milliseconds) {
    if (_lastScrollTime == null) return false;
    final now = DateTime.now();
    return now.difference(_lastScrollTime!).inMilliseconds >= milliseconds;
  }

  // 加载更多场景函数
  void _loadMoreScenes(String direction) {
    final state = editorBloc.state;
    if (state is! editor_bloc.EditorLoaded) {
      AppLogger.w('EditorScreenController', '无法加载更多场景: 编辑器尚未初始化');
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
      AppLogger.i('EditorScreenController', '已经加载到最后一章，不需要继续加载');
    }
    // 上滑检查是否已经到顶
    else if (direction == 'up' && _findFirstLoadedChapterId(state.novel) == _findFirstChapterId(state.novel)) {
      alreadyHasEnoughContent = true;
      AppLogger.i('EditorScreenController', '已经加载到第一章，不需要继续加载');
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
    } catch (e) {
      AppLogger.e('EditorScreenController', '加载更多场景出错', e);
      _isLoadingMore = false;
      notifyListeners(); // 更新UI状态
    } finally {
      // 延迟重置标志，给API调用一些时间
      Future.delayed(const Duration(milliseconds: 1000), () {
        _isLoadingMore = false;
        notifyListeners(); // 确保加载状态被重置
      });
    }
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
}
