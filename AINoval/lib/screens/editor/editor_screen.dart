import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ainoval/utils/logger.dart';

import 'package:flutter_quill/flutter_quill.dart' hide EditorState;
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/screens/ai_config/ai_config_management_screen.dart'; // 导入管理屏幕
import 'package:ainoval/config/app_config.dart'; // <<< Import AppConfig
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart'; // <<< Import Repository Interface
import 'package:ainoval/screens/settings/settings_panel.dart'; // <<< Import SettingsPanel
import 'package:ainoval/utils/word_count_analyzer.dart';
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
  bool _isSettingsPanelVisible = false; // <<< 添加状态变量

  // 聊天侧边栏宽度相关状态
  double _chatSidebarWidth = 380; // 默认宽度
  static const double _minChatSidebarWidth = 280; // 最小宽度
  static const double _maxChatSidebarWidth = 500; // 最大宽度
  static const String _chatSidebarWidthPrefKey = 'chat_sidebar_width'; // 持久化键

  String? _currentUserId; // <<< Store userId

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _editorBloc = EditorBloc(
      repository: EditorRepositoryImpl(),
      novelId: widget.novel.id,
    )..add(const LoadEditorContent());

    // 添加监听器确保数据变化时界面更新
    _editorBloc.stream.listen((state) {
      if (state is EditorLoaded && mounted) {
        // 始终更新UI，确保字数统计和同步状态实时反映
        setState(() {});
      }
    });

    _currentUserId = AppConfig.userId;
    if (_currentUserId == null) {
      AppLogger.e(
          'EditorScreen', 'User ID is null. Some features might be limited.');
    }

    // 加载保存的侧边栏宽度
    _loadSavedChatSidebarWidth();
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

    for (final act in novel.acts) {
      AppLogger.d('Screens/editor/editor_screen',
          '检查 Act: ${act.id} (${act.title}). Chapters: ${act.chapters.length}');
      if (act.chapters.isEmpty) {
        AppLogger.w(
            'Screens/editor/editor_screen', 'Act ${act.id} 没有 Chapters。');
        continue;
      }

      for (final chapter in act.chapters) {
        AppLogger.d('Screens/editor/editor_screen',
            '检查 Chapter: ${chapter.id} (${chapter.title}). Scenes: ${chapter.scenes.length}');
        if (chapter.scenes.isEmpty) {
          AppLogger.w('Screens/editor/editor_screen',
              'Chapter ${chapter.id} 没有 Scenes。');
          continue;
        }

        controllersChecked = true;

        for (int i = 0; i < chapter.scenes.length; i++) {
          final scene = chapter.scenes[i];
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';
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
    }

    AppLogger.i('Screens/editor/editor_screen',
        '控制器确保完成。控制器总数: ${_sceneControllers.length}. 是否添加新控制器: $controllersAdded. 是否检查过场景: $controllersChecked.');
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
    final l10n = AppLocalizations.of(context)!;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _editorBloc),
      ],
      child: BlocConsumer<EditorBloc, EditorState>(
        listener: (context, state) {
          if (state is EditorError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is EditorLoaded) {
            _ensureControllersForNovel(state.novel);
          }
        },
        builder: (context, state) {
          if (state is EditorLoaded) {
            _ensureControllersForNovel(state.novel);

            final activeControllerId = state.activeActId != null &&
                    state.activeChapterId != null &&
                    state.activeSceneId != null
                ? '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}'
                : null;

            if (activeControllerId != null &&
                !_sceneControllers.containsKey(activeControllerId)) {
              AppLogger.w('Screens/editor/editor_screen',
                  '活动场景 $activeControllerId 的控制器不存在，但仍尝试构建编辑器UI...');
            }
            return _buildEditorScreen(context, state, l10n);
          } else if (state is EditorSettingsOpen) {
            return _buildSettingsScreen(context, state, l10n);
          } else {
            AppLogger.i('Screens/editor/editor_screen',
                '当前状态: ${state.runtimeType}, 显示加载...');
            return _buildLoadingScreen(l10n);
          }
        },
      ),
    );
  }

  Widget _buildLoadingScreen(AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEditorScreen(
      BuildContext context, EditorLoaded state, AppLocalizations l10n) {
    final fallbackController = _getFallbackController(state);

    // <<< Get userId, provide default or handle error if null >>>
    final userIdForPanel = _currentUserId;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              EditorSidebar(
                novel: widget.novel,
                tabController: _tabController,
                onOpenAIChat: () {
                  setState(() {
                    _isAIChatSidebarVisible = true;
                    _isSettingsPanelVisible = false; // 关闭设置面板
                  });
                },
                onOpenSettings: () {
                  // <<< 添加打开设置的回调
                  setState(() {
                    _isSettingsPanelVisible = true;
                    _isAIChatSidebarVisible = false; // 关闭聊天侧边栏
                  });
                },
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
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
                              // <<< 修改此回调
                              setState(() {
                                _isSettingsPanelVisible =
                                    !_isSettingsPanelVisible;
                                if (_isSettingsPanelVisible) {
                                  _isAIChatSidebarVisible = false; // 打开设置时关闭聊天
                                }
                              });
                            },
                            isSettingsActive:
                                _isSettingsPanelVisible, // <<< 传递设置面板状态
                          ),
                          EditorToolbar(
                            controller: fallbackController,
                          ),
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
                        child: AIChatSidebar(
                          novelId: widget.novel.id,
                          chapterId: state.activeChapterId,
                          onClose: () {
                            setState(() {
                              _isAIChatSidebarVisible = false;
                            });
                          },
                        ),
                      )
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_isSettingsPanelVisible) // <<< Uncomment settings panel
            Positioned.fill(
              child: GestureDetector(
                // Use Positioned.fill and add background overlay
                onTap: () => setState(() => _isSettingsPanelVisible = false),
                child: Container(
                  color: Colors.black.withOpacity(0.5), // Darker overlay
                  child: Center(
                    child: GestureDetector(
                      // Prevent closing when clicking the panel itself
                      onTap: () {},
                      child: userIdForPanel == null
                          ? _buildLoginRequiredPanel(
                              context) // Show message if not logged in
                          : SettingsPanel(
                              // <<< Pass userId and provide BLoC
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
      ),
      floatingActionButton: state.isSaving
          ? FloatingActionButton(
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
            )
          : _isAIChatSidebarVisible
              ? null
              : FloatingActionButton(
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
                ),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(
          width: 8,
          height: double.infinity,
          color: _isDragging
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Colors.grey.withOpacity(0.2),
          child: Center(
            child: Container(
              width: 2,
              height: double.infinity,
              color: _isDragging
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}
