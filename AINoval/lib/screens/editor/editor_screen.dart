import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/chat/chat_bloc.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/repositories/chat_repository.dart';
import 'package:ainoval/repositories/codex_repository.dart';
import 'package:ainoval/repositories/editor_repository.dart';
import 'package:ainoval/repositories/novel_repository.dart';
import 'package:ainoval/screens/chat/widgets/ai_chat_sidebar.dart';
import 'package:ainoval/screens/chat/widgets/chat_sidebar.dart';
import 'package:ainoval/screens/editor/components/editor_app_bar.dart';
import 'package:ainoval/screens/editor/components/editor_main_area.dart';
// 导入拆分后的组件
import 'package:ainoval/screens/editor/components/editor_sidebar.dart';
import 'package:ainoval/screens/editor/widgets/editor_settings_panel.dart';
import 'package:ainoval/screens/editor/widgets/editor_toolbar.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/context_provider.dart';
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
  late QuillController _controller;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isControllerInitialized = false;
  // 创建一个局部的EditorBloc实例，直接初始化
  late final EditorBloc _editorBloc = EditorBloc(
    repository: EditorRepository(
      apiService: ApiService(),
      localStorageService: LocalStorageService()..init(),
    ),
    novelId: widget.novel.id,
  );

  // 添加TabController来管理顶部标签页
  late TabController _tabController;

  // 为每个场景创建单独的控制器
  final Map<String, QuillController> _sceneControllers = {};
  // 当前活动的场景ID
  String? _activeSceneId;

  // 添加这些字段来存储控制器引用
  final Map<String, TextEditingController> _sceneTitleControllers = {};
  final Map<String, TextEditingController> _sceneSubtitleControllers = {};
  final Map<String, TextEditingController> _sceneSummaryControllers = {};

  // 添加AI聊天侧边栏状态
  bool _isAIChatSidebarVisible = false;

  @override
  void initState() {
    super.initState();
    // 初始化TabController，3个标签页：Codex、Snippets、Chats
    _tabController = TabController(length: 3, vsync: this);

    // 直接加载编辑器内容，不需要等待LocalStorageService初始化
    _editorBloc.add(const LoadEditorContent());

    // 添加状态监听，处理新场景添加的情况
    _editorBloc.stream.listen((state) {
      if (state is EditorLoaded && state.activeSceneId != null) {
        final sceneId =
            '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}';

        // 如果是新场景且控制器不存在，创建新控制器
        if (!_sceneControllers.containsKey(sceneId)) {
          try {
            // 找到对应的场景
            final act = state.novel.getAct(state.activeActId!);
            if (act != null) {
              final chapter = act.getChapter(state.activeChapterId!);
              if (chapter != null) {
                final scene = chapter.scenes.firstWhere(
                  (s) => s.id == state.activeSceneId,
                  orElse: () => chapter.scenes.first,
                );

                // 创建新控制器
                final QuillController controller = QuillController(
                  document: _parseDocument(scene.content),
                  selection: const TextSelection.collapsed(offset: 0),
                );

                _sceneControllers[sceneId] = controller;

                // 创建标题和摘要控制器
                _sceneTitleControllers[sceneId] = TextEditingController(
                    text:
                        '${chapter.title} · Scene ${chapter.scenes.indexOf(scene) + 1}');
                _sceneSubtitleControllers[sceneId] =
                    TextEditingController(text: '');
                _sceneSummaryControllers[sceneId] =
                    TextEditingController(text: scene.summary.content);

                // 更新活动场景ID
                _activeSceneId = sceneId;

                // 添加监听 - 使用安全的监听方式
                _setupDocumentChangeListener(controller, sceneId, state);
              }
            }
          } catch (e) {
            AppLogger.e(
                'Screens/editor/editor_screen', '创建新场景控制器失败: $sceneId', e);
          }
        }
      }
    });
  }

  // 创建一个安全的文档变更监听方法
  void _setupDocumentChangeListener(
      QuillController controller, String sceneId, EditorLoaded state) {
    // 确保控制器和文档准备好
    if (controller.document.changes != null) {
      controller.document.changes.listen((_) {
        if (!mounted) return;

        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;

          try {
            final jsonStr = jsonEncode(controller.document.toDelta().toJson());

            // 更新内容
            _editorBloc.add(UpdateSceneContent(
              novelId: _editorBloc.novelId,
              actId: state.activeActId!,
              chapterId: state.activeChapterId!,
              sceneId: state.activeSceneId!,
              content: jsonStr,
              shouldRebuild: false,
            ));
          } catch (e) {
            AppLogger.e('Screens/editor/editor_screen', '更新内容失败', e);
          }
        });
      }).onError((e) {
        AppLogger.e('Screens/editor/editor_screen', '文档变更监听器错误', e);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounceTimer?.cancel();
    if (_isControllerInitialized) {
      try {
        // 先关闭文档变更监听器，再dispose控制器
        _controller.dispose();
      } catch (e) {
        AppLogger.e('Screens/editor/editor_screen', '关闭主控制器失败', e);
      }
    }
    // 释放所有场景控制器
    for (final controller in _sceneControllers.values) {
      try {
        // 先关闭文档变更监听器，再dispose控制器
        controller.dispose();
      } catch (e) {
        AppLogger.e('Screens/editor/editor_screen', '关闭场景控制器失败', e);
      }
    }
    // 释放所有文本控制器
    for (final controller in _sceneTitleControllers.values) {
      controller.dispose();
    }
    for (final controller in _sceneSubtitleControllers.values) {
      controller.dispose();
    }
    for (final controller in _sceneSummaryControllers.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    _focusNode.dispose();
    _editorBloc.close(); // 关闭Bloc
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 创建共享的服务实例
    final apiService = ApiService();
    final localStorageService = LocalStorageService()..init();
    final webSocketService = WebSocketService();

    // 创建仓库实例
    final novelRepository = NovelRepository(
      apiService: apiService,
      localStorageService: localStorageService,
    );

    // CodexRepository没有构造函数参数
    final codexRepository = CodexRepository();

    // 创建上下文提供者
    final contextProvider = ContextProvider(
      novelRepository: novelRepository,
      codexRepository: codexRepository,
    );

    // 创建ChatRepository实例
    final chatRepository = ChatRepository(
      apiService: apiService,
      localStorageService: localStorageService,
      webSocketService: webSocketService,
    );

    // 创建ChatBloc实例
    final chatBloc = ChatBloc(
      repository: chatRepository,
      contextProvider: contextProvider,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: _editorBloc, // 使用已创建的EditorBloc实例
        ),
        BlocProvider.value(
          value: chatBloc, // 使用已创建的ChatBloc实例
        ),
      ],
      child: BlocConsumer<EditorBloc, EditorState>(
        listener: (context, state) {
          if (state is EditorError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }

          // 当状态为EditorLoaded时，检查是否需要滚动到新添加的元素
          if (state is EditorLoaded && state.lastSaveTime != null) {
            // 获取当前时间和最后保存时间的差值
            final timeDifference =
                DateTime.now().difference(state.lastSaveTime!);

            // 只有在时间差小于1秒的情况下才考虑滚动，避免每次保存都滚动
            if (timeDifference.inSeconds < 1) {
              // 检查是否是新添加的Act
              bool isNewAct = false;
              if (state.novel.acts.isNotEmpty && state.activeActId != null) {
                final act = state.novel.acts.last;
                isNewAct = act.id == state.activeActId && act.chapters.isEmpty;
              }

              // 检查是否是新添加的Chapter
              bool isNewChapter = false;
              String? newChapterId;
              if (state.activeActId != null && state.activeChapterId != null) {
                final act = state.novel.getAct(state.activeActId!);
                if (act != null && act.chapters.isNotEmpty) {
                  final chapter = act.chapters.last;
                  isNewChapter = chapter.id == state.activeChapterId &&
                      chapter.scenes.length <= 1;
                  if (isNewChapter) {
                    newChapterId = chapter.id;
                  }
                }
              }

              // 只有在添加新Act或Chapter时才滚动
              if (isNewAct || isNewChapter) {
                // 延迟执行，确保UI已经构建完成
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted && _scrollController.hasClients) {
                    if (isNewChapter && newChapterId != null) {
                      // 查找新章节的位置
                      final chapterElement = _findChapterElement(newChapterId);
                      if (chapterElement != null) {
                        // 滚动到新章节的中央位置
                        final chapterPosition =
                            _calculateChapterPosition(chapterElement);
                        _scrollController.animateTo(
                          chapterPosition,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );

                        // 请求焦点到新章节的编辑区
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (state.activeActId != null &&
                              newChapterId != null) {
                            _requestFocusToNewChapter(
                                state.activeActId!, newChapterId);
                          }
                        });
                      } else {
                        // 如果找不到章节元素，则滚动到底部
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    } else {
                      // 对于新Act，滚动到底部
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                });
              }
            }
          }
        },
        builder: (context, state) {
          if (state is EditorLoading) {
            return _buildLoadingScreen(l10n);
          } else if (state is EditorLoaded) {
            return _buildEditorScreen(context, state, l10n);
          } else if (state is EditorSettingsOpen) {
            return _buildSettingsScreen(context, state, l10n);
          } else {
            return _buildLoadingScreen(l10n);
          }
        },
      ),
    );
  }

  // 构建加载中页面
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

  // 构建编辑器页面
  Widget _buildEditorScreen(
      BuildContext context, EditorLoaded state, AppLocalizations l10n) {
    // 初始化编辑器控制器
    try {
      // 每次状态更新时都重新初始化控制器，以确保新添加的Act、Chapter和Scene能够正确显示
      _initEditorController(state.novel);
      _isControllerInitialized = true;
    } catch (e) {
      AppLogger.e('Screens/editor/editor_screen', '初始化编辑器控制器失败', e);
      // 使用空文档初始化
      if (!_isControllerInitialized) {
        _controller = QuillController(
          document: Document.fromJson(
              jsonDecode('{"ops":[{"insert":"\\n"}]}')['ops']),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _isControllerInitialized = true;
      }
    }

    // 如果有活动章节，确保对应的控制器已经初始化
    if (state.activeActId != null && state.activeChapterId != null) {
      final act = state.novel.getAct(state.activeActId!);
      if (act != null) {
        final chapter = act.getChapter(state.activeChapterId!);
        if (chapter != null && chapter.scenes.isNotEmpty) {
          // 查找当前活动场景
          Scene? scene;
          if (state.activeSceneId != null) {
            scene = chapter.scenes.firstWhere(
              (s) => s.id == state.activeSceneId,
              orElse: () => chapter.scenes.first,
            );
          } else {
            scene = chapter.scenes.first;
          }

          // 为每个场景创建控制器
          for (int i = 0; i < chapter.scenes.length; i++) {
            final currentScene = chapter.scenes[i];
            final sceneId =
                '${state.activeActId}_${state.activeChapterId}_${currentScene.id}';

            if (!_sceneControllers.containsKey(sceneId)) {
              try {
                final sceneDocument = _parseDocument(currentScene.content);
                _sceneControllers[sceneId] = QuillController(
                  document: sceneDocument,
                  selection: const TextSelection.collapsed(offset: 0),
                );

                // 为场景标题创建控制器
                _sceneTitleControllers[sceneId] = TextEditingController(
                    text: '${chapter.title} · Scene ${i + 1}');

                // 为场景子标题创建控制器
                _sceneSubtitleControllers[sceneId] =
                    TextEditingController(text: '');

                // 为场景摘要创建控制器
                _sceneSummaryControllers[sceneId] =
                    TextEditingController(text: currentScene.summary.content);

                // 添加内容变化监听，使用异步处理并增加错误处理
                _sceneControllers[sceneId]!.document.changes.listen(
                  (_) {
                    if (!mounted) return; // 检查组件是否仍然挂载

                    _debounceTimer?.cancel();
                    _debounceTimer =
                        Timer(const Duration(milliseconds: 500), () {
                      if (!mounted) return; // 再次检查，因为Timer可能在组件卸载后触发

                      try {
                        // 先检查控制器是否还有效
                        if (_sceneControllers.containsKey(sceneId) &&
                            _sceneControllers[sceneId] != null) {
                          final jsonStr = jsonEncode(_sceneControllers[sceneId]!
                              .document
                              .toDelta()
                              .toJson());

                          // 保存当前的选择位置
                          final currentSelection =
                              _sceneControllers[sceneId]!.selection;

                          // 更新EditorBloc中的场景内容，但不触发UI重建
                          _editorBloc.add(UpdateSceneContent(
                            novelId: _editorBloc.state is EditorLoaded
                                ? (_editorBloc.state as EditorLoaded).novel.id
                                : widget.novel.id,
                            actId: state.activeActId!,
                            chapterId: state.activeChapterId!,
                            sceneId: currentScene.id,
                            content: jsonStr,
                            shouldRebuild: false, // 添加标志，指示不需要重建UI
                          ));
                        }
                      } catch (e) {
                        AppLogger.e(
                            'Screens/editor/editor_screen', '更新内容失败: $e', e);
                      }
                    });
                  },
                  onError: (error) {
                    AppLogger.e(
                        'Screens/editor/editor_screen', '文档变化监听器错误: $error');
                  },
                );
              } catch (e) {
                AppLogger.e('Screens/editor/editor_screen',
                    '初始化场景控制器失败, sceneId: $sceneId', e);
              }
            }
          }

          // 设置活动场景ID
          if (state.activeSceneId != null) {
            _activeSceneId =
                '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}';
          } else {
            _activeSceneId =
                '${state.activeActId}_${state.activeChapterId}_${scene.id}';
          }
        }
      }

      // 为兼容性保留旧的sceneId格式
      final legacySceneId = '${state.activeActId}_${state.activeChapterId}';
      if (!_sceneControllers.containsKey(legacySceneId)) {
        // 如果控制器不存在，尝试重新初始化
        try {
          // 查找对应的Act和Chapter
          final act = state.novel.getAct(state.activeActId!);
          if (act != null) {
            final chapter = act.getChapter(state.activeChapterId!);
            if (chapter != null && chapter.scenes.isNotEmpty) {
              // 查找当前活动场景
              Scene? scene;
              if (state.activeSceneId != null) {
                scene = chapter.scenes.firstWhere(
                  (s) => s.id == state.activeSceneId,
                  orElse: () => chapter.scenes.first,
                );
              } else {
                scene = chapter.scenes.first;
              }

              final sceneDocument = _parseDocument(scene.content);
              _sceneControllers[legacySceneId] = QuillController(
                document: sceneDocument,
                selection: const TextSelection.collapsed(offset: 0),
              );

              // 为场景标题创建控制器
              _sceneTitleControllers[legacySceneId] =
                  TextEditingController(text: '${chapter.title} · Scene 1');

              // 为场景子标题创建控制器
              _sceneSubtitleControllers[legacySceneId] =
                  TextEditingController(text: '');

              // 为场景摘要创建控制器
              _sceneSummaryControllers[legacySceneId] =
                  TextEditingController(text: scene.summary.content);

              // 设置为活动场景
              _activeSceneId = legacySceneId;
            }
          }
        } catch (e) {
          AppLogger.e('Screens/editor/editor_screen', '初始化活动场景控制器失败', e);
        }
      } else {
        // 设置为活动场景
        _activeSceneId = legacySceneId;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // 左侧边栏 - 使用拆分后的组件
              EditorSidebar(
                novel: widget.novel,
                tabController: _tabController,
                onOpenAIChat: () {
                  AppLogger.i('Screens/editor/editor_screen',
                      'Opening AI chat from sidebar');
                  setState(() {
                    _isAIChatSidebarVisible = true;
                  });
                },
              ),

              // 中间编辑器
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部工具栏 - 使用拆分后的组件
                    EditorAppBar(
                      novelTitle: widget.novel.title,
                      wordCount: state.novel.wordCount,
                      isSaving: state.isSaving,
                      lastSaveTime: state.lastSaveTime,
                      onBackPressed: () => Navigator.pop(context),
                      onChatPressed: () {
                        AppLogger.i('Screens/editor/editor_screen',
                            'Chat button pressed, toggling sidebar visibility');
                        setState(() {
                          _isAIChatSidebarVisible = !_isAIChatSidebarVisible;
                        });
                      },
                      isChatActive: _isAIChatSidebarVisible,
                    ),

                    // 编辑器工具栏
                    EditorToolbar(controller: _controller),

                    // 主编辑区 - 使用拆分后的组件
                    Expanded(
                      child: EditorMainArea(
                        novel: state.novel,
                        editorBloc: _editorBloc,
                        sceneControllers: _sceneControllers,
                        sceneSummaryControllers: _sceneSummaryControllers,
                        activeActId: state.activeActId,
                        activeChapterId: state.activeChapterId,
                        scrollController: _scrollController,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 右侧AI聊天侧边栏
          if (_isAIChatSidebarVisible)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AIChatSidebar(
                novelId: widget.novel.id,
                chapterId: state.activeChapterId,
                onClose: () {
                  AppLogger.i('Screens/editor/editor_screen',
                      'Closing AI chat sidebar');
                  setState(() {
                    _isAIChatSidebarVisible = false;
                  });
                },
              ),
            ),
        ],
      ),
      // 浮动按钮
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
              ? null // 当聊天侧边栏打开时不显示浮动按钮
              : FloatingActionButton(
                  heroTag: 'chat',
                  onPressed: () {
                    AppLogger.i('Screens/editor/editor_screen',
                        'Chat floating button pressed');
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

  // 构建Codex标签页
  Widget _buildCodexTab() {
    return Column(
      children: [
        // 搜索框
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

        // 空状态提示
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

  // 构建Snippets标签页
  Widget _buildSnippetsTab() {
    return const Center(
      child: Text('Snippets功能将在未来版本中推出'),
    );
  }

  // 构建Chats标签页
  Widget _buildChatsTab() {
    return ChatSidebar(
      novelId: widget.novel.id,
    );
  }

  // 构建设置页面
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

  // 初始化编辑器控制器
  void _initEditorController(novel_models.Novel novel) {
    // 初始化主控制器（现在仅用于兼容性）
    _controller = QuillController(
      document:
          Document.fromJson(jsonDecode('{"ops":[{"insert":"\\n"}]}')['ops']),
      selection: const TextSelection.collapsed(offset: 0),
    );

    // 保留所有现有控制器的内容映射
    final Map<String, Document> existingDocuments = {};
    for (final entry in _sceneControllers.entries) {
      try {
        existingDocuments[entry.key] = entry.value.document;
      } catch (e) {
        AppLogger.e(
            'Screens/editor/editor_screen', '保存现有文档失败: ${entry.key}', e);
      }
    }

    // 取消所有现有监听器，然后安全地清除旧的控制器
    for (final controller in _sceneControllers.values) {
      try {
        // 尝试关闭文档变更监听器
        controller.dispose();
      } catch (e) {
        AppLogger.e('Screens/editor/editor_screen', '关闭控制器失败', e);
      }
    }
    _sceneControllers.clear();

    // 清理其他控制器
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

    // 初始化场景控制器
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        // 为每个场景创建控制器
        for (int i = 0; i < chapter.scenes.length; i++) {
          final scene = chapter.scenes[i];
          final sceneId = '${act.id}_${chapter.id}_${scene.id}';

          Document sceneDocument;

          // 优先使用现有的文档（如果存在）
          if (existingDocuments.containsKey(sceneId)) {
            sceneDocument = existingDocuments[sceneId]!;
          } else {
            // 否则从场景内容解析
            sceneDocument = _parseDocument(scene.content);
          }

          _sceneControllers[sceneId] = QuillController(
            document: sceneDocument,
            selection: const TextSelection.collapsed(offset: 0),
          );

          // 为场景标题创建控制器
          _sceneTitleControllers[sceneId] =
              TextEditingController(text: '${chapter.title} · Scene ${i + 1}');

          // 为场景子标题创建控制器
          _sceneSubtitleControllers[sceneId] = TextEditingController(text: '');

          // 为场景摘要创建控制器
          _sceneSummaryControllers[sceneId] =
              TextEditingController(text: scene.summary.content);

          // 添加内容变化监听，使用弱引用StreamSubscription并进行异常处理
          _sceneControllers[sceneId]!.document.changes.listen(
            (_) {
              if (!mounted) return; // 检查组件是否仍然挂载

              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                if (!mounted) return; // 再次检查，因为Timer可能在组件卸载后触发

                try {
                  // 先检查控制器是否还有效
                  if (_sceneControllers.containsKey(sceneId) &&
                      _sceneControllers[sceneId] != null) {
                    final jsonStr = jsonEncode(_sceneControllers[sceneId]!
                        .document
                        .toDelta()
                        .toJson());

                    // 更新EditorBloc中的场景内容，但不触发UI重建
                    _editorBloc.add(UpdateSceneContent(
                      novelId: _editorBloc.state is EditorLoaded
                          ? (_editorBloc.state as EditorLoaded).novel.id
                          : widget.novel.id,
                      actId: act.id,
                      chapterId: chapter.id,
                      sceneId: scene.id,
                      content: jsonStr,
                      shouldRebuild: false, // 添加标志，指示不需要重建UI
                    ));
                  }
                } catch (e) {
                  AppLogger.e('Screens/editor/editor_screen', '更新内容失败: $e', e);
                }
              });
            },
            onError: (error) {
              AppLogger.e('Screens/editor/editor_screen', '文档变化监听器错误: $error');
            },
          );
        }

        // 为兼容性保留旧的sceneId格式
        final legacySceneId = '${act.id}_${chapter.id}';
        if (!_sceneControllers.containsKey(legacySceneId) &&
            chapter.scenes.isNotEmpty) {
          // 使用第一个场景的内容
          final scene = chapter.scenes.first;

          Document sceneDocument;
          // 优先使用现有的文档（如果存在）
          if (existingDocuments.containsKey(legacySceneId)) {
            sceneDocument = existingDocuments[legacySceneId]!;
          } else {
            // 否则从场景内容解析
            sceneDocument = _parseDocument(scene.content);
          }

          _sceneControllers[legacySceneId] = QuillController(
            document: sceneDocument,
            selection: const TextSelection.collapsed(offset: 0),
          );

          // 为场景标题创建控制器
          _sceneTitleControllers[legacySceneId] =
              TextEditingController(text: '${chapter.title} · Scene 1');

          // 为场景子标题创建控制器
          _sceneSubtitleControllers[legacySceneId] =
              TextEditingController(text: '');

          // 为场景摘要创建控制器
          _sceneSummaryControllers[legacySceneId] =
              TextEditingController(text: scene.summary.content);
        }
      }
    }

    // 设置活动场景
    if (novel.acts.isNotEmpty) {
      // 如果有活动章节，则设置为活动场景
      final state = _editorBloc.state;
      if (state is EditorLoaded &&
          state.activeActId != null &&
          state.activeChapterId != null) {
        final act = novel.getAct(state.activeActId!);
        if (act != null) {
          final chapter = act.getChapter(state.activeChapterId!);
          if (chapter != null && chapter.scenes.isNotEmpty) {
            // 如果有活动场景ID，使用它
            if (state.activeSceneId != null) {
              _activeSceneId =
                  '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}';
            } else {
              // 否则使用第一个场景
              final scene = chapter.scenes.first;
              _activeSceneId =
                  '${state.activeActId}_${state.activeChapterId}_${scene.id}';

              // 更新活动场景ID
              _editorBloc.add(SetActiveScene(
                  actId: state.activeActId!,
                  chapterId: state.activeChapterId!,
                  sceneId: scene.id));
            }
          } else {
            _activeSceneId = '${state.activeActId}_${state.activeChapterId}';
          }
        }
      } else if (novel.acts.first.chapters.isNotEmpty) {
        // 否则设置第一个场景为活动场景
        final firstChapter = novel.acts.first.chapters.first;
        if (firstChapter.scenes.isNotEmpty) {
          final firstScene = firstChapter.scenes.first;
          _activeSceneId =
              '${novel.acts.first.id}_${firstChapter.id}_${firstScene.id}';

          // 更新活动章节和场景
          _editorBloc.add(SetActiveChapter(
              actId: novel.acts.first.id, chapterId: firstChapter.id));

          _editorBloc.add(SetActiveScene(
              actId: novel.acts.first.id,
              chapterId: firstChapter.id,
              sceneId: firstScene.id));
        } else {
          _activeSceneId = '${novel.acts.first.id}_${firstChapter.id}';

          // 更新活动章节
          _editorBloc.add(SetActiveChapter(
              actId: novel.acts.first.id, chapterId: firstChapter.id));
        }
      }
    }
  }

  // 解析文档内容的方法
  Document _parseDocument(String content) {
    try {
      // 尝试解析JSON
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
        // 直接是ops数组
        return Document.fromJson(deltaJson);
      } else {
        AppLogger.i('Screens/editor/editor_screen', '内容格式不正确：$content');
        return Document.fromJson([
          {'insert': '\n'}
        ]);
      }
    } catch (e) {
      // 如果解析失败，创建空文档
      AppLogger.e('Screens/editor/editor_screen', '解析内容失败，使用空文档', e);
      return Document.fromJson([
        {'insert': '\n'}
      ]);
    }
  }

  // 查找章节元素
  RenderObject? _findChapterElement(String chapterId) {
    try {
      // 在状态保存和恢复时，使用替代方法查找元素
      // 由于ValueKey不能像GlobalKey那样直接获取context，
      // 我们改为在布局完成后通过位置计算来确定滚动位置
      final firstChapter = _editorBloc.state is EditorLoaded
          ? (_editorBloc.state as EditorLoaded).novel.acts.isNotEmpty
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
        // 使用估算的位置，这样虽然没那么精确，但能避免使用GlobalKey
        return null; // 将导致滚动到默认位置（底部）
      }
      return null;
    } catch (e) {
      AppLogger.e('Screens/editor/editor_screen', '查找章节元素失败', e);
      return null;
    }
  }

  // 计算章节位置，使其在视图中央
  double _calculateChapterPosition(RenderObject chapterElement) {
    try {
      // 获取章节在视图中的位置
      final RenderBox renderBox = chapterElement as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);

      // 计算章节的中心位置
      final chapterCenter = position.dy + (renderBox.size.height / 2);

      // 计算视图的中心位置
      final viewportHeight = _scrollController.position.viewportDimension;
      final viewportCenter = viewportHeight / 2;

      // 计算需要滚动的位置，使章节中心与视图中心对齐
      return _scrollController.offset + (chapterCenter - viewportCenter);
    } catch (e) {
      AppLogger.e('Screens/editor/editor_screen', '计算章节位置失败', e);
      return _scrollController.position.maxScrollExtent;
    }
  }

  // 请求焦点到新章节的编辑区
  void _requestFocusToNewChapter(String actId, String chapterId) {
    try {
      // 简化焦点请求逻辑，不再尝试使用key查找
      // 在EditorBloc中通过状态更新触发场景的焦点请求
      AppLogger.i('Screens/editor/editor_screen',
          '已设置活动章节: actId=$actId, chapterId=$chapterId');

      // 延迟一帧后，再次触发活动章节设置，这样会让对应组件主动请求焦点
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
