import 'dart:async';

import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
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
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/foundation.dart';
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
  
  // 性能监控相关
  Timer? _performanceMonitorTimer;
  final Stopwatch _buildStopwatch = Stopwatch();
  int _buildCount = 0;
  int _totalBuildTimeMs = 0;

  // 记录上次加载的时间，用于节流控制
  DateTime? _lastUpLoadTime;
  DateTime? _lastDownLoadTime;
  
  // 自动续写对话框控制
  bool _showContinueWritingForm = false;

  @override
  void initState() {
    super.initState();
    _controller = EditorScreenController(
      novel: widget.novel,
      vsync: this,
    );
    _layoutManager = EditorLayoutManager();
    _stateManager = EditorStateManager();
    
    // 在编辑器初始化时加载所有场景摘要
    _controller.loadAllSceneSummaries();
    
    // 在调试模式下启动性能监控
    if (kDebugMode) {
      _setupPerformanceMonitoring();
    }
    
    // 确保滚动监听器被添加
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 在第一次渲染完成后，确认滚动监听器工作正常
      final ScrollController controller = _controller.scrollController;
      AppLogger.i('EditorScreen', '初始化滚动监听器，当前是否已有监听器: ${controller.hasListeners}');
      
      // 如果滚动监听器没有被添加（防止重复添加），则添加监听器
      if (!controller.hasListeners) {
        controller.addListener(_onScrollWrapper);
        AppLogger.i('EditorScreen', '已添加滚动监听器');
      }
    });
  }
  
  // 滚动监听器包装方法，确保调用到控制器的_onScroll方法
  void _onScrollWrapper() {
    try {
      // 获取ScrollController信息
      final ScrollController controller = _controller.scrollController;
      
      // 如果控制器不可用，直接返回
      if (!controller.hasClients) return;
      
      final offset = controller.offset;
      final maxScroll = controller.position.maxScrollExtent;
      final viewportHeight = controller.position.viewportDimension;
      
      // 获取编辑器状态
      final editorState = _controller.editorBloc.state;
      if (editorState is! editor_bloc.EditorLoaded) {
        return; // 只在编辑器已加载状态处理
      }
      
      // 如果编辑器正在加载，跳过本次检查
      if (editorState.isLoading) {
        AppLogger.d('EditorScreen', '编辑器正在加载，跳过分页检查');
        return;
      }
      
      // 使用视口高度的一定比例作为阈值
      final threshold = viewportHeight * 0.5; // 50%的视口高度
      
      // 检查是否需要加载更多章节场景
      String? fromChapterId;
      String direction = '';
      
      AppLogger.d('EditorScreen', '滚动监测: 当前位置=$offset, 最大位置=$maxScroll, 阈值=$threshold');
      
      if (offset <= threshold) {
        // 接近顶部，向上加载更多
        AppLogger.i('EditorScreen', '检测到接近顶部，尝试向上加载');
        fromChapterId = _findFirstChapterId(editorState.novel);
        if (fromChapterId != null) {
          direction = 'up';
        }
      } else if (maxScroll - offset <= threshold) {
        // 接近底部，向下加载更多
        AppLogger.i('EditorScreen', '检测到接近底部，尝试向下加载');
        fromChapterId = _findLastChapterId(editorState.novel);
        if (fromChapterId != null) {
          direction = 'down';
        }
      }
      
      // 如果找到了章节ID且需要加载，触发加载事件
      if (fromChapterId != null && direction.isNotEmpty) {
        // 防抖控制，避免短时间内多次触发相同方向的加载
        bool shouldLoadMore = true;
        
        // 根据加载方向判断是否需要节流
        if (direction == 'up' && _lastUpLoadTime != null) {
          final timeDiff = DateTime.now().difference(_lastUpLoadTime!).inSeconds;
          shouldLoadMore = timeDiff >= 3; // 至少间隔3秒
          if (!shouldLoadMore) {
            AppLogger.d('EditorScreen', '向上加载频率过高，跳过此次请求 (间隔${timeDiff}秒)');
          }
        } else if (direction == 'down' && _lastDownLoadTime != null) {
          final timeDiff = DateTime.now().difference(_lastDownLoadTime!).inSeconds;
          shouldLoadMore = timeDiff >= 3; // 至少间隔3秒
          if (!shouldLoadMore) {
            AppLogger.d('EditorScreen', '向下加载频率过高，跳过此次请求 (间隔${timeDiff}秒)');
          }
        }
        
        if (shouldLoadMore) {
          AppLogger.i('EditorScreen', '触发${direction=="up"?"向上":"向下"}加载，起始章节: $fromChapterId');
          
          // 记录本次加载时间
          if (direction == 'up') {
            _lastUpLoadTime = DateTime.now();
          } else {
            _lastDownLoadTime = DateTime.now();
          }
          
          _controller.editorBloc.add(editor_bloc.LoadMoreScenes(
            fromChapterId: fromChapterId,
            direction: direction,
            chaptersLimit: 3,
            preventFocusChange: true, // 防止焦点变化
            skipIfLoading: true, // 如果已有加载任务，跳过此次请求
            actId: _findActIdForChapter(fromChapterId), // 添加必需的actId参数
          ));
        }
      }
    } catch (e) {
      AppLogger.e('EditorScreen', '滚动监听器出错', e);
    }
  }
  
  // 辅助方法：查找第一个有场景的章节ID
  String? _findFirstChapterId(novel_models.Novel novel) {
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        if (chapter.scenes.isNotEmpty) {
          return chapter.id;
        }
      }
    }
    
    // 如果没有有场景的章节，返回第一个章节
    if (novel.acts.isNotEmpty && novel.acts.first.chapters.isNotEmpty) {
      return novel.acts.first.chapters.first.id;
    }
    
    return null;
  }
  
  // 辅助方法：查找最后一个有场景的章节ID
  String? _findLastChapterId(novel_models.Novel novel) {
    for (int i = novel.acts.length - 1; i >= 0; i--) {
      final act = novel.acts[i];
      for (int j = act.chapters.length - 1; j >= 0; j--) {
        final chapter = act.chapters[j];
        if (chapter.scenes.isNotEmpty) {
          return chapter.id;
        }
      }
    }
    
    // 如果没有有场景的章节，返回最后一个章节
    if (novel.acts.isNotEmpty && novel.acts.last.chapters.isNotEmpty) {
      return novel.acts.last.chapters.last.id;
    }
    
    return null;
  }
  
  // 辅助方法：查找章节所属的卷ID
  String _findActIdForChapter(String chapterId) {
    final state = _controller.editorBloc.state;
    if (state is editor_bloc.EditorLoaded) {
      // 在当前加载的小说结构中查找章节所属的卷
      for (final act in state.novel.acts) {
        for (final chapter in act.chapters) {
          if (chapter.id == chapterId) {
            return act.id;
          }
        }
      }
      
      // 如果找不到章节所属的卷，返回第一个卷的ID作为fallback
      if (state.novel.acts.isNotEmpty) {
        AppLogger.w('EditorScreen', '未找到章节 $chapterId 所属的卷，默认使用第一个卷');
        return state.novel.acts.first.id;
      }
    }
    
    // 如果状态无效或找不到任何卷，返回一个空字符串作为标记
    AppLogger.e('EditorScreen', '无法确定章节 $chapterId 所属的卷ID，使用空字符串');
    return '';
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
    
    final editorWidget = MultiProvider(
      providers: [
        BlocProvider.value(value: _controller.editorBloc),
        ChangeNotifierProvider.value(value: _controller),
        ChangeNotifierProvider.value(value: _layoutManager),
      ],
      child: BlocListener<editor_bloc.EditorBloc, editor_bloc.EditorState>(
        bloc: _controller.editorBloc,
        listener: (context, state) {
          // 监听状态变化，当加载完成时强制刷新UI
          if (state is editor_bloc.EditorLoaded && !state.isLoading) {
            // 确保是从加载中变为非加载状态
            // 使用微任务确保在当前帧结束后执行
            Future.microtask(() {
              if (mounted) {
                AppLogger.i('EditorScreen', '检测到加载完成，强制刷新UI以显示新章节');
                setState(() {
                  // 这里不需要做任何事情，只是触发重建
                });
                
                // 通知EditorMainArea刷新
                try {
                  final mainAreaState = _controller.editorMainAreaKey.currentState;
                  if (mainAreaState != null) {
                    mainAreaState.setState(() {
                      AppLogger.i('EditorScreen', '通知EditorMainArea刷新UI');
                    });
                  }
                } catch (e) {
                  AppLogger.e('EditorScreen', '尝试刷新EditorMainArea失败', e);
                }
              }
            });
          }
        },
        // 添加listenWhen条件，确保在章节数量变化时也触发刷新
        listenWhen: (previous, current) {
          // 从Loading变为Loaded状态
          if (previous is editor_bloc.EditorLoading && current is editor_bloc.EditorLoaded) {
            return true;
          }
          
          // 检测加载状态变化
          if (previous is editor_bloc.EditorLoaded && current is editor_bloc.EditorLoaded) {
            // 加载状态变化：从加载中变为非加载状态
            if (previous.isLoading && !current.isLoading) {
              return true;
            }
            
            // 章节数量变化
            int previousChapterCount = 0;
            int currentChapterCount = 0;
            
            // 计算前一个状态的总章节数
            for (final act in previous.novel.acts) {
              previousChapterCount += act.chapters.length;
            }
            
            // 计算当前状态的总章节数
            for (final act in current.novel.acts) {
              currentChapterCount += act.chapters.length;
            }
            
            // 检测场景数量变化
            int previousSceneCount = 0;
            int currentSceneCount = 0;
            
            // 计算前一个状态的总场景数
            for (final act in previous.novel.acts) {
              for (final chapter in act.chapters) {
                previousSceneCount += chapter.scenes.length;
              }
            }
            
            // 计算当前状态的总场景数
            for (final act in current.novel.acts) {
              for (final chapter in act.chapters) {
                currentSceneCount += chapter.scenes.length;
              }
            }
            
            // 检测Act数量变化
            if (previous.novel.acts.length != current.novel.acts.length) {
              AppLogger.i('EditorScreen', '检测到Act数量变化: ${previous.novel.acts.length} -> ${current.novel.acts.length}');
              return true;
            }
            
            // 如果章节数量或场景数量有变化，触发刷新
            if (previousChapterCount != currentChapterCount || previousSceneCount != currentSceneCount) {
              AppLogger.i('EditorScreen', '检测到章节或场景数量变化: 章节 $previousChapterCount->$currentChapterCount, 场景 $previousSceneCount->$currentSceneCount');
              return true;
            }
          }
          
          return false;
        },
        child: EditorLayout(
          controller: _controller,
          layoutManager: _layoutManager,
          stateManager: _stateManager,
          onAutoContinueWritingPressed: _showAutoContinueWritingDialog,
        ),
      ),
    );
    
    // 统计构建时间
    if (kDebugMode && _buildStopwatch.isRunning) {
      _buildStopwatch.stop();
      final buildTimeMs = _buildStopwatch.elapsedMilliseconds;
      _buildCount++;
      _totalBuildTimeMs += buildTimeMs;
      
      // 如果构建时间超过16ms（低于60FPS），记录警告
      if (buildTimeMs > 16) {
        AppLogger.w('EditorScreen', '构建时间过长: ${buildTimeMs}ms');
      }
    }
    
    // 最终的布局，包含编辑器和可能的自动续写对话框
    return Scaffold(
      body: Stack(
        children: [
          // 编辑器主体
          editorWidget,
          
          // 自动续写表单对话框
          if (_showContinueWritingForm)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(16),
                child: Material(
                  elevation: 24,
                  borderRadius: BorderRadius.circular(16),
                  child: ContinueWritingForm(
                    novelId: widget.novel.id,
                    userId: AppConfig.userId ?? '',
                    onCancel: _hideAutoContinueWritingDialog,
                    onSubmit: _handleContinueWritingSubmit,
                    userAiModelConfigRepository: context.read<UserAIModelConfigRepository>(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
