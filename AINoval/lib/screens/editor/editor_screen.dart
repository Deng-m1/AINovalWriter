import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' hide EditorState;
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/screens/editor/widgets/word_count_display.dart';
import 'package:ainoval/screens/editor/widgets/editor_toolbar.dart';
import 'package:ainoval/screens/editor/widgets/editor_settings_panel.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ainoval/screens/chat/chat_screen.dart';
import 'package:ainoval/blocs/chat/chat_bloc.dart';
import 'package:ainoval/screens/chat/widgets/chat_sidebar.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/screens/editor/widgets/editor_sidebar.dart';
import 'package:ainoval/screens/editor/widgets/editor_content_area.dart';

class EditorScreen extends StatefulWidget {
  
  const EditorScreen({
    super.key,
    required this.novel,
  });
  final NovelSummary novel;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
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
  
  // 定义标签页索引常量
  static const int _codexTabIndex = 0;
  static const int _snippetsTabIndex = 1;
  static const int _chatsTabIndex = 2;
  
  // 为每个场景创建单独的控制器
  final Map<String, QuillController> _sceneControllers = {};
  // 当前活动的场景ID
  String? _activeSceneId;
  
  // 添加这些字段来存储控制器引用
  final Map<String, TextEditingController> _sceneTitleControllers = {};
  final Map<String, TextEditingController> _sceneSubtitleControllers = {};
  final Map<String, TextEditingController> _sceneSummaryControllers = {};
  
