import 'dart:async';
import 'dart:convert';

/*
 * 编辑器屏幕性能优化措施：
 * 1. 控制器检查节流：添加_shouldCheckControllers方法，避免每次滚动时都检查控制器
 * 2. EditorBloc监听优化：只在必要时（保存状态、活动场景等变化）触发UI更新
 * 3. 滚动事件节流：避免频繁触发滚动加载更多功能，减少API调用
 * 4. 控制器创建优化：减少不必要的日志输出，批量处理场景ID生成
 * 5. 高效数据结构：使用Set和预分配列表，减少字符串操作
 */

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/config/app_config.dart'; // <<< Import AppConfig
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/chat/widgets/ai_chat_sidebar.dart';
import 'package:ainoval/screens/editor/components/editor_app_bar.dart';
import 'package:ainoval/screens/editor/components/editor_main_area.dart';
// 导入拆分后的组件
import 'package:ainoval/screens/editor/components/editor_sidebar.dart';
import 'package:ainoval/screens/editor/widgets/editor_settings_panel.dart';
import 'package:ainoval/screens/editor/widgets/editor_toolbar.dart';
import 'package:ainoval/screens/settings/settings_panel.dart'; // <<< Import SettingsPanel
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ScrollActivity; // 导入ScrollActivity
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' hide EditorState;
import 'package:shared_preferences/shared_preferences.dart'; // 导入持久化功能

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.novel,
  });
  final NovelSummary novel;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  late final EditorBloc _editorBloc;
  late TabController _tabController;

  final Map<String, QuillController> _sceneControllers = {};

  final Map<String, TextEditingController> _sceneTitleControllers = {};
  final Map<String, TextEditingController> _sceneSubtitleControllers = {};
  final Map<String, TextEditingController> _sceneSummaryControllers = {};

  bool _isAIChatSidebarVisible = false; // 控制聊天侧边栏是否可见
  bool _isSettingsPanelVisible = false; // 控制设置面板是否可见
  bool _isEditorSidebarVisible = true; // 控制编辑器侧边栏是否可见

  // 聊天侧边栏宽度相关状态
  double _chatSidebarWidth = 380; // 默认宽度
  static const double _minChatSidebarWidth = 280; // 最小宽度
  static const double _maxChatSidebarWidth = 500; // 最大宽度
  static const String _chatSidebarWidthPrefKey = 'chat_sidebar_width'; // 持久化键

  // 编辑器侧边栏宽度相关状态
  double _editorSidebarWidth = 280; // 默认宽度
  static const double _minEditorSidebarWidth = 220; // 减小最小宽度
  static const double _maxEditorSidebarWidth = 400; // 最大宽度
  static const String _editorSidebarWidthPrefKey =
      'editor_sidebar_width'; // 持久化键

  String? _currentUserId; // Store userId
  
  // 控制器检查节流相关变量
  DateTime? _lastControllerCheckTime;
  static const Duration _controllerCheckInterval = Duration(milliseconds: 500);
  // 控制器检查间隔，单独设置为5秒，降低频率
  static const Duration _controllerLongCheckInterval = Duration(seconds: 5);
  EditorLoaded? _lastEditorState; // 缓存上一次的EditorLoaded状态
  
  // 字数统计缓存
  int _cachedWordCount = 0;
  String? _wordCountCacheKey;
  // 字数统计内存缓存，用于同一次渲染周期内避免重复计算
  Map<String, int> _memoryWordCountCache = {};
  
  // 滚动处理节流
  DateTime? _lastScrollHandleTime;
  static const Duration _scrollHandleInterval = Duration(milliseconds: 50);

  // 滚动相关常量
  static const Duration _scrollThrottleInterval = Duration(milliseconds: 300);
  // 预加载距离，当滚动到距离边缘这个值时开始加载下一页
  static const double _preloadDistance = 800.0;

  // 记录上次滚动位置和时间，用于计算滚动速度
  double _lastScrollPosition = 0.0;
  DateTime? _lastScrollTime;
  // 滚动速度阈值 (像素/毫秒)
  static const double _maxScrollSpeed = 5.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _editorBloc = EditorBloc(
      repository: EditorRepositoryImpl(),
      novelId: widget.novel.id,
    );
    
    // 使用分页加载，而不是加载所有内容
    // 从小说列表进入时，使用lastEditedChapterId为null，让后端自动选择最近编辑的章节
    _editorBloc.add(LoadEditorContentPaginated(
      novelId: widget.novel.id,
      // NovelSummary没有lastEditedChapterId字段，传null让后端自行处理
      lastEditedChapterId: null,
      chaptersLimit: 2, // 减少初始加载章节数，只加载最近编辑章节的前后各2章
    ));

    // 添加监听器确保数据变化时界面更新
    _editorBloc.stream.listen((state) {
      if (state is EditorLoaded && mounted) {
        // 不再始终更新UI，只在必要时更新
        final EditorLoaded lastState = _lastEditorState ?? state;
        
        // 只有在以下情况才更新UI:
        // 1. 保存状态变化
        // 2. 错误信息变化
        // 3. 活动场景/章节/部分变化
        // 4. 字数统计变化
        bool shouldUpdateUI = lastState.isSaving != state.isSaving ||
            lastState.errorMessage != state.errorMessage ||
            lastState.activeActId != state.activeActId ||
            lastState.activeChapterId != state.activeChapterId ||
            lastState.activeSceneId != state.activeSceneId;
            
        // 只在必要时触发setState
        if (shouldUpdateUI) {
          setState(() {});
        }
      }
    });

    // 添加滚动监听，实现滚动加载更多场景
    _scrollController.addListener(_onScroll);

    _currentUserId = AppConfig.userId;
    if (_currentUserId == null) {
      AppLogger.e(
          'EditorScreen', 'User ID is null. Some features might be limited.');
    }

    // 加载保存的聊天侧边栏宽度
    _loadSavedChatSidebarWidth();

    // 加载保存的编辑器侧边栏宽度
    _loadSavedEditorSidebarWidth();
  }

  // 加载保存的聊天侧边栏宽度
  Future<void> _loadSavedChatSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble(_chatSidebarWidthPrefKey);
      if (savedWidth != null) {
        if (savedWidth >= _minChatSidebarWidth &&
            savedWidth <= _maxChatSidebarWidth) {
          setState(() {
            _chatSidebarWidth = savedWidth;
          });
        }
      }
    } catch (e) {
      AppLogger.e('EditorScreen', '加载侧边栏宽度失败', e);
    }
  }

  // 保存聊天侧边栏宽度
  Future<void> _saveChatSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_chatSidebarWidthPrefKey, _chatSidebarWidth);
    } catch (e) {
      AppLogger.e('EditorScreen', '保存侧边栏宽度失败', e);
    }
  }

  // 加载保存的编辑器侧边栏宽度
  Future<void> _loadSavedEditorSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble(_editorSidebarWidthPrefKey);
      if (savedWidth != null) {
        if (savedWidth >= _minEditorSidebarWidth &&
            savedWidth <= _maxEditorSidebarWidth) {
          setState(() {
            _editorSidebarWidth = savedWidth;
          });
        }
      }
    } catch (e) {
      AppLogger.e('EditorScreen', '加载编辑器侧边栏宽度失败', e);
    }
  }

  // 保存编辑器侧边栏宽度
  Future<void> _saveEditorSidebarWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_editorSidebarWidthPrefKey, _editorSidebarWidth);
    } catch (e) {
      AppLogger.e('EditorScreen', '保存编辑器侧边栏宽度失败', e);
    }
  }

  // 显示编辑器侧边栏宽度调整对话框
  void _showEditorSidebarWidthDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('调整侧边栏宽度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前宽度: ${_editorSidebarWidth.toInt()} 像素'),
              const SizedBox(height: 16),
              Slider(
                value: _editorSidebarWidth,
                min: _minEditorSidebarWidth,
                max: _maxEditorSidebarWidth,
                divisions: 8,
                label: _editorSidebarWidth.toInt().toString(),
                onChanged: (value) {
                  setState(() {
                    _editorSidebarWidth = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveEditorSidebarWidth();
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _ensureControllersForNovel(novel_models.Novel novel) {
    AppLogger.i('Screens/editor/editor_screen',
        '确保控制器存在于小说: ${novel.id}. Acts: ${novel.acts.length}');
    bool controllersAdded = false;
    bool controllersChecked = false;

    if (novel.acts.isEmpty) {
      AppLogger.w(
          'Screens/editor/editor_screen', '小说 ${novel.id} 没有 Acts，无法创建控制器。');
      if (_sceneControllers.isNotEmpty) {
        AppLogger.w('Screens/editor/editor_screen', '小说没有 Acts，但存在旧控制器，清理中...');
        _clearAllControllers();
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
        AppLogger.d('Screens/editor/editor_screen',
            '检查 Act: ${act.id} (${act.title}). Chapters: ${act.chapters.length}');
      }
      
      bool actHasLoadedScenes = false;

      for (final chapter in act.chapters) {
        totalChapterCount++;
        
        if (needsDetailedLog) {
          AppLogger.d('Screens/editor/editor_screen',
              '检查 Chapter: ${chapter.id} (${chapter.title}). Scenes: ${chapter.scenes.length}');
        }
        
        // 跳过没有场景的章节，这些章节的场景可能尚未加载或需要按需加载
        if (chapter.scenes.isEmpty) {
          if (needsDetailedLog) {
            AppLogger.d('Screens/editor/editor_screen',
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
          
          if (!_sceneControllers.containsKey(sceneId)) {
            try {
              final scene = chapter.scenes[i];
              
              AppLogger.i(
                  'Screens/editor/editor_screen', '检测到新场景或缺失控制器，创建: $sceneId');
                  
              // 减少长内容的日志打印，提高性能
              if (needsDetailedLog && scene.content.length <= 50) {
                AppLogger.d('Screens/editor/editor_screen',
                    '解析 Scene $sceneId 内容: "${scene.content}"');
              }
              
              final sceneDocument = _parseDocument(scene.content);

              if (needsDetailedLog) {
                AppLogger.d('Screens/editor/editor_screen',
                    '设置 Scene $sceneId 摘要: "${scene.summary.content}"');
              }

              _sceneControllers[sceneId] = QuillController(
                document: sceneDocument,
                selection: const TextSelection.collapsed(offset: 0),
              );
              _sceneTitleControllers[sceneId] = TextEditingController(
                  text: '${chapter.title} · Scene ${i + 1}');
              _sceneSubtitleControllers[sceneId] =
                  TextEditingController(text: '');
              _sceneSummaryControllers[sceneId] =
                  TextEditingController(text: scene.summary.content);
              controllersAdded = true;
              
              if (needsDetailedLog) {
                AppLogger.i('Screens/editor/editor_screen', '成功创建控制器: $sceneId');
              }
            } catch (e, stackTrace) {
              AppLogger.e('Screens/editor/editor_screen',
                  '创建新场景控制器失败: $sceneId', e, stackTrace);
              _sceneControllers[sceneId] = QuillController.basic();
              _sceneTitleControllers[sceneId] =
                  TextEditingController(text: '加载错误');
              _sceneSubtitleControllers[sceneId] = TextEditingController();
              _sceneSummaryControllers[sceneId] =
                  TextEditingController(text: '错误: $e');
            }
          } else if (needsDetailedLog) {
            // 仅在需要详细日志时记录"已存在"信息
            AppLogger.v('Screens/editor/editor_screen', '控制器已存在: $sceneId');
            
            // 确保标题是最新的
            final expectedTitle = '${chapter.title} · Scene ${i + 1}';
            if (_sceneTitleControllers[sceneId]?.text != expectedTitle) {
              _sceneTitleControllers[sceneId]?.text = expectedTitle;
            }
            
            // 确保摘要是最新的
            final scene = chapter.scenes[i];
            if (_sceneSummaryControllers[sceneId]?.text != scene.summary.content) {
              _sceneSummaryControllers[sceneId]?.text = scene.summary.content;
            }
          }
        }
      }
      
      // 如果这个Act没有任何已加载的场景，记录日志
      if (!actHasLoadedScenes && needsDetailedLog) {
        AppLogger.d('Screens/editor/editor_screen',
            'Act ${act.id} (${act.title}) 没有任何已加载场景，跳过整个Act。');
      }
    }
    
    // 清理不再需要的控制器，释放资源
    final List<String> controllersToRemove = _sceneControllers.keys
        .where((id) => !validSceneIds.contains(id))
        .toList();
        
    if (controllersToRemove.isNotEmpty) {
      AppLogger.i('Screens/editor/editor_screen', 
          '清理 ${controllersToRemove.length} 个不再需要的控制器');
      
      for (final id in controllersToRemove) {
        _sceneControllers[id]?.dispose();
        _sceneControllers.remove(id);
        
        _sceneTitleControllers[id]?.dispose();
        _sceneTitleControllers.remove(id);
        
        _sceneSubtitleControllers[id]?.dispose();
        _sceneSubtitleControllers.remove(id);
        
        _sceneSummaryControllers[id]?.dispose();
        _sceneSummaryControllers.remove(id);
      }
    }

    AppLogger.i('Screens/editor/editor_screen',
        '控制器确保完成。控制器总数: ${_sceneControllers.length}, 总章节数: $totalChapterCount, 已加载章节: $loadedChapterCount (${(loadedChapterCount * 100 / totalChapterCount).toStringAsFixed(1)}%), 已加载场景: $loadedSceneCount. 是否添加新控制器: $controllersAdded, 是否检查过场景: $controllersChecked.');
  }

  void _createControllersForNovel(novel_models.Novel novel) {
    AppLogger.i('Screens/editor/editor_screen', '为小说创建控制器: ${novel.id}');
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        for (int i = 0; i < chapter.scenes.length; i++) {
          final scene = chapter.scenes[i];
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';
          if (!_sceneControllers.containsKey(sceneId)) {
            try {
              final sceneDocument = _parseDocument(scene.content);
              _sceneControllers[sceneId] = QuillController(
                document: sceneDocument,
                selection: const TextSelection.collapsed(offset: 0),
              );
              _sceneTitleControllers[sceneId] = TextEditingController(
                  text: '${chapter.title} · Scene ${i + 1}');
              _sceneSubtitleControllers[sceneId] =
                  TextEditingController(text: '');
              _sceneSummaryControllers[sceneId] =
                  TextEditingController(text: scene.summary.content);
              AppLogger.d('Screens/editor/editor_screen', '已创建控制器: $sceneId');
            } catch (e) {
              AppLogger.e(
                  'Screens/editor/editor_screen', '创建场景控制器失败: $sceneId', e);
              _sceneControllers[sceneId] = QuillController.basic();
              _sceneTitleControllers[sceneId] =
                  TextEditingController(text: '错误');
              _sceneSubtitleControllers[sceneId] = TextEditingController();
              _sceneSummaryControllers[sceneId] = TextEditingController();
            }
          }
        }
      }
    }
  }

  void _clearAllControllers() {
    AppLogger.i('Screens/editor/editor_screen', '清理所有控制器');
    for (final controller in _sceneControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        AppLogger.e('Screens/editor/editor_screen', '关闭场景控制器失败', e);
      }
    }
    _sceneControllers.clear();

    for (final controller in _sceneTitleControllers.values) {
      controller.dispose();
    }
    _sceneTitleControllers.clear();
    for (final controller in _sceneSubtitleControllers.values) {
      controller.dispose();
    }
    _sceneSubtitleControllers.clear();
    for (final controller in _sceneSummaryControllers.values) {
      controller.dispose();
    }
    _sceneSummaryControllers.clear();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounceTimer?.cancel();
    _clearAllControllers();
    _scrollController.dispose();
    _focusNode.dispose();
    _editorBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 清除内存缓存，确保每次build周期都使用新的内存缓存
    // 这样可以在同一个build周期内避免重复计算，但不会在不同的build周期之间复用可能过期的结果
    _memoryWordCountCache.clear();
    
    // 将BlocProvider移到最外层，包裹整个Scaffold
    return BlocProvider.value(
      value: _editorBloc,
      child: Scaffold(
        body: Row(
          children: [
            // 左侧导航
            if (_isEditorSidebarVisible) ...[
              SizedBox(
                width: _editorSidebarWidth,
                child: EditorSidebar(
                  novel: widget.novel,
                  tabController: _tabController,
                  onOpenAIChat: () {
                    setState(() {
                      _isAIChatSidebarVisible = true;
                      _isSettingsPanelVisible = false; // 关闭设置面板
                    });
                  },
                  onOpenSettings: () {
                    setState(() {
                      _isSettingsPanelVisible = true;
                      _isAIChatSidebarVisible = false; // 关闭聊天侧边栏
                    });
                  },
                  onToggleSidebar: () {
                    setState(() {
                      _isEditorSidebarVisible = false;
                    });
                  },
                  onAdjustWidth: _showEditorSidebarWidthDialog,
                ),
              ),
              _DraggableDivider(
                onDragUpdate: (delta) {
                  setState(() {
                    // 更新侧边栏宽度，同时考虑最小/最大限制
                    _editorSidebarWidth =
                        (_editorSidebarWidth + delta.delta.dx).clamp(
                      _minEditorSidebarWidth,
                      _maxEditorSidebarWidth,
                    );
                  });
                },
                onDragEnd: (_) {
                  // 拖拽结束时保存宽度
                  _saveEditorSidebarWidth();
                },
              ),
            ],
            // 主编辑区域
            Expanded(
              child: BlocBuilder<EditorBloc, EditorState>(
                buildWhen: (previous, current) {
                  // 只在状态类型变化或数据结构真正变化时重建UI
                  if (previous.runtimeType != current.runtimeType) {
                    return true; // 状态类型变化时重建
                  }
                  
                  // 如果都是EditorLoaded状态，做深度比较
                  if (previous is EditorLoaded && current is EditorLoaded) {
                    final EditorLoaded prevLoaded = previous;
                    final EditorLoaded currLoaded = current;
                    
                    // 先检查时间戳，如果相同且非零，大概率内容相同
                    final prevTimestamp = prevLoaded.novel.updatedAt?.millisecondsSinceEpoch ?? 0;
                    final currTimestamp = currLoaded.novel.updatedAt?.millisecondsSinceEpoch ?? 0;
                    
                    // 如果时间戳都不为0但不同，内容肯定变化了
                    if (prevTimestamp != currTimestamp && 
                        prevTimestamp > 0 && currTimestamp > 0) {
                      return true;
                    }
                    
                    // 严格限制重建条件，只有这些关键状态变化时才重建
                    return prevLoaded.isSaving != currLoaded.isSaving ||
                        prevLoaded.isLoading != currLoaded.isLoading ||
                        prevLoaded.errorMessage != currLoaded.errorMessage ||
                        prevLoaded.activeActId != currLoaded.activeActId ||
                        prevLoaded.activeChapterId != currLoaded.activeChapterId ||
                        prevLoaded.activeSceneId != currLoaded.activeSceneId ||
                        // 小说基本结构变化检查
                        prevLoaded.novel.acts.length != currLoaded.novel.acts.length;
                  }
                  
                  return true; // 其他情况保守处理，进行重建
                },
                builder: (context, state) {
                  if (state is EditorLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is EditorError) {
                    return Center(child: Text('错误: ${state.message}'));
                  } else if (state is EditorLoaded) {
                    // 使用节流函数决定是否需要检查控制器
                    if (_shouldCheckControllers(state)) {
                      _ensureControllersForNovel(state.novel);
                    }
                    return _buildLoadedEditor(context, state);
                  } else {
                    return const Center(child: Text('未知状态'));
                  }
                },
              ),
            ),
            // 右侧助手面板
            if (_isAIChatSidebarVisible) ...[
              _DraggableDivider(
                onDragUpdate: (delta) {
                  setState(() {
                    // 更新侧边栏宽度，同时考虑最小/最大限制
                    _chatSidebarWidth =
                        (_chatSidebarWidth - delta.delta.dx).clamp(
                      _minChatSidebarWidth,
                      _maxChatSidebarWidth,
                    );
                  });
                },
                onDragEnd: (_) {
                  // 拖拽结束时保存宽度
                  _saveChatSidebarWidth();
                },
              ),
              SizedBox(
                width: _chatSidebarWidth,
                child: BlocBuilder<EditorBloc, EditorState>(
                  buildWhen: (previous, current) {
                    // 只在状态类型变化或chapterId变化时重建
                    if (previous.runtimeType != current.runtimeType) {
                      return true;
                    }
                    if (previous is EditorLoaded && current is EditorLoaded) {
                      return previous.activeChapterId != current.activeChapterId;
                    }
                    return true;
                  },
                  builder: (context, state) {
                    if (state is EditorLoaded) {
                      return AIChatSidebar(
                        novelId: widget.novel.id,
                        chapterId: state.activeChapterId,
                        onClose: () {
                          setState(() {
                            _isAIChatSidebarVisible = false;
                          });
                        },
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              )
            ],
          ],
        ),
        floatingActionButton: BlocBuilder<EditorBloc, EditorState>(
          buildWhen: (previous, current) {
            if (previous.runtimeType != current.runtimeType) {
              return true;
            }
            if (previous is EditorLoaded && current is EditorLoaded) {
              return previous.isSaving != current.isSaving;
            }
            return true;
          },
          builder: (context, state) {
            if (state is EditorLoaded && state.isSaving) {
              return FloatingActionButton(
                heroTag: 'saving',
                onPressed: null,
                backgroundColor: Colors.grey.shade400,
                tooltip: '正在保存...',
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            } else if (_isAIChatSidebarVisible) {
              return Container();
            } else {
              return FloatingActionButton(
                heroTag: 'chat',
                onPressed: () {
                  setState(() {
                    _isAIChatSidebarVisible = !_isAIChatSidebarVisible;
                  });
                },
                backgroundColor: Colors.grey.shade700,
                tooltip: '打开AI聊天',
                child: const Icon(
                  Icons.chat,
                  color: Colors.white,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // 为指定章节手动加载场景内容
  void _loadScenesForChapter(String chapterId) {
    _editorBloc.add(LoadMoreScenes(
      fromChapterId: chapterId,
      direction: 'center',
      chaptersLimit: 1, // 只加载当前章节
    ));
  }
  
  // 暴露加载方法，供子组件调用
  void loadScenesForChapter(String chapterId) {
    _loadScenesForChapter(chapterId);
  }

  Widget _buildLoadedEditor(BuildContext context, EditorLoaded state) {
    final fallbackController = _getFallbackController(state);

    // Get userId, provide default or handle error if null
    final userIdForPanel = _currentUserId;

    // 提前计算字数，避免每次重建UI时都重新计算
    final wordCount = _calculateTotalWordCount(state.novel);

    return Stack(
      children: [
        Column(
          children: [
            // 编辑器顶部工具栏和操作栏
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorAppBar(
                  novelTitle: widget.novel.title,
                  wordCount: wordCount, // 使用提前计算的字数
                  isSaving: state.isSaving,
                  lastSaveTime: state.lastSaveTime,
                  onBackPressed: () => Navigator.pop(context),
                  onChatPressed: () {
                    setState(() {
                      _isAIChatSidebarVisible =
                          !_isAIChatSidebarVisible;
                      if (_isAIChatSidebarVisible) {
                        _isSettingsPanelVisible = false; // 打开聊天时关闭设置
                      }
                    });
                  },
                  isChatActive: _isAIChatSidebarVisible,
                  onAiConfigPressed: () {
                    setState(() {
                      _isSettingsPanelVisible =
                          !_isSettingsPanelVisible;
                      if (_isSettingsPanelVisible) {
                        _isAIChatSidebarVisible = false; // 打开设置时关闭聊天
                      }
                    });
                  },
                  isSettingsActive: _isSettingsPanelVisible,
                ),
                EditorToolbar(
                  controller: fallbackController,
                ),
              ],
            ),
            // 主编辑区域与聊天侧边栏
            Expanded(
              child: Row(
                children: [
                  // 主编辑区域
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16),
                      child: EditorMainArea(
                        novel: state.novel,
                        editorBloc: _editorBloc,
                        sceneControllers: _sceneControllers,
                        sceneSummaryControllers:
                            _sceneSummaryControllers,
                        activeActId: state.activeActId,
                        activeChapterId: state.activeChapterId,
                        activeSceneId: state.activeSceneId,
                        scrollController: _scrollController,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!_isEditorSidebarVisible)
          Positioned(
            left: 0,
            top: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isEditorSidebarVisible = true;
                  });
                },
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        if (_isSettingsPanelVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isSettingsPanelVisible = false),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: userIdForPanel == null
                        ? _buildLoginRequiredPanel(context)
                        : SettingsPanel(
                            userId: userIdForPanel,
                            onClose: () {
                              setState(() {
                                _isSettingsPanelVisible = false;
                              });
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Helper widget to show when user is not logged in
  Widget _buildLoginRequiredPanel(BuildContext context) {
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: 400, // Smaller width for message
        height: 200, // Smaller height for message
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '需要登录', // TODO: Localize
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '请先登录以访问和管理 AI 配置。', // TODO: Localize
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement navigation to login screen
                setState(() =>
                    _isSettingsPanelVisible = false); // Close panel for now
              },
              child: const Text('前往登录'), // TODO: Localize
            )
          ],
        ),
      ),
    );
  }

  QuillController _getFallbackController(EditorLoaded state) {
    if (state.activeActId != null &&
        state.activeChapterId != null &&
        state.activeSceneId != null) {
      final activeControllerId =
          '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}';
      if (_sceneControllers.containsKey(activeControllerId)) {
        AppLogger.d(
            'Screens/editor/editor_screen', '获取活动控制器: $activeControllerId');
        return _sceneControllers[activeControllerId]!;
      } else {
        AppLogger.w(
            'Screens/editor/editor_screen', '活动控制器 $activeControllerId 未找到!');
      }
    }
    if (_sceneControllers.isNotEmpty) {
      AppLogger.w('Screens/editor/editor_screen',
          '返回第一个可用控制器: ${_sceneControllers.keys.first}');
      return _sceneControllers.values.first;
    }
    AppLogger.e('Screens/editor/editor_screen', '没有可用的控制器，返回基础控制器');
    return QuillController.basic();
  }

  Widget _buildSettingsScreen(
      BuildContext context, EditorSettingsOpen state, AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editorSettings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<EditorBloc>().add(const ToggleEditorSettings());
          },
        ),
      ),
      body: EditorSettingsPanel(
        settings: EditorSettings.fromMap(state.settings),
        onSettingsChanged: (newSettings) {
          context
              .read<EditorBloc>()
              .add(UpdateEditorSettings(settings: newSettings.toMap()));
        },
      ),
    );
  }

  Document _parseDocument(String content) {
    // 如果内容是空字符串，直接返回空文档
    if (content.isEmpty) {
      AppLogger.w('Screens/editor/editor_screen', '解析内容为空字符串，视为空文档');
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
          AppLogger.i('Screens/editor/editor_screen', 'ops 不是列表类型：$ops');
          return Document.fromJson([
            {'insert': '\n'}
          ]);
        }
      } else if (deltaJson is List) {
        return Document.fromJson(deltaJson);
      } else {
        AppLogger.w(
            'Screens/editor/editor_screen', '内容格式不正确或非预期JSON: $content');
        return Document.fromJson([
          {'insert': '\n'}
        ]);
      }
    } catch (e, stackTrace) {
      AppLogger.e(
          'Screens/editor/editor_screen', '解析内容失败，使用空文档', e, stackTrace);
      return Document.fromJson([
        {'insert': '\n'}
      ]);
    }
  }

  int _calculateTotalWordCount(novel_models.Novel novel) {
    // 生成缓存键：使用更新时间和场景总数作为缓存键
    final totalSceneCount = novel.acts.fold(0, (sum, act) => 
        sum + act.chapters.fold(0, (sum, chapter) => 
            sum + chapter.scenes.length));
    
    final updatedAtMs = novel.updatedAt?.millisecondsSinceEpoch ?? 0;
    final cacheKey = '${novel.id}_${updatedAtMs}_$totalSceneCount';
    
    // 首先检查内存缓存，这是最快的检查方式
    if (_memoryWordCountCache.containsKey(cacheKey)) {
      // 完全跳过日志记录以提高性能
      return _memoryWordCountCache[cacheKey]!;
    }
    
    // 如果持久化缓存有效，直接返回缓存的字数
    if (cacheKey == _wordCountCacheKey && _cachedWordCount > 0) {
      // 同时更新内存缓存
      _memoryWordCountCache[cacheKey] = _cachedWordCount;
      return _cachedWordCount;
    }
    
    // 检查是否在滚动过程中 - 如果在滚动，使用旧缓存或返回0而不是计算
    final now = DateTime.now();
    if (_lastScrollHandleTime != null && 
        now.difference(_lastScrollHandleTime!) < const Duration(seconds: 2)) {
      // 在滚动过程中，如果有缓存直接用，没有就返回0避免计算
      if (_cachedWordCount > 0) {
        AppLogger.d('EditorScreen', '滚动中使用缓存字数: $_cachedWordCount');
        // 同时更新内存缓存
        _memoryWordCountCache[cacheKey] = _cachedWordCount;
        return _cachedWordCount;
      } else {
        AppLogger.d('EditorScreen', '滚动中跳过字数计算');
        return 0; // 返回0避免计算
      }
    }
    
    // 正常情况下，记录字数计算原因
    AppLogger.i('EditorScreen', '字数统计缓存无效，重新计算。新缓存键: $cacheKey，旧缓存键: ${_wordCountCacheKey ?? "无"}');
  
    // 计算总字数（不再重复计算每个场景的字数）
    int totalWordCount = 0;
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        for (final scene in chapter.scenes) {
          // 直接使用存储的字数，不重新计算
          totalWordCount += scene.wordCount;
        }
      }
    }

    // 更新缓存，并减少日志输出
    _wordCountCacheKey = cacheKey;
    _cachedWordCount = totalWordCount;
    
    // 同时更新内存缓存
    _memoryWordCountCache[cacheKey] = totalWordCount;
    
    AppLogger.i('EditorScreen', '小说总字数计算结果: $totalWordCount (Acts: ${novel.acts.length}, 更新缓存键: $cacheKey)');
    return totalWordCount;
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
    if (_editorBloc.state is EditorLoaded && 
        (_editorBloc.state as EditorLoaded).isLoading) {
      return;
    }
    
    // 计算滚动速度
    final currentPosition = _scrollController.position.pixels;
    if (_lastScrollTime != null) {
      final elapsed = now.difference(_lastScrollTime!).inMilliseconds;
      if (elapsed > 0) {
        final distance = (currentPosition - _lastScrollPosition).abs();
        final speed = distance / elapsed;
        
        // 速度过快时不触发加载
        if (speed > _maxScrollSpeed) {
          AppLogger.d('EditorScreen', '滚动速度过快 ($speed px/ms)，暂不加载');
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
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // 如果已经滚动到接近底部，加载更多场景
    if (offset >= maxScroll - _preloadDistance) {
      _loadMoreScenes('down');
    }
    
    // 如果滚动到接近顶部，加载更多场景
    if (offset <= _preloadDistance) {
      _loadMoreScenes('up');
    }
  }
  
  // 防抖变量，避免频繁触发加载
  DateTime? _lastLoadTime;
  String? _lastDirection;
  String? _lastFromChapterId;
  bool _isLoadingMore = false;
  
  // 用于滚动事件的节流控制
  DateTime? _lastScrollProcessTime;

  // 加载更多场景函数
  void _loadMoreScenes(String direction) {
    final state = _editorBloc.state;
    if (state is! EditorLoaded) return;
    
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
    assert(fromChapterId != null, "fromChapterId不应该为null");
    
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
    
    AppLogger.i('EditorScreen', '加载更多场景: 方向=$direction, 起始章节=$fromChapterId');
    
    // 触发加载更多事件 - 使用非空断言操作符，因为我们已经确保fromChapterId不为null
    _editorBloc.add(LoadMoreScenes(
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
      AppLogger.i('EditorScreen', 
          '当前共有 $totalChapters 个章节，其中 $emptyChapters 个章节没有场景（未加载或空章节）');
    }
  }

  // 优化后的控制器检查方法，加入节流功能
  bool _shouldCheckControllers(EditorLoaded state) {
    // 如果状态对象引用变化，表示小说数据结构可能发生变化，需要检查
    final bool stateChanged = _lastEditorState != state;
    
    // 极端节流：如果距离上次检查时间不足5秒，绝对不检查
    final now = DateTime.now();
    if (_lastControllerCheckTime != null && 
        now.difference(_lastControllerCheckTime!) < const Duration(seconds: 5)) {
      // 记录日志：禁止频繁检查
      if (stateChanged) {
        AppLogger.d('Screens/editor/editor_screen', '节流: 禁止5秒内重复检查控制器');
      }
      return false;
    }

    // 如果状态变了，深入比较关键属性是否真的变化
    bool contentChanged = false;
    if (stateChanged && _lastEditorState != null) {
      // 检查小说结构是否有实质变化，主要比较acts和scenes的数量
      final oldNovel = _lastEditorState!.novel;
      final newNovel = state.novel;
      
      // 检查更新时间戳是否变化 - 表示内容实际被修改
      final oldTimestamp = oldNovel.updatedAt?.millisecondsSinceEpoch ?? 0;
      final newTimestamp = newNovel.updatedAt?.millisecondsSinceEpoch ?? 0;
      if (oldTimestamp != newTimestamp && newTimestamp > 0) {
        contentChanged = true;
      } else {
        // 检查act数量是否变化
        if (oldNovel.acts.length != newNovel.acts.length) {
          contentChanged = true;
        } else {
          // 检查章节和场景数量是否变化
          int oldSceneCount = 0;
          int newSceneCount = 0;
          
          for (int i = 0; i < oldNovel.acts.length; i++) {
            final oldAct = oldNovel.acts[i];
            final newAct = newNovel.acts[i];
            
            // 检查章节数量
            if (oldAct.chapters.length != newAct.chapters.length) {
              contentChanged = true;
              break;
            }
            
            // 检查场景数量
            for (int j = 0; j < oldAct.chapters.length; j++) {
              if (j < newAct.chapters.length) {
                oldSceneCount += oldAct.chapters[j].scenes.length;
                newSceneCount += newAct.chapters[j].scenes.length;
              }
            }
          }
          
          // 如果场景总数变化，内容变化
          if (oldSceneCount != newSceneCount) {
            contentChanged = true;
          }
        }
      }
    }

    // 检查活动元素是否变化
    bool activeElementsChanged = false;
    if (stateChanged && _lastEditorState != null) {
      activeElementsChanged = 
          _lastEditorState!.activeActId != state.activeActId ||
          _lastEditorState!.activeChapterId != state.activeChapterId ||
          _lastEditorState!.activeSceneId != state.activeSceneId;
    }

    // 如果上次检查时间为空，或者距离上次检查已经超过间隔时间，需要检查
    final bool timeIntervalExceeded = _lastControllerCheckTime == null || 
        now.difference(_lastControllerCheckTime!) > _controllerLongCheckInterval;
    
    // 定义仅在必要时重构的条件:
    // 1. 首次加载（_lastControllerCheckTime为null）
    // 2. 内容结构变化（添加/删除场景或章节）
    // 3. 当前正在加载状态（但不是刚从加载完成回到非加载状态，因为这通常是滚动引起的）
    final bool needsRebuild = _lastControllerCheckTime == null || 
                           contentChanged || 
                           activeElementsChanged ||
                           (state.isLoading && (_lastEditorState == null || !_lastEditorState!.isLoading));
    
    // 更新状态引用，用于下次比较
    _lastEditorState = state;
    
    // 如果需要检查，更新最后检查时间
    if (needsRebuild || timeIntervalExceeded) {
      _lastControllerCheckTime = now;
      
      String reason;
      if (needsRebuild) {
        if (contentChanged) {
          reason = "内容结构变化";
        } else if (activeElementsChanged) {
          reason = "活动元素变化";
        } else if (state.isLoading) {
          reason = "加载状态变化";
        } else {
          reason = "首次加载";
        }
      } else {
        reason = "时间间隔超过(${_controllerLongCheckInterval.inSeconds}秒)";
      }
      
      AppLogger.i('Screens/editor/editor_screen', '触发控制器检查 - 原因: $reason');
      return true;
    }
    
    return false;
  }
}

/// 可拖拽的分隔条组件
class _DraggableDivider extends StatefulWidget {
  const _DraggableDivider({
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;

  @override
  State<_DraggableDivider> createState() => _DraggableDividerState();
}

class _DraggableDividerState extends State<_DraggableDivider> {
  bool _isDragging = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (details) {
          setState(() {
            _isDragging = false;
          });
          widget.onDragEnd(details);
        },
        child: Container(
          width: 8,
          height: double.infinity,
          color: _isDragging
              ? theme.colorScheme.primary.withOpacity(0.1)
              : _isHovering
                  ? Colors.grey.shade200
                  : Colors.grey.shade100,
          child: Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: _isDragging
                  ? theme.colorScheme.primary
                  : _isHovering
                      ? Colors.grey.shade400
                      : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }
}

