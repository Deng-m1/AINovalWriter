import 'dart:async';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/blocs/sidebar/sidebar_bloc.dart';
import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/screens/editor/components/editor_layout.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:ainoval/screens/editor/managers/editor_state_manager.dart';
import 'package:ainoval/screens/editor/widgets/continue_writing_form.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/blocs/setting/setting_bloc.dart';
import 'package:ainoval/services/api_service/repositories/novel_setting_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/novel_setting_repository_impl.dart';

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
  
  // 性能监控相关
  Timer? _performanceMonitorTimer;
  final Stopwatch _buildStopwatch = Stopwatch();
  int _buildCount = 0;
  int _totalBuildTimeMs = 0;

  
  // 自动续写对话框控制
  bool _showContinueWritingForm = false;

  late final SidebarBloc _sidebarBloc;

  @override
  void initState() {
    super.initState();
    _controller = EditorScreenController(
      novel: widget.novel,
      vsync: this,
    );
    _layoutManager = EditorLayoutManager();
    _stateManager = EditorStateManager();
    
    // 初始化 SidebarBloc
    _sidebarBloc = SidebarBloc(
      editorRepository: _controller.editorRepository,
    );
    
    // 加载小说结构数据
    _sidebarBloc.add(LoadNovelStructure(widget.novel.id));
    
    // 在调试模式下启动性能监控
    if (kDebugMode) {
      _setupPerformanceMonitoring();
    }
  }
  
  // 设置性能监控
  void _setupPerformanceMonitoring() {
    _performanceMonitorTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_buildCount > 0) {
        final avgBuildTime = _totalBuildTimeMs / _buildCount;
        AppLogger.i('EditorScreen', 
          '性能统计: 10秒内构建次数: $_buildCount, 平均构建时间: ${avgBuildTime.toStringAsFixed(2)}ms');
        _buildCount = 0;
        _totalBuildTimeMs = 0;
      }
    });
  }
  
  // 自动续写对话框显示控制
  void _showAutoContinueWritingDialog() {
    setState(() {
      _showContinueWritingForm = true;
    });
  }
  
  // 隐藏自动续写对话框
  void _hideAutoContinueWritingDialog() {
    setState(() {
      _showContinueWritingForm = false;
    });
  }
  
  // 处理自动续写表单提交
  void _handleContinueWritingSubmit(Map<String, dynamic> parameters) async {
    try {
      // 直接使用控制器中的编辑器仓库
      final editorRepository = _controller.editorRepository;
      
      // 提交任务
      final taskId = await editorRepository.submitContinueWritingTask(
        novelId: parameters['novelId'],
        numberOfChapters: parameters['numberOfChapters'],
        aiConfigIdSummary: parameters['aiConfigIdSummary'],
        aiConfigIdContent: parameters['aiConfigIdContent'],
        startContextMode: parameters['startContextMode'],
        contextChapterCount: parameters['contextChapterCount'],
        customContext: parameters['customContext'],
        writingStyle: parameters['writingStyle'],
      );
      
      // 隐藏对话框
      _hideAutoContinueWritingDialog();
      
      // 显示提交成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('自动续写任务已提交，任务ID: $taskId'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('EditorScreen', '提交自动续写任务失败', e);
      
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交自动续写任务失败: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // 释放性能监控资源
    _performanceMonitorTimer?.cancel();
    _buildStopwatch.stop();
    
    // 关闭SidebarBloc
    _sidebarBloc.close();
    
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
    // 在调试模式下监控构建性能
    if (kDebugMode) {
      _buildStopwatch.reset();
      _buildStopwatch.start();
    }
    
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<NovelSettingRepository>(
          create: (context) => NovelSettingRepositoryImpl(
            apiClient: ApiClient(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _controller.editorBloc),
          BlocProvider.value(value: _sidebarBloc),
          ChangeNotifierProvider.value(value: _controller),
          ChangeNotifierProvider.value(value: _layoutManager),
          BlocProvider<SettingBloc>(
            create: (context) => SettingBloc(
              settingRepository: context.read<NovelSettingRepository>(),
            )..add(LoadSettingGroups(widget.novel.id)),
          ),
        ],
        child: EditorLayout(
          controller: _controller,
          layoutManager: _layoutManager,
          stateManager: _stateManager,
          onAutoContinueWritingPressed: _showAutoContinueWritingDialog,
        ),
      ),
    );
  }
}
