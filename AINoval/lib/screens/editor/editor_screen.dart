import 'dart:async';
import 'dart:convert';

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
        // 始终更新UI，确保字数统计和同步状态实时反映
        setState(() {});
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

    for (final act in novel.acts) {
      AppLogger.d('Screens/editor/editor_screen',
          '检查 Act: ${act.id} (${act.title}). Chapters: ${act.chapters.length}');
      
      bool actHasLoadedScenes = false;

      for (final chapter in act.chapters) {
        totalChapterCount++;
        AppLogger.d('Screens/editor/editor_screen',
            '检查 Chapter: ${chapter.id} (${chapter.title}). Scenes: ${chapter.scenes.length}');
        
        // 跳过没有场景的章节，这些章节的场景可能尚未加载或需要按需加载
        if (chapter.scenes.isEmpty) {
          AppLogger.d('Screens/editor/editor_screen',
              'Chapter ${chapter.id} 的场景未加载或没有场景，跳过控制器创建。');
          continue;
        }
        
        // 标记这个章节已加载
        loadedChapterCount++;
        actHasLoadedScenes = true;
        controllersChecked = true;

        for (int i = 0; i < chapter.scenes.length; i++) {
          final scene = chapter.scenes[i];
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';
          
          // 记录有效的场景ID
          validSceneIds.add(sceneId);
          loadedSceneCount++;
          
          AppLogger.v('Screens/editor/editor_screen', '检查 Scene: $sceneId');

          if (!_sceneControllers.containsKey(sceneId)) {
            AppLogger.i(
                'Screens/editor/editor_screen', '检测到新场景或缺失控制器，创建: $sceneId');
            try {
              final contentPreview = scene.content.length > 50
                  ? '${scene.content.substring(0, 50)}...'
                  : scene.content;
              AppLogger.d('Screens/editor/editor_screen',
                  '解析 Scene $sceneId 内容: "$contentPreview"');
              final sceneDocument = _parseDocument(scene.content);

              AppLogger.d('Screens/editor/editor_screen',
                  '设置 Scene $sceneId 摘要: "${scene.summary.content}"');

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
              AppLogger.i('Screens/editor/editor_screen', '成功创建控制器: $sceneId');
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
          } else {
            AppLogger.v('Screens/editor/editor_screen', '控制器已存在: $sceneId');
            final expectedTitle = '${chapter.title} · Scene ${i + 1}';
            if (_sceneTitleControllers[sceneId]?.text != expectedTitle) {
              _sceneTitleControllers[sceneId]?.text = expectedTitle;
            }
            if (_sceneSummaryControllers[sceneId]?.text !=
                scene.summary.content) {
              _sceneSummaryControllers[sceneId]?.text = scene.summary.content;
            }
          }
        }
      }
      
      // 如果这个Act没有任何已加载的场景，记录日志
      if (!actHasLoadedScenes) {
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
                builder: (context, state) {
                  if (state is EditorLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is EditorError) {
                    return Center(child: Text('错误: ${state.message}'));
                  } else if (state is EditorLoaded) {
                    _ensureControllersForNovel(state.novel);
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
                  wordCount: _calculateTotalWordCount(state.novel),
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
    int totalWordCount = 0;

    // 记录日志，帮助调试字数计算
    AppLogger.d('EditorScreen', '开始计算小说总字数');

    // 添加更多详细日志记录
    int actCount = 0;
    int chapterCount = 0;
    int sceneCount = 0;

    for (final act in novel.acts) {
      actCount++;
      int actWordCount = 0;

      for (final chapter in act.chapters) {
        chapterCount++;
        int chapterWordCount = 0;

        for (final scene in chapter.scenes) {
          sceneCount++;

          // 记录每个场景的字数统计数据
          final sceneWordCount = scene.wordCount;
          final calculatedWordCount =
              WordCountAnalyzer.countWords(scene.content);

          AppLogger.d(
              'EditorScreen',
              '场景字数统计: 场景ID=${scene.id}, '
                  '存储的字数=$sceneWordCount, '
                  '计算的字数=$calculatedWordCount, '
                  '内容长度=${scene.content.length}');

          // 总是使用场景的存储字数
          chapterWordCount += sceneWordCount;
          totalWordCount += sceneWordCount;
        }

        AppLogger.d('EditorScreen',
            '章节: ${chapter.title} (ID=${chapter.id}) 总字数: $chapterWordCount');
        actWordCount += chapterWordCount;
      }

      AppLogger.d('EditorScreen',
          'Act: ${act.title} (ID=${act.id}) 总字数: $actWordCount');
    }

    AppLogger.i('EditorScreen',
        '小说总字数计算结果: $totalWordCount (Acts: $actCount, Chapters: $chapterCount, Scenes: $sceneCount)');
    return totalWordCount;
  }

  // 滚动监听函数，用于实现无限滚动加载
  void _onScroll() {
    // 获取当前滚动位置
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // 如果已经滚动到接近底部，加载更多场景
    if (offset >= maxScroll - 500) {
      _loadMoreScenes('down');
    }
    
    // 如果滚动到接近顶部，加载更多场景
    if (offset <= 500) {
      _loadMoreScenes('up');
    }
  }
  
  // 防抖变量，避免频繁触发加载
  DateTime? _lastLoadTime;
  String? _lastDirection;
  String? _lastFromChapterId;
  bool _isLoadingMore = false;

  // 加载更多场景函数
  void _loadMoreScenes(String direction) {
    final state = _editorBloc.state;
    if (state is! EditorLoaded) return;
    
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
    final now = DateTime.now();
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
