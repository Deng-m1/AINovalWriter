import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' hide EditorState;
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/screens/editor/widgets/word_count_display.dart';
import 'package:ainoval/screens/editor/widgets/editor_toolbar.dart';
import 'package:ainoval/screens/editor/widgets/editor_settings_panel.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EditorScreen extends StatefulWidget {
  final NovelSummary novel;
  
  const EditorScreen({
    super.key,
    required this.novel,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late QuillController _controller;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isControllerInitialized = false;
  // 创建一个局部的EditorBloc实例
  late EditorBloc _editorBloc;
  
  @override
  void initState() {
    super.initState();
    // 在initState中初始化EditorBloc
    _editorBloc = EditorBloc(
      repository: EditorRepository(
        apiService: ApiService(),
        localStorageService: LocalStorageService(),
      ),
      novelId: widget.novel.id,
      chapterId: '1', // 第一迭代中使用固定章节ID
    );
    _editorBloc.add(LoadEditorContent());
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (_isControllerInitialized) {
      _controller.dispose();
    }
    _scrollController.dispose();
    _focusNode.dispose();
    _editorBloc.close(); // 关闭Bloc
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return BlocProvider.value(
      value: _editorBloc, // 使用已创建的EditorBloc实例
      child: BlocConsumer<EditorBloc, EditorState>(
        listener: (context, state) {
          if (state is EditorError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
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
  Widget _buildEditorScreen(BuildContext context, EditorLoaded state, AppLocalizations l10n) {
    // 初始化编辑器控制器
    try {
      if (!_isControllerInitialized) {
        _initEditorController(state.content);
        _isControllerInitialized = true;
      }
    } catch (e) {
      print('初始化编辑器控制器失败: $e');
      // 使用空文档初始化
      if (!_isControllerInitialized) {
        _initEditorController(EditorContent(
          id: '1',
          content: '{"ops":[{"insert":"\\n"}]}',
          lastSaved: DateTime.now(),
        ));
        _isControllerInitialized = true;
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
        actions: [
          // 字数统计
          WordCountDisplay(
            controller: _controller,
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
          
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.read<EditorBloc>().add(ToggleEditorSettings());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 编辑器工具栏
          EditorToolbar(controller: _controller),
          
          // 主编辑区
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: QuillEditor(
                controller: _controller,
                scrollController: _scrollController,
                focusNode: _focusNode,
                configurations: QuillEditorConfigurations(
                  scrollable: true,
                  autoFocus: true,
                  sharedConfigurations: QuillSharedConfigurations(
                    locale: const Locale('zh', 'CN'),
                  ),
                  placeholder: l10n.startWriting,
                  expands: true,
                  padding: EdgeInsets.zero,
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      TextStyle(
                        fontSize: state.settings.fontSize,
                        fontFamily: state.settings.fontFamily,
                        height: state.settings.lineSpacing,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      const HorizontalSpacing(0, 0),
                      const VerticalSpacing(0, 0),
                      const VerticalSpacing(0, 0),
                      BoxDecoration(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: state.isDirty
          ? FloatingActionButton(
              onPressed: () {
                context.read<EditorBloc>().add(SaveContent());
              },
              tooltip: l10n.save,
              child: const Icon(Icons.save),
            )
          : null,
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
            context.read<EditorBloc>().add(ToggleEditorSettings());
          },
        ),
      ),
      body: EditorSettingsPanel(
        settings: state.settings,
        onSettingsChanged: (newSettings) {
          context.read<EditorBloc>().add(UpdateEditorSettings(settings: newSettings));
        },
      ),
    );
  }
  
  // 初始化编辑器控制器
  void _initEditorController(EditorContent content) {
    // 解析delta JSON
    final document = _parseDocument(content.content);
    
    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    
    // 添加内容变化监听
    _controller.document.changes.listen((_) {
      if (!mounted) return; // 检查组件是否仍然挂载
      
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return; // 再次检查，因为Timer可能在组件卸载后触发
        
        try {
          final jsonStr = jsonEncode(_controller.document.toDelta().toJson());
          // 使用局部变量_editorBloc而不是通过context获取
          _editorBloc.add(UpdateContent(newContent: jsonStr));
        } catch (e) {
          print('更新内容失败: $e');
        }
      });
    });
  }
  
  // 将内容字符串解析为Document
  Document _parseDocument(String content) {
    try {
      // 尝试解析JSON
      final dynamic deltaJson = jsonDecode(content);
      if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
        return Document.fromJson(deltaJson['ops']);
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
} 