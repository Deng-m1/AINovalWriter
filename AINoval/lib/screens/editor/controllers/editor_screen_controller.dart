import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/blocs/plan/plan_bloc.dart' as plan_bloc;
import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/prompt_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/services/sync_service.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
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

  // 编辑器状态
  bool isPlanViewActive = false;
  String? currentUserId;

  // 控制器集合
  final Map<String, QuillController> sceneControllers = {};
  final Map<String, TextEditingController> sceneTitleControllers = {};
  final Map<String, TextEditingController> sceneSubtitleControllers = {};
  final Map<String, TextEditingController> sceneSummaryControllers = {};
  final Map<String, GlobalKey> sceneKeys = {};

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

    // 使用分页加载，而不是加载所有内容
    editorBloc.add(editor_bloc.LoadEditorContentPaginated(
      novelId: novel.id,
      lastEditedChapterId: novel.lastEditedChapterId,
      chaptersLimit: 2, // 减少初始加载章节数，只加载最近编辑章节的前后各2章
    ));

    // 添加滚动监听，实现滚动加载更多场景
    scrollController.addListener(_onScroll);

    currentUserId = AppConfig.userId;
    if (currentUserId == null) {
      AppLogger.e(
          'EditorScreenController', 'User ID is null. Some features might be limited.');
    }
  }

  // 滚动监听函数，用于实现无限滚动加载
  void _onScroll() {
    // 滚动处理节流：限制短时间内多次处理滚动事件
    final now = DateTime.now();
    if (_lastScrollHandleTime != null &&
        now.difference(_lastScrollHandleTime!) < _scrollHandleInterval) {
      return; // 在节流间隔内，直接返回不处理
    }
    _lastScrollHandleTime = now;

    // 如果正在加载中，不触发新的加载请求
    if (editorBloc.state is editor_bloc.EditorLoaded &&
        (editorBloc.state as editor_bloc.EditorLoaded).isLoading) {
      return;
    }

    // 计算滚动速度
    final currentPosition = scrollController.position.pixels;
    if (_lastScrollTime != null) {
      final elapsed = now.difference(_lastScrollTime!).inMilliseconds;
      if (elapsed > 0) {
        final distance = (currentPosition - _lastScrollPosition).abs();
        final speed = distance / elapsed;

        // 速度过快时不触发加载
        if (speed > _maxScrollSpeed) {
          AppLogger.d('EditorScreenController', '滚动速度过快 ($speed px/ms)，暂不加载');
          _lastScrollPosition = currentPosition;
          _lastScrollTime = now;
          return;
        }
      }
    }

    // 更新滚动位置和时间
    _lastScrollPosition = currentPosition;
    _lastScrollTime = now;

    // 获取当前滚动位置
    final offset = scrollController.offset;
    final maxScroll = scrollController.position.maxScrollExtent;

    // 如果已经滚动到接近底部，加载更多场景
    if (offset >= maxScroll - _preloadDistance) {
      _loadMoreScenes('down');
    }

    // 如果滚动到接近顶部，加载更多场景
    if (offset <= _preloadDistance) {
      _loadMoreScenes('up');
    }
  }

  // 滚动相关变量
  DateTime? _lastScrollHandleTime;
  static const Duration _scrollHandleInterval = Duration(milliseconds: 50);
  static const Duration _scrollThrottleInterval = Duration(milliseconds: 300);
  static const double _preloadDistance = 800.0;
  double _lastScrollPosition = 0.0;
  DateTime? _lastScrollTime;
  static const double _maxScrollSpeed = 5.0;

  // 防抖变量，避免频繁触发加载
  DateTime? _lastLoadTime;
  String? _lastDirection;
  String? _lastFromChapterId;
  bool _isLoadingMore = false;

  // 用于滚动事件的节流控制
  DateTime? _lastScrollProcessTime;

  // 加载更多场景函数
  void _loadMoreScenes(String direction) {
    final state = editorBloc.state;
    if (state is! editor_bloc.EditorLoaded) return;

    // 滚动事件节流 - 避免短时间内频繁处理滚动事件
    final now = DateTime.now();
    if (_lastScrollProcessTime != null &&
        now.difference(_lastScrollProcessTime!) < _scrollThrottleInterval) {
      return; // 在节流间隔内，直接返回不处理
    }
    _lastScrollProcessTime = now;

    // 如果正在加载中，不重复触发
    if (state.isLoading || _isLoadingMore) return;

    // 设置临时标志，避免重复加载
    _isLoadingMore = true;

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
        // 没有章节可加载，重置标志
        _isLoadingMore = false;
        return;
      }
    }

    // 安全断言 - 此时我们已经确保fromChapterId不为null
    assert(fromChapterId != null, 'fromChapterId不应该为null');

    // 防抖：避免短时间内多次触发相同的加载请求
    if (_lastLoadTime != null &&
        now.difference(_lastLoadTime!).inSeconds < 2 &&
        _lastDirection == direction &&
        _lastFromChapterId == fromChapterId) {
      _isLoadingMore = false;
      return;
    }

    _lastLoadTime = now;
    _lastDirection = direction;
    _lastFromChapterId = fromChapterId;

    AppLogger.i('EditorScreenController', '加载更多场景: 方向=$direction, 起始章节=$fromChapterId');

    // 触发加载更多事件 - 使用非空断言操作符，因为我们已经确保fromChapterId不为null
    editorBloc.add(editor_bloc.LoadMoreScenes(
      fromChapterId: fromChapterId!, // 使用!操作符确保非空
      direction: direction,
      chaptersLimit: 3, // 每次加载3章内容
    ));

    // 延迟重置标志，给API调用一些时间
    Future.delayed(const Duration(milliseconds: 500), () {
      _isLoadingMore = false;
    });
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
      chaptersLimit: 1, // 只加载当前章节
    ));
  }

  // 切换Plan视图
  void togglePlanView() {
    AppLogger.i('EditorScreenController', '切换Plan视图，当前状态: $isPlanViewActive');
    final currentState = editorBloc.state;
    final isPlanToWrite = isPlanViewActive; // 如果当前是Plan视图，则将切换到Write视图

    // 切换状态
    isPlanViewActive = !isPlanViewActive;

    // 记录日志
    AppLogger.i('EditorScreenController', '切换后的Plan视图状态: $isPlanViewActive');

    // 如果激活Plan视图，加载Plan数据
    if (isPlanViewActive) {
      AppLogger.i('EditorScreenController', '加载Plan数据');
      planBloc.add(const plan_bloc.LoadPlanContent());
    }
    // 如果从Plan视图切换到Write视图，确保编辑器内容正常显示
    else if (isPlanToWrite && currentState is editor_bloc.EditorLoaded) {
      AppLogger.i('EditorScreenController', 'Switched from Plan to Write view. Scroll handled by BlocListener.');
    }

    // 强制触发状态更新
    editorBloc.add(const editor_bloc.RefreshEditor());

    // 通知监听器状态变化
    notifyListeners();

    // 延迟再次通知，确保 UI 更新
    Future.delayed(const Duration(milliseconds: 50), () {
      notifyListeners();
    });
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

  // 确保控制器存在于小说
  void ensureControllersForNovel(novel_models.Novel novel) {
    AppLogger.i('EditorScreenController',
        '确保控制器存在于小说: ${novel.id}. Acts: ${novel.acts.length}');
    bool controllersAdded = false;
    bool controllersChecked = false;

    if (novel.acts.isEmpty) {
      AppLogger.w(
          'EditorScreenController', '小说 ${novel.id} 没有 Acts，无法创建控制器。');
      if (sceneControllers.isNotEmpty) {
        AppLogger.w('EditorScreenController', '小说没有 Acts，但存在旧控制器，清理中...');
        clearAllControllers();
      }
      return;
    }

    // 记录当前有哪些有效的场景ID，用于清理不再需要的控制器
    final Set<String> validSceneIds = {};

    // 记录已加载场景的章节数和场景数，用于日志
    int loadedChapterCount = 0;
    int loadedSceneCount = 0;
    int totalChapterCount = 0;

    // 批量处理控制器，避免频繁的日志输出及不必要的消耗
    bool needsDetailedLog = false; // 是否需要详细日志
    final int totalActCount = novel.acts.length;

    for (int actIndex = 0; actIndex < novel.acts.length; actIndex++) {
      final act = novel.acts[actIndex];

      // 对于大型小说，只对前两个和最后一个Act记录详细日志
      needsDetailedLog = actIndex < 2 || actIndex == totalActCount - 1;

      if (needsDetailedLog) {
        AppLogger.d('EditorScreenController',
            '检查 Act: ${act.id} (${act.title}). Chapters: ${act.chapters.length}');
      }

      bool actHasLoadedScenes = false;

      for (final chapter in act.chapters) {
        totalChapterCount++;

        if (needsDetailedLog) {
          AppLogger.d('EditorScreenController',
              '检查 Chapter: ${chapter.id} (${chapter.title}). Scenes: ${chapter.scenes.length}');
        }

        // 跳过没有场景的章节，这些章节的场景可能尚未加载或需要按需加载
        if (chapter.scenes.isEmpty) {
          if (needsDetailedLog) {
            AppLogger.d('EditorScreenController',
                'Chapter ${chapter.id} 的场景未加载或没有场景，跳过控制器创建。');
          }
          continue;
        }

        // 标记这个章节已加载
        loadedChapterCount++;
        actHasLoadedScenes = true;
        controllersChecked = true;

        // 预分配场景ID数组，减少字符串操作
        final List<String> sceneIds = List.generate(
          chapter.scenes.length,
          (i) => '${act.id}_${chapter.id}_${chapter.scenes[i].id}'
        );

        // 标记所有有效场景ID
        validSceneIds.addAll(sceneIds);
        loadedSceneCount += chapter.scenes.length;

        // 批量创建缺失的控制器
        for (int i = 0; i < chapter.scenes.length; i++) {
          final sceneId = sceneIds[i];

          if (!sceneControllers.containsKey(sceneId)) {
            try {
              final scene = chapter.scenes[i];

              AppLogger.i(
                  'EditorScreenController', '检测到新场景或缺失控制器，创建: $sceneId');

              // 减少长内容的日志打印，提高性能
              if (needsDetailedLog && scene.content.length <= 50) {
                AppLogger.d('EditorScreenController',
                    '解析 Scene $sceneId 内容: "${scene.content}"');
              }

              final sceneDocument = _parseDocument(scene.content);

              if (needsDetailedLog) {
                AppLogger.d('EditorScreenController',
                    '设置 Scene $sceneId 摘要: "${scene.summary.content}"');
              }

              sceneControllers[sceneId] = QuillController(
                document: sceneDocument,
                selection: const TextSelection.collapsed(offset: 0),
              );
              sceneTitleControllers[sceneId] = TextEditingController(
                  text: '${chapter.title} · Scene ${i + 1}');
              sceneSubtitleControllers[sceneId] =
                  TextEditingController(text: '');
              sceneSummaryControllers[sceneId] =
                  TextEditingController(text: scene.summary.content);
              // Create and store GlobalKey
              sceneKeys[sceneId] = GlobalKey();
              controllersAdded = true;

              if (needsDetailedLog) {
                AppLogger.i('EditorScreenController', '成功创建控制器: $sceneId');
              }
            } catch (e, stackTrace) {
              AppLogger.e('EditorScreenController',
                  '创建新场景控制器失败: $sceneId', e, stackTrace);
              sceneControllers[sceneId] = QuillController.basic();
              sceneTitleControllers[sceneId] =
                  TextEditingController(text: '加载错误');
              sceneSubtitleControllers[sceneId] = TextEditingController();
              sceneSummaryControllers[sceneId] =
                  TextEditingController(text: '错误: $e');
            }
          } else if (needsDetailedLog) {
            // 仅在需要详细日志时记录"已存在"信息
            AppLogger.v('EditorScreenController', '控制器已存在: $sceneId');

            // 确保标题是最新的
            final expectedTitle = '${chapter.title} · Scene ${i + 1}';
            if (sceneTitleControllers[sceneId]?.text != expectedTitle) {
              sceneTitleControllers[sceneId]?.text = expectedTitle;
            }

            // 确保摘要是最新的
            final scene = chapter.scenes[i];
            if (sceneSummaryControllers[sceneId]?.text != scene.summary.content) {
              sceneSummaryControllers[sceneId]?.text = scene.summary.content;
            }
          }
        }
      }

      // 如果这个Act没有任何已加载的场景，记录日志
      if (!actHasLoadedScenes && needsDetailedLog) {
        AppLogger.d('EditorScreenController',
            'Act ${act.id} (${act.title}) 没有任何已加载场景，跳过整个Act。');
      }
    }

    // 清理不再需要的控制器，释放资源
    final List<String> controllersToRemove = sceneControllers.keys
        .where((id) => !validSceneIds.contains(id))
        .toList();

    if (controllersToRemove.isNotEmpty) {
      AppLogger.i('EditorScreenController',
          '清理 ${controllersToRemove.length} 个不再需要的控制器');

      for (final id in controllersToRemove) {
        sceneControllers[id]?.dispose();
        sceneControllers.remove(id);

        sceneTitleControllers[id]?.dispose();
        sceneTitleControllers.remove(id);

        sceneSubtitleControllers[id]?.dispose();
        sceneSubtitleControllers.remove(id);

        sceneSummaryControllers[id]?.dispose();
        sceneSummaryControllers.remove(id);
        // Remove GlobalKey
        sceneKeys.remove(id);
      }
    }

    AppLogger.i('EditorScreenController',
        '控制器确保完成。控制器总数: ${sceneControllers.length}, 总章节数: $totalChapterCount, 已加载章节: $loadedChapterCount (${(loadedChapterCount * 100 / totalChapterCount).toStringAsFixed(1)}%), 已加载场景: $loadedSceneCount. 是否添加新控制器: $controllersAdded, 是否检查过场景: $controllersChecked.');
  }

  // 解析文档内容
  Document _parseDocument(String content) {
    // 如果内容是空字符串，直接返回空文档
    if (content.isEmpty) {
      AppLogger.w('EditorScreenController', '解析内容为空字符串，视为空文档');
      return Document.fromJson([
        {'insert': '\n'}
      ]);
    }
    try {
      final dynamic deltaJson = jsonDecode(content);
      if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
        final ops = deltaJson['ops'];
        if (ops is List) {
          return Document.fromJson(ops);
        } else {
          AppLogger.i('EditorScreenController', 'ops 不是列表类型：$ops');
          return Document.fromJson([
            {'insert': '\n'}
          ]);
        }
      } else if (deltaJson is List) {
        return Document.fromJson(deltaJson);
      } else {
        AppLogger.w(
            'EditorScreenController', '内容格式不正确或非预期JSON: $content');
        return Document.fromJson([
          {'insert': '\n'}
        ]);
      }
    } catch (e, stackTrace) {
      AppLogger.e(
          'EditorScreenController', '解析内容失败，使用空文档', e, stackTrace);
      return Document.fromJson([
        {'insert': '\n'}
      ]);
    }
  }

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
    // 取消滚动监听器
    scrollController.removeListener(_onScroll);
    scrollController.dispose();

    // 释放焦点节点
    focusNode.dispose();

    // 尝试同步当前小说数据
    syncCurrentNovel();

    // 清理控制器资源
    clearAllControllers();

    // 关闭同步服务
    syncService.dispose();

    // 清理BLoC
    editorBloc.close();

    // 清理TabController
    tabController.dispose();

    // 调用父类的dispose方法
    super.dispose();
  }
}