  @override
  void initState() {
    super.initState();
    // 初始化TabController，3个标签页：Codex、Snippets、Chats
    _tabController = TabController(length: 3, vsync: this);
    
    // 直接加载编辑器内容，不需要等待LocalStorageService初始化
    _editorBloc.add(const LoadEditorContent());
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _debounceTimer?.cancel();
    if (_isControllerInitialized) {
      _controller.dispose();
    }
    // 释放所有场景控制器
    for (final controller in _sceneControllers.values) {
      controller.dispose();
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
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        // 处理状态变化
        if (state.status == EditorStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage)),
          );
        } else if (state.status == EditorStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('内容已保存')),
          );
        }
      },
      builder: (context, state) {
        if (state.status == EditorStatus.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return Scaffold(
          appBar: AppBar(
            title: Text(state.novelTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  context.read<EditorBloc>().add(SaveContent());
                },
                tooltip: '保存',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  _showSettingsDialog(context);
                },
                tooltip: '设置',
              ),
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () {
                  _navigateToChatScreen(context);
                },
                tooltip: 'AI助手',
              ),
            ],
          ),
          drawer: EditorSidebar(
            novel: state.novel,
            currentChapterId: state.currentChapterId,
            onChapterSelected: (chapterId) {
              context.read<EditorBloc>().add(LoadChapter(chapterId: chapterId));
            },
            onAddChapter: () {
              _showAddChapterDialog(context);
            },
          ),
          body: Column(
            children: [
              EditorToolbar(
                onBoldPressed: () => _applyFormatting(context, 'bold'),
                onItalicPressed: () => _applyFormatting(context, 'italic'),
                onUnderlinePressed: () => _applyFormatting(context, 'underline'),
                onAlignLeftPressed: () => _applyFormatting(context, 'alignLeft'),
                onAlignCenterPressed: () => _applyFormatting(context, 'alignCenter'),
                onAlignRightPressed: () => _applyFormatting(context, 'alignRight'),
                onUndoPressed: () {
                  context.read<EditorBloc>().add(UndoEdit());
                },
                onRedoPressed: () {
                  context.read<EditorBloc>().add(RedoEdit());
                },
              ),
              Expanded(
                child: EditorContentArea(
                  controller: _controller,
                  focusNode: _focusNode,
                  isReadOnly: state.status == EditorStatus.loading,
                  onChanged: (text) {
                    if (!_isInitializing) {
                      context.read<EditorBloc>().add(UpdateContent(content: text));
                    }
                  },
                ),
              ),
              _buildStatusBar(context, state),
            ],
          ),
        );
      },
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
  Widget _buildEditorScreen(BuildContext context, EditorLoaded state, AppLocalizations l10n) {
    // 初始化编辑器控制器
    try {
      if (!_isControllerInitialized) {
        _initEditorController(state.novel);
        _isControllerInitialized = true;
      }
    } catch (e) {
      print('初始化编辑器控制器失败: $e');
      // 使用空文档初始化
      if (!_isControllerInitialized) {
        _controller = QuillController(
          document: Document.fromJson(jsonDecode('{"ops":[{"insert":"\\n"}]}')['ops']),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _isControllerInitialized = true;
      }
    }
    
    return Scaffold(
      body: Row(
        children: [
          // 左侧边栏
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              children: [
                // 小说标题
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.book, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.novel.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        onPressed: () {
                          // 打开设置
                        },
                      ),
                    ],
                  ),
                ),
                
                // 标签页导航
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.book_outlined),
                      text: 'Codex',
                    ),
                    Tab(
                      icon: Icon(Icons.snippet_folder_outlined),
                      text: 'Snippets',
                    ),
                    Tab(
                      icon: Icon(Icons.chat_outlined),
                      text: 'Chats',
                    ),
                  ],
                ),
                
                // 标签页内容
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Codex 标签页
                      _buildCodexTab(),
                      
                      // Snippets 标签页
                      _buildSnippetsTab(),
                      
                      // Chats 标签页
                      _buildChatsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 中间编辑器
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 编辑器主体
                Expanded(
                  child: Column(
                    children: [
                      // 顶部工具栏
                      AppBar(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black54),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        title: Row(
                          children: [
                            // 小说标题
                            Text(
                              widget.novel.title,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 小箭头
                            const Icon(Icons.keyboard_arrow_right, size: 16, color: Colors.black54),
                          ],
                        ),
                        actions: [
                          // 顶部导航按钮
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                // Plan 按钮
                                _buildNavButton('Plan', Icons.map_outlined, false, () {}),
                                const SizedBox(width: 8),
                                // Write 按钮 (激活状态)
                                _buildNavButton('Write', Icons.edit_outlined, true, () {}),
                                const SizedBox(width: 8),
                                // Chat 按钮
                                _buildNavButton('Chat', Icons.chat_outlined, false, () {}),
                                const SizedBox(width: 8),
                                // Review 按钮
                                _buildNavButton('Review', Icons.rate_review_outlined, false, () {}),
                              ],
                            ),
                          ),
                          
                          // 字数统计
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${state.novel.wordCount} Words',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${(state.novel.wordCount / 250).ceil()} pages · ${(state.novel.wordCount / 200).ceil()}m read',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // 格式按钮
                          IconButton(
                            icon: const Icon(Icons.text_format, color: Colors.black54),
                            tooltip: '格式',
                            onPressed: () {},
                          ),
                          
                          // 焦点按钮
                          IconButton(
                            icon: const Icon(Icons.center_focus_strong, color: Colors.black54),
                            tooltip: '焦点模式',
                            onPressed: () {},
                          ),
                          
                          // 保存状态指示器
                          if (state.isSaving)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (state.lastSaveTime != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Tooltip(
                                message: l10n.saved,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade300,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      // 编辑器工具栏
                      EditorToolbar(controller: _controller),
                      
                      // 主编辑区
                      Expanded(
                        child: Container(
                          color: Colors.white, // 将背景色改为白色
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Center(
                              child: Container(
                                width: 1100, // 增加宽度以容纳内容和摘要
                                padding: const EdgeInsets.symmetric(horizontal: 40), // 添加水平内边距
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 动态构建Acts
                                    ...state.novel.acts.map((act) => _buildActSection(
                                      act.title,
                                      act.chapters.map((chapter) => _buildChapterSection(
                                        chapter.title,
                                        [_buildSceneSection(
                                          '${chapter.title} · Scene 1',
                                          '${chapter.wordCount} Words',
                                          state.activeChapterId == chapter.id,
                                          actId: act.id,
                                          chapterId: chapter.id,
                                        )],
                                        actId: act.id,
                                        chapterId: chapter.id,
                                      )).toList(),
                                      actId: act.id,
                                    )),
                                    
                                    // 添加新Act按钮
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                                        child: TextButton.icon(
                                          onPressed: () {
                                            // 添加新Act的逻辑
                                          },
                                          icon: const Icon(Icons.add),
                                          label: const Text('New Act'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // 移除保存按钮，改为显示保存状态
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
          : null,
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
  Widget _buildSettingsScreen(BuildContext context, EditorSettingsOpen state, AppLocalizations l10n) {
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
          context.read<EditorBloc>().add(UpdateEditorSettings(settings: newSettings.toMap()));
        },
      ),
    );
  }
  
  // 初始化编辑器控制器
  void _initEditorController(novel_models.Novel novel) {
    // 初始化主控制器（现在仅用于兼容性）
    _controller = QuillController(
      document: Document.fromJson(jsonDecode('{"ops":[{"insert":"\\n"}]}')['ops']),
      selection: const TextSelection.collapsed(offset: 0),
    );
    
    // 初始化场景控制器
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        final sceneId = '${act.id}_${chapter.id}';
        
        if (!_sceneControllers.containsKey(sceneId)) {
          final sceneDocument = _parseDocument(chapter.scene.content);
          _sceneControllers[sceneId] = QuillController(
            document: sceneDocument,
            selection: const TextSelection.collapsed(offset: 0),
          );
          
          // 为场景标题创建控制器
          _sceneTitleControllers[sceneId] = TextEditingController(text: '${chapter.title} · Scene 1');
          
          // 为场景子标题创建控制器
          _sceneSubtitleControllers[sceneId] = TextEditingController(text: '');
          
          // 为场景摘要创建控制器
          _sceneSummaryControllers[sceneId] = TextEditingController(text: chapter.scene.summary.content);
          
          // 添加内容变化监听
          _sceneControllers[sceneId]!.document.changes.listen((_) {
            if (!mounted) return; // 检查组件是否仍然挂载
            
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
              if (!mounted) return; // 再次检查，因为Timer可能在组件卸载后触发
              
              try {
                final jsonStr = jsonEncode(_sceneControllers[sceneId]!.document.toDelta().toJson());
                
                // 更新EditorBloc中的场景内容
                _editorBloc.add(UpdateSceneContent(
                  actId: act.id,
                  chapterId: chapter.id,
                  content: jsonStr,
                ));
                
                // 更新右侧摘要区域的标题
                setState(() {
                  _activeSceneId = sceneId; // 设置当前活动场景
                });
              } catch (e) {
                print('更新内容失败: $e');
              }
            });
          });
        }
      }
    }
    
    // 设置第一个场景为活动场景
    if (novel.acts.isNotEmpty && novel.acts.first.chapters.isNotEmpty) {
      _activeSceneId = '${novel.acts.first.id}_${novel.acts.first.chapters.first.id}';
    }
  }
  
  // 将内容字符串解析为Document
  Document _parseDocument(String content) {
    try {
      // 尝试解析JSON
      final dynamic deltaJson = jsonDecode(content);
      if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
        final ops = deltaJson['ops'];
        if (ops is List) {
          return Document.fromJson(ops);
        } else {
          print('ops 不是列表类型：$ops');
          return Document();
        }
      } else if (deltaJson is List) {
        // 直接是ops数组
        return Document.fromJson(deltaJson);
      } else {
        print('内容格式不正确：$content');
        return Document();
      }
    } catch (e) {
      // 如果解析失败，可能是纯文本格式，创建简单的delta
      print('解析内容失败，使用纯文本格式: $e');
      return Document()..insert(0, content);
    }
  }

  // 添加一个辅助方法来创建导航按钮
  Widget _buildNavButton(String text, IconData icon, bool isActive, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? Colors.white : Colors.black87,
        size: 16,
      ),
      label: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.black87,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.grey.shade800 : Colors.transparent,
        foregroundColor: isActive ? Colors.white : Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  // 构建Act部分
  Widget _buildActSection(String title, List<Widget> chapters, {required String actId}) {
    // 为Act标题创建一个控制器
    final TextEditingController actTitleController = TextEditingController(text: title);
    // 为Act标题添加防抖动计时器
    Timer? _actTitleDebounceTimer;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Act标题 - 修改为居中显示
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 40, 0, 16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 替换为可编辑的文本字段
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: actTitleController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      // 使用防抖动机制，避免频繁更新
                      _actTitleDebounceTimer?.cancel();
                      _actTitleDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          _editorBloc.add(UpdateActTitle(
                            actId: actId,
                            title: value,
                          ));
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {},
                  tooltip: 'Actions',
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
        
        // 章节列表
        ...chapters,
        
        // 添加新章节按钮
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: TextButton.icon(
              onPressed: () {
                // 添加新章节的逻辑
              },
              icon: const Icon(Icons.add),
              label: const Text('New Chapter'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ),
        ),
        
        // Act分隔线
        Container(
          margin: const EdgeInsets.symmetric(vertical: 40),
          height: 1,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }
  
  // 构建Chapter部分
  Widget _buildChapterSection(String title, List<Widget> scenes, {required String actId, required String chapterId}) {
    // 为Chapter标题创建一个控制器
    final TextEditingController chapterTitleController = TextEditingController(text: title);
    // 为Chapter标题添加防抖动计时器
    Timer? _chapterTitleDebounceTimer;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chapter标题
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 40, 0, 16),
          child: Row(
            children: [
              // 替换为可编辑的文本字段
              Expanded(
                child: TextField(
                  controller: chapterTitleController,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    // 使用防抖动机制，避免频繁更新
                    _chapterTitleDebounceTimer?.cancel();
                    _chapterTitleDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        _editorBloc.add(UpdateChapterTitle(
                          actId: actId,
                          chapterId: chapterId,
                          title: value,
                        ));
                      }
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: () {},
                tooltip: 'Actions',
                color: Colors.grey.shade700,
              ),
            ],
          ),
        ),
        
        // 场景列表
        ...scenes,
        
        // 添加新场景按钮
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('New Scene'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 构建Scene部分
  Widget _buildSceneSection(String title, String wordCount, bool isActive, {String? actId, String? chapterId, bool isFirst = true}) {
    // 为每个场景创建唯一的ID
    final sceneId = actId != null && chapterId != null ? '${actId}_$chapterId' : title.replaceAll(' ', '_').toLowerCase();
    
    // 如果该场景还没有控制器，创建一个新的
    if (!_sceneControllers.containsKey(sceneId)) {
      _sceneControllers[sceneId] = QuillController(
        document: Document(),
        selection: const TextSelection.collapsed(offset: 0),
      );
      
      // 为场景标题创建一个控制器
      _sceneTitleControllers[sceneId] = TextEditingController(text: title);
      
      // 为场景子标题创建一个控制器
      _sceneSubtitleControllers[sceneId] = TextEditingController(text: '');
      
      // 为场景摘要创建一个控制器
      _sceneSummaryControllers[sceneId] = TextEditingController(text: '');
    }
    
    // 创建专用于此场景的FocusNode
    final focusNode = FocusNode();
    
    // 判断当前场景是否为活动场景
    final bool isActiveScene = _activeSceneId == sceneId || isActive;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 如果不是第一个场景，添加场景分隔符
        if (!isFirst)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Container(
                width: 40,
                height: 20,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.diamond_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        
        // 场景标题和字数统计
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (wordCount.isNotEmpty)
                Text(
                  wordCount,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        
        // 编辑器和摘要区域并排显示
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 编辑器区域
            Expanded(
              flex: 7, // 占据70%的宽度
              child: GestureDetector(
                onTap: () {
                  // 设置当前活动场景
                  setState(() {
                    _activeSceneId = sceneId;
                  });
                  
                  // 如果有actId和chapterId，设置为活动章节
                  if (actId != null && chapterId != null) {
                    _editorBloc.add(SetActiveChapter(actId: actId, chapterId: chapterId));
                  }
                  
                  // 延迟请求焦点，确保UI更新后再获取焦点
                  Future.microtask(() {
                    if (mounted && focusNode.canRequestFocus) {
                      focusNode.requestFocus();
                    }
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 100, // 设置最小高度
                  ),
                  decoration: BoxDecoration(
                    // 使用背景色而不是边框来指示选中状态
                    color: isActiveScene ? Colors.grey.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: QuillEditor(
                    controller: _sceneControllers[sceneId]!,
                    focusNode: focusNode,
                    scrollController: ScrollController(),
                    configurations: const QuillEditorConfigurations(
                      scrollable: false, // 改为false，不需要内部滚动
                      autoFocus: false, // 不自动获取焦点
                      sharedConfigurations: QuillSharedConfigurations(
                        locale: Locale('zh', 'CN'),
                      ),
                      placeholder: 'Start writing, or type \'/\' for commands...',
                      expands: false,
                      padding: EdgeInsets.all(8),
                      customStyles: DefaultStyles(
                        paragraph: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: 16,
                            fontFamily: 'Serif',
                            height: 1.5,
                            color: Colors.black87,
                          ),
                          HorizontalSpacing(0, 0),
                          VerticalSpacing(0, 0),
                          VerticalSpacing(0, 0),
                          BoxDecoration(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // 摘要区域 - 修改背景色为白色，与创作区保持一致
            Expanded(
              flex: 3, // 占据30%的宽度
              child: Container(
                margin: const EdgeInsets.only(left: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, // 修改为白色背景
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 摘要标题
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 16),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey.shade700,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 摘要内容
                    TextField(
                      controller: _sceneSummaryControllers[sceneId],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      maxLines: null, // 允许无限行
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Add summary...',
                      ),
                      onChanged: (value) {
                        // 使用防抖动机制，避免频繁更新摘要
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                          if (mounted && actId != null && chapterId != null) {
                            _editorBloc.add(UpdateSummary(
                              actId: actId,
                              chapterId: chapterId,
                              summary: value,
                            ));
                          }
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 底部操作按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('刷新'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('AI生成'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        // 底部操作按钮
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Actions'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.label_outline, size: 16),
                label: const Text('Label'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.code, size: 16),
                label: const Text('Codex'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 