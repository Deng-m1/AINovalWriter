import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/components/editor_layout.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:ainoval/screens/editor/managers/editor_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

/// 编辑器屏幕
/// 使用设计模式重构后的编辑器屏幕，将功能拆分为多个组件
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
  late final EditorScreenController _controller;
  late final EditorLayoutManager _layoutManager;
  late final EditorStateManager _stateManager;

  @override
  void initState() {
    super.initState();
    _controller = EditorScreenController(
      novel: widget.novel,
      vsync: this,
    );
    _layoutManager = EditorLayoutManager();
    _stateManager = EditorStateManager();
  }

  @override
  void dispose() {
    // 尝试同步当前小说数据
    _controller.syncCurrentNovel();

    // 通知小说列表页面刷新数据
    _controller.notifyNovelListRefresh(context);

    // 释放控制器资源
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider.value(value: _controller.editorBloc),
        ChangeNotifierProvider.value(value: _controller),
        ChangeNotifierProvider.value(value: _layoutManager),
      ],
      child: EditorLayout(
        controller: _controller,
        layoutManager: _layoutManager,
        stateManager: _stateManager,
      ),
    );
  }
}
