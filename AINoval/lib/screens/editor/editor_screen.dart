import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/chat/chat_bloc.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/services/context_provider.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/chat_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/novel_repository_impl.dart';
import 'package:ainoval/screens/chat/widgets/ai_chat_sidebar.dart';
import 'package:ainoval/screens/chat/widgets/chat_sidebar.dart';
import 'package:ainoval/screens/editor/components/editor_app_bar.dart';
import 'package:ainoval/screens/editor/components/editor_main_area.dart';
// 导入拆分后的组件
import 'package:ainoval/screens/editor/components/editor_sidebar.dart';
import 'package:ainoval/screens/editor/widgets/editor_settings_panel.dart';
import 'package:ainoval/screens/editor/widgets/editor_toolbar.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ainoval/utils/logger.dart';

import 'package:flutter_quill/flutter_quill.dart' hide EditorState;

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
  late final EditorBloc _editorBloc = EditorBloc(
    repository: EditorRepositoryImpl(),
    novelId: widget.novel.id,
  );

  late TabController _tabController;

  final Map<String, QuillController> _sceneControllers = {};

  final Map<String, TextEditingController> _sceneTitleControllers = {};
  final Map<String, TextEditingController> _sceneSubtitleControllers = {};
  final Map<String, TextEditingController> _sceneSummaryControllers = {};

  bool _isAIChatSidebarVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _editorBloc.add(const LoadEditorContent());
  }

  void _initializeAllControllers(novel_models.Novel novel) {
    AppLogger.i('Screens/editor/editor_screen', '初始化所有控制器');
    _clearAllControllers();
    _createControllersForNovel(novel);
    if (mounted) {
       setState(() {});
    }
  }

  void _ensureControllersForNovel(novel_models.Novel novel) {
    AppLogger.i('Screens/editor/editor_screen', '确保控制器存在于小说: ${novel.id}. Acts: ${novel.acts.length}');
    bool controllersAdded = false;
    bool controllersChecked = false;

    if (novel.acts.isEmpty) {
        AppLogger.w('Screens/editor/editor_screen', '小说 ${novel.id} 没有 Acts，无法创建控制器。');
        if (_sceneControllers.isNotEmpty) {
             AppLogger.w('Screens/editor/editor_screen', '小说没有 Acts，但存在旧控制器，清理中...');
             _clearAllControllers();
        }
        return;
    }

    for (final act in novel.acts) {
      AppLogger.d('Screens/editor/editor_screen', '检查 Act: ${act.id} (${act.title}). Chapters: ${act.chapters.length}');
      if (act.chapters.isEmpty) {
          AppLogger.w('Screens/editor/editor_screen', 'Act ${act.id} 没有 Chapters。');
          continue;
      }

      for (final chapter in act.chapters) {
        AppLogger.d('Screens/editor/editor_screen', '检查 Chapter: ${chapter.id} (${chapter.title}). Scenes: ${chapter.scenes.length}');
        if (chapter.scenes.isEmpty) {
            AppLogger.w('Screens/editor/editor_screen', 'Chapter ${chapter.id} 没有 Scenes。');
            continue;
        }

        controllersChecked = true;

        for (int i = 0; i < chapter.scenes.length; i++) {
          final scene = chapter.scenes[i];
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';
          AppLogger.v('Screens/editor/editor_screen', '检查 Scene: $sceneId');

          if (!_sceneControllers.containsKey(sceneId)) {
            AppLogger.i('Screens/editor/editor_screen', '检测到新场景或缺失控制器，创建: $sceneId');
            try {
              final contentPreview = scene.content.length > 50 ? '${scene.content.substring(0, 50)}...' : scene.content;
              AppLogger.d('Screens/editor/editor_screen', '解析 Scene $sceneId 内容: "$contentPreview"');
              final sceneDocument = _parseDocument(scene.content);

              AppLogger.d('Screens/editor/editor_screen', '设置 Scene $sceneId 摘要: "${scene.summary.content}"');

              _sceneControllers[sceneId] = QuillController(
                document: sceneDocument,
                selection: const TextSelection.collapsed(offset: 0),
              );
              _sceneTitleControllers[sceneId] = TextEditingController(text: '${chapter.title} · Scene ${i + 1}');
              _sceneSubtitleControllers[sceneId] = TextEditingController(text: '');
              _sceneSummaryControllers[sceneId] = TextEditingController(text: scene.summary.content);
              controllersAdded = true;
              AppLogger.i('Screens/editor/editor_screen', '成功创建控制器: $sceneId');
            } catch (e, stackTrace) {
               AppLogger.e('Screens/editor/editor_screen', '创建新场景控制器失败: $sceneId', e, stackTrace);
               _sceneControllers[sceneId] = QuillController.basic();
               _sceneTitleControllers[sceneId] = TextEditingController(text: '加载错误');
               _sceneSubtitleControllers[sceneId] = TextEditingController();
               _sceneSummaryControllers[sceneId] = TextEditingController(text: '错误: $e');
            }
          } else {
             AppLogger.v('Screens/editor/editor_screen', '控制器已存在: $sceneId');
             final expectedTitle = '${chapter.title} · Scene ${i + 1}';
             if (_sceneTitleControllers[sceneId]?.text != expectedTitle) {
               _sceneTitleControllers[sceneId]?.text = expectedTitle;
             }
             if (_sceneSummaryControllers[sceneId]?.text != scene.summary.content) {
                _sceneSummaryControllers[sceneId]?.text = scene.summary.content;
             }
          }
        }
      }
    }

    AppLogger.i('Screens/editor/editor_screen', '控制器确保完成。控制器总数: ${_sceneControllers.length}. 是否添加新控制器: $controllersAdded. 是否检查过场景: $controllersChecked.');
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
              _sceneTitleControllers[sceneId] = TextEditingController(text: '${chapter.title} · Scene ${i + 1}');
              _sceneSubtitleControllers[sceneId] = TextEditingController(text: '');
              _sceneSummaryControllers[sceneId] = TextEditingController(text: scene.summary.content);
               AppLogger.d('Screens/editor/editor_screen', '已创建控制器: $sceneId');
            } catch (e) {
              AppLogger.e('Screens/editor/editor_screen', '创建场景控制器失败: $sceneId', e);
              _sceneControllers[sceneId] = QuillController.basic();
              _sceneTitleControllers[sceneId] = TextEditingController(text: '错误');
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

    final novelRepository = NovelRepositoryImpl();

    final contextProvider = ContextProvider(
      novelRepository: novelRepository,
      codexRepository: CodexRepository(),
    );

    final chatRepository = ChatRepositoryImpl();

    final chatBloc = ChatBloc(
      repository: chatRepository,
      contextProvider: contextProvider,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: _editorBloc,
        ),
        BlocProvider.value(
          value: chatBloc,
        ),
      ],
      child: BlocConsumer<EditorBloc, EditorState>(
        listener: (context, state) {
          if (state is EditorError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is EditorLoaded) {
            _ensureControllersForNovel(state.novel);
            final activeControllerId = state.activeActId != null && state.activeChapterId != null && state.activeSceneId != null
                ? '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}'
                : null;
            if (state.novel.acts.isNotEmpty && _sceneControllers.isEmpty) {
               AppLogger.w('Screens/editor/editor_screen', 'EditorLoaded 状态，但控制器列表为空，显示加载...');
               return _buildLoadingScreen(l10n);
            }
            else if (activeControllerId != null && !_sceneControllers.containsKey(activeControllerId)) {
               AppLogger.w('Screens/editor/editor_screen', '活动场景 $activeControllerId 的控制器不存在，显示加载...');
               return _buildLoadingScreen(l10n);
            }
            return _buildEditorScreen(context, state, l10n);
          } else if (state is EditorSettingsOpen) {
            return _buildSettingsScreen(context, state, l10n);
          } else {
            AppLogger.i('Screens/editor/editor_screen', '当前状态: ${state.runtimeType}, 显示加载...');
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

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              EditorSidebar(
                novel: widget.novel,
                tabController: _tabController,
                onOpenAIChat: () {
                  setState(() { _isAIChatSidebarVisible = true; });
                },
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EditorAppBar(
                      novelTitle: widget.novel.title,
                      wordCount: state.novel.wordCount,
                      isSaving: state.isSaving,
                      lastSaveTime: state.lastSaveTime,
                      onBackPressed: () => Navigator.pop(context),
                      onChatPressed: () {
                        setState(() { _isAIChatSidebarVisible = !_isAIChatSidebarVisible; });
                      },
                      isChatActive: _isAIChatSidebarVisible,
                    ),

                    EditorToolbar(
                      controller: fallbackController,
                    ),

                    Expanded(
                      child: EditorMainArea(
                        novel: state.novel,
                        editorBloc: _editorBloc,
                        sceneControllers: _sceneControllers,
                        sceneSummaryControllers: _sceneSummaryControllers,
                        activeActId: state.activeActId,
                        activeChapterId: state.activeChapterId,
                        activeSceneId: state.activeSceneId,
                        scrollController: _scrollController,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_isAIChatSidebarVisible)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AIChatSidebar(
                novelId: widget.novel.id,
                chapterId: state.activeChapterId,
                onClose: () {
                  setState(() { _isAIChatSidebarVisible = false; });
                },
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

  QuillController _getFallbackController(EditorLoaded state) {
    if (state.activeActId != null && state.activeChapterId != null && state.activeSceneId != null) {
      final activeControllerId = '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}';
      if (_sceneControllers.containsKey(activeControllerId)) {
        AppLogger.d('Screens/editor/editor_screen', '获取活动控制器: $activeControllerId');
        return _sceneControllers[activeControllerId]!;
      } else {
         AppLogger.w('Screens/editor/editor_screen', '活动控制器 $activeControllerId 未找到!');
      }
    }
    if (_sceneControllers.isNotEmpty) {
      AppLogger.w('Screens/editor/editor_screen', '返回第一个可用控制器: ${_sceneControllers.keys.first}');
      return _sceneControllers.values.first;
    }
    AppLogger.e('Screens/editor/editor_screen', '没有可用的控制器，返回基础控制器');
    return QuillController.basic();
  }

  Widget _buildCodexTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索条目...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),

        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Codex为空',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Codex存储有关您的故事世界的信息',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('创建新条目'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnippetsTab() {
    return const Center(
      child: Text('Snippets功能将在未来版本中推出'),
    );
  }

  Widget _buildChatsTab() {
    return ChatSidebar(
      novelId: widget.novel.id,
    );
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
      return Document.fromJson([{'insert': '\n'}]);
    }
    try {
      final dynamic deltaJson = jsonDecode(content);
      if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
        final ops = deltaJson['ops'];
        if (ops is List) {
          return Document.fromJson(ops);
        } else {
          AppLogger.i('Screens/editor/editor_screen', 'ops 不是列表类型：$ops');
          return Document.fromJson([{'insert': '\n'}]);
        }
      } else if (deltaJson is List) {
        return Document.fromJson(deltaJson);
      } else {
        AppLogger.w('Screens/editor/editor_screen', '内容格式不正确或非预期JSON: $content');
        return Document.fromJson([{'insert': '\n'}]);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Screens/editor/editor_screen', '解析内容失败，使用空文档', e, stackTrace);
      return Document.fromJson([{'insert': '\n'}]);
    }
  }

  RenderObject? _findChapterElement(String chapterId) {
    try {
      final firstChapter = _editorBloc.state is EditorLoaded
          ? (_editorBloc.state as EditorLoaded)
                  .novel
                  .acts
                  .isNotEmpty
              ? (_editorBloc.state as EditorLoaded)
                      .novel
                      .acts
                      .first
                      .chapters
                      .isNotEmpty
                  ? (_editorBloc.state as EditorLoaded)
                      .novel
                      .acts
                      .first
                      .chapters
                      .first
                  : null
              : null
          : null;

      if (firstChapter != null) {
        return null;
      }
      return null;
    } catch (e) {
      AppLogger.e('Screens/editor/editor_screen', '查找章节元素失败', e);
      return null;
    }
  }

  double _calculateChapterPosition(RenderObject chapterElement) {
    try {
      final RenderBox renderBox = chapterElement as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);

      final chapterCenter = position.dy + (renderBox.size.height / 2);

      final viewportHeight = _scrollController.position.viewportDimension;
      final viewportCenter = viewportHeight / 2;

      return _scrollController.offset + (chapterCenter - viewportCenter);
    } catch (e) {
      AppLogger.e('Screens/editor/editor_screen', '计算章节位置失败', e);
      return _scrollController.position.maxScrollExtent;
    }
  }

  void _requestFocusToNewChapter(String actId, String chapterId) {
    try {
      AppLogger.i('Screens/editor/editor_screen',
          '已设置活动章节: actId=$actId, chapterId=$chapterId');

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _editorBloc.add(SetActiveChapter(
            actId: actId,
            chapterId: chapterId,
          ));
        }
      });
    } catch (e) {
      AppLogger.e('Screens/editor/editor_screen', '请求焦点到新章节失败', e);
    }
  }
}
