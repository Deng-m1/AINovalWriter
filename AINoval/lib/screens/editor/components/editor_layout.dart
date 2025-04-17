import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/screens/chat/widgets/ai_chat_sidebar.dart';
import 'package:ainoval/screens/editor/components/draggable_divider.dart';
import 'package:ainoval/screens/editor/components/editor_app_bar.dart';
import 'package:ainoval/screens/editor/components/editor_main_area.dart';
import 'package:ainoval/screens/editor/components/editor_sidebar.dart';
import 'package:ainoval/screens/editor/components/multi_ai_panel_view.dart';
import 'package:ainoval/screens/editor/components/plan_view.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/screens/editor/managers/editor_dialog_manager.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:ainoval/screens/editor/managers/editor_state_manager.dart';
import 'package:ainoval/screens/editor/widgets/ai_generation_panel.dart';
import 'package:ainoval/screens/editor/widgets/ai_summary_panel.dart';
import 'package:ainoval/screens/editor/widgets/novel_settings_view.dart';
import 'package:ainoval/screens/settings/settings_panel.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/aliyun_oss_storage_repository.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/models/editor_settings.dart';

/// 编辑器布局组件
/// 负责组织编辑器的整体布局
class EditorLayout extends StatelessWidget {
  const EditorLayout({
    super.key,
    required this.controller,
    required this.layoutManager,
    required this.stateManager,
  });

  final EditorScreenController controller;
  final EditorLayoutManager layoutManager;
  final EditorStateManager stateManager;

  @override
  Widget build(BuildContext context) {
    // 清除内存缓存，确保每次build周期都使用新的内存缓存
    stateManager.clearMemoryCache();

    return Scaffold(
      body: BlocListener<editor_bloc.EditorBloc, editor_bloc.EditorState>(
        listener: (context, state) {
          if (state is editor_bloc.EditorLoaded && state.activeSceneId != null) {
            // 智能判断是否需要滚动
            final targetKeyId = '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}';
            final key = controller.sceneKeys[targetKeyId];
            
            // 记录当前激活的场景ID
            final lastActiveSceneId = controller.lastActiveSceneId;
            final currentActiveSceneId = targetKeyId;
            
            // 只有在以下情况才滚动:
            // 1. 场景ID发生变化（用户手动选择了新场景，而非仅触发焦点变化）
            // 2. 当前焦点不在任何编辑器中
            // 这样可以避免干扰用户正在输入的场景
            bool shouldScroll = false;
            bool isUserInitiated = lastActiveSceneId != currentActiveSceneId;
            bool noEditorHasFocus = !FocusScope.of(context).hasPrimaryFocus;
            
            // 更新控制器中记录的最后活动场景
            controller.lastActiveSceneId = currentActiveSceneId;
            
            // 检查当前场景是否在视图中
            bool isSceneVisible = false;
            if (key?.currentContext != null) {
              // 获取场景组件的位置和尺寸
              final RenderBox renderBox = key!.currentContext!.findRenderObject() as RenderBox;
              final position = renderBox.localToGlobal(Offset.zero);
              
              // 获取视口尺寸
              final viewportHeight = MediaQuery.of(context).size.height;
              
              // 判断场景是否在视图内（或部分在视图内）
              isSceneVisible = position.dy < viewportHeight && 
                              position.dy + renderBox.size.height > 0;
            }
            
            // 只有在场景不可见 且 满足滚动条件时才滚动
            shouldScroll = !isSceneVisible && (isUserInitiated || noEditorHasFocus);
            
            // 记录滚动决策日志
            AppLogger.d('EditorLayout', '活动场景滚动决策: 场景=$targetKeyId, 是否滚动=$shouldScroll, 用户发起=${isUserInitiated}, 无焦点=${noEditorHasFocus}, 可见=${isSceneVisible}');
            
            // 执行滚动操作
            if (shouldScroll) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // 等待布局完成后，通过GlobalKey查找EditorMainArea组件
                try {
                  final editorMainAreaKey = controller.editorMainAreaKey;
                  if (editorMainAreaKey?.currentState != null) {
                    // 调用EditorMainArea的scrollToActiveScene方法滚动到活动场景
                    editorMainAreaKey!.currentState!.scrollToActiveScene();
                    AppLogger.i('EditorLayout', '触发滚动到活动场景: $targetKeyId');
                  } else {
                    AppLogger.w('EditorLayout', '无法找到EditorMainArea组件，无法滚动');
                  }
                } catch (e) {
                  AppLogger.e('EditorLayout', '滚动到活动场景时出错', e);
                }
              });
            }
          }
          
          if (state is editor_bloc.EditorLoaded) {
            // 当生成状态开始或内容更新时，确保流式显示面板打开
            if (state.isStreamingGeneration && 
                state.aiSceneGenerationStatus == editor_bloc.AIGenerationStatus.generating) {
              final layoutManager = Provider.of<EditorLayoutManager>(context, listen: false);
              if (!layoutManager.isAISceneGenerationPanelVisible) {
                AppLogger.i('EditorLayout', '检测到流式生成状态，自动打开AI生成面板');
                layoutManager.toggleAISceneGenerationPanel();
              }
            }
          }
        },
        // Listen only when activeSceneId might have changed meaningfully
        listenWhen: (previous, current) {
          if (previous is editor_bloc.EditorLoaded && current is editor_bloc.EditorLoaded) {
            // Only trigger if activeSceneId actually changes *and* is not null
            return previous.activeSceneId != current.activeSceneId &&
                   current.activeSceneId != null;
          }
          // Trigger if transitioning into EditorLoaded with an activeSceneId
          if (current is editor_bloc.EditorLoaded && current.activeSceneId != null) {
             return true;
          }
          if (previous is editor_bloc.EditorLoaded && current is editor_bloc.EditorLoaded) {
            // 当生成状态变化或内容有更新时触发
            return previous.isStreamingGeneration != current.isStreamingGeneration ||
                   previous.aiSceneGenerationStatus != current.aiSceneGenerationStatus ||
                   previous.generatedSceneContent != current.generatedSceneContent;
          }
          return false;
        },
        child: BlocBuilder<editor_bloc.EditorBloc, editor_bloc.EditorState>(
          buildWhen: (previous, current) {
            // 只在状态类型变化或数据结构真正变化时重建UI
            if (previous.runtimeType != current.runtimeType) {
              return true; // 状态类型变化时重建
            }

            // 如果都是EditorLoaded状态，做深度比较
            if (previous is editor_bloc.EditorLoaded && current is editor_bloc.EditorLoaded) {
              final editor_bloc.EditorLoaded prevLoaded = previous;
              final editor_bloc.EditorLoaded currLoaded = current;

              // 先检查时间戳，如果相同且非零，大概率内容相同
              final prevTimestamp = prevLoaded.novel.updatedAt.millisecondsSinceEpoch;
              final currTimestamp = currLoaded.novel.updatedAt.millisecondsSinceEpoch;

              // 如果时间戳都不为0但不同，内容肯定变化了
              if (prevTimestamp != currTimestamp &&
                  prevTimestamp > 0 && currTimestamp > 0) {
                return true;
              }

              // 计算总章节数和场景数
              int prevTotalChapters = 0;
              int currTotalChapters = 0;
              int prevTotalScenes = 0;
              int currTotalScenes = 0;
              
              // 计算前一个状态的总章节数和场景数
              for (final act in prevLoaded.novel.acts) {
                prevTotalChapters += act.chapters.length;
                for (final chapter in act.chapters) {
                  prevTotalScenes += chapter.scenes.length;
                }
              }
              
              // 计算当前状态的总章节数和场景数
              for (final act in currLoaded.novel.acts) {
                currTotalChapters += act.chapters.length;
                for (final chapter in act.chapters) {
                  currTotalScenes += chapter.scenes.length;
                }
              }
              
              // 如果章节数量或场景数量有变化，触发重建
              final structureChanged = prevTotalChapters != currTotalChapters || 
                                     prevTotalScenes != currTotalScenes;
                                     
              if (structureChanged) {
                AppLogger.i('EditorLayout', '检测到章节或场景数量变化: 章节 $prevTotalChapters->$currTotalChapters, 场景 $prevTotalScenes->$currTotalScenes');
              }

              // 严格限制重建条件，只有这些关键状态变化时才重建
              final shouldRebuild = structureChanged ||
                  prevLoaded.isSaving != currLoaded.isSaving ||
                  prevLoaded.isLoading != currLoaded.isLoading ||
                  prevLoaded.errorMessage != currLoaded.errorMessage ||
                  prevLoaded.activeActId != currLoaded.activeActId ||
                  prevLoaded.activeChapterId != currLoaded.activeChapterId ||
                  prevLoaded.activeSceneId != currLoaded.activeSceneId ||
                  // 小说基本结构变化检查
                  prevLoaded.novel.acts.length != currLoaded.novel.acts.length;
              
              // 如果需要重建，记录原因以助调试
              if (shouldRebuild && kDebugMode) {
                String reason = '';
                if (structureChanged) reason = '章节或场景数量变化';
                else if (prevLoaded.isSaving != currLoaded.isSaving) reason = '保存状态变化';
                else if (prevLoaded.isLoading != currLoaded.isLoading) reason = '加载状态变化';
                else if (prevLoaded.activeActId != currLoaded.activeActId) reason = '活动Act变化';
                else if (prevLoaded.activeChapterId != currLoaded.activeChapterId) reason = '活动Chapter变化';
                else if (prevLoaded.activeSceneId != currLoaded.activeSceneId) reason = '活动Scene变化';
                else if (prevLoaded.novel.acts.length != currLoaded.novel.acts.length) reason = 'Acts数量变化';
                
                // 使用更低级别的日志记录重建原因，减少日志输出
                if (prevLoaded.isLoading != currLoaded.isLoading) {
                  // 加载状态变化较常见，可以常规记录
                  AppLogger.d('EditorLayout', '重建UI，原因: $reason');
                } else {
                  // 其他变化仅在调试模式下记录
                  AppLogger.d('EditorLayout', '重建UI，原因: $reason');
                }
              }
              
              return shouldRebuild;
            }

            return false; // 默认不重建，减少不必要的UI刷新
          },
          builder: (context, state) {
            if (state is editor_bloc.EditorLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is editor_bloc.EditorError) {
              return Center(child: Text('错误: ${state.message}'));
            } else if (state is editor_bloc.EditorLoaded) {
              // 使用节流函数决定是否需要检查控制器
              if (stateManager.shouldCheckControllers(state)) {
                controller.ensureControllersForNovel(state.novel);
              }
              return _buildMainLayout(context, state);
            } else {
              return const Center(child: Text('未知状态'));
            }
          },
        ),
      ),
    );
  }

  // 构建主布局
  Widget _buildMainLayout(BuildContext context, editor_bloc.EditorLoaded state) {
    return Consumer2<EditorLayoutManager, EditorScreenController>(
      builder: (context, layoutState, controllerState, child) {
        final hasVisibleAIPanels = layoutState.visiblePanels.isNotEmpty;
        final isLoadingMore = state.isLoading || controllerState.isLoadingMore;
        
        return Stack(
          children: [
            Row(
              children: [
                // 左侧导航
                if (layoutState.isEditorSidebarVisible) ...[
                  SizedBox(
                    width: layoutState.editorSidebarWidth,
                    child: EditorSidebar(
                      novel: controllerState.novel,
                      tabController: controllerState.tabController,
                      onOpenAIChat: () {
                        layoutState.toggleAIChatSidebar();
                      },
                      onOpenSettings: layoutState.toggleNovelSettings,
                      onToggleSidebar: layoutState.toggleEditorSidebar,
                      onAdjustWidth: () => _showEditorSidebarWidthDialog(context),
                    ),
                  ),
                  DraggableDivider(
                    onDragUpdate: (delta) {
                      layoutState.updateEditorSidebarWidth(delta.delta.dx);
                    },
                    onDragEnd: (_) {
                      layoutState.saveEditorSidebarWidth();
                    },
                  ),
                ],
                // 主编辑区域
                Expanded(
                  child: Column(
                    children: [
                      // 编辑器顶部工具栏和操作栏
                      EditorAppBar(
                        novelTitle: controllerState.novel.title,
                        wordCount: stateManager.calculateTotalWordCount(state.novel),
                        isSaving: state.isSaving,
                        lastSaveTime: state.lastSaveTime,
                        onBackPressed: () => Navigator.pop(context),
                        onChatPressed: layoutState.toggleAIChatSidebar,
                        isChatActive: layoutState.isAIChatSidebarVisible,
                        onAiConfigPressed: layoutState.toggleSettingsPanel,
                        isSettingsActive: layoutState.isSettingsPanelVisible,
                        onPlanPressed: controllerState.togglePlanView,
                        isPlanActive: controllerState.isPlanViewActive,
                        onWritePressed: controllerState.isPlanViewActive ? controllerState.togglePlanView : null,
                        onAIGenerationPressed: layoutState.toggleAISceneGenerationPanel,
                        onAISummaryPressed: layoutState.toggleAISummaryPanel,
                        isAIGenerationActive: layoutState.isAISceneGenerationPanelVisible || layoutState.isAISummaryPanelVisible,
                      ),
                      // 主编辑区域与聊天侧边栏
                      Expanded(
                        child: layoutState.isNovelSettingsVisible
                          ? MultiRepositoryProvider(
                              providers: [
                                RepositoryProvider<EditorRepository>(
                                  create: (context) => controllerState.editorRepository,
                                ),
                                RepositoryProvider<StorageRepository>(
                                  create: (context) => AliyunOssStorageRepository(controllerState.apiClient),
                                ),
                              ],
                              child: NovelSettingsView(
                                novel: controllerState.novel,
                                onSettingsClose: layoutState.toggleNovelSettings,
                              ),
                            )
                          : Row(
                              children: [
                                // 根据当前视图模式选择显示内容
                                Expanded(
                                  child: controllerState.isPlanViewActive
                                    ? PlanView(
                                        novelId: controllerState.novel.id,
                                        planBloc: controllerState.planBloc,
                                        onSwitchToWrite: controllerState.togglePlanView,
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                            left: 16, right: 16, bottom: 16),
                                        child: EditorMainArea(
                                          key: controllerState.editorMainAreaKey,
                                          novel: state.novel,
                                          editorBloc: controllerState.editorBloc,
                                          sceneControllers: controllerState.sceneControllers,
                                          sceneSummaryControllers:
                                              controllerState.sceneSummaryControllers,
                                          activeActId: state.activeActId,
                                          activeChapterId: state.activeChapterId,
                                          activeSceneId: state.activeSceneId,
                                          scrollController: controllerState.scrollController,
                                          sceneKeys: controllerState.sceneKeys,
                                        ),
                                      ),
                                ),
                                
                                // 右侧多AI面板组件
                                if (hasVisibleAIPanels) ...[
                                  DraggableDivider(
                                    onDragUpdate: (delta) {
                                      // 更新最左侧面板的宽度，这里影响主编辑区域和面板的边界
                                      final firstPanelId = layoutState.visiblePanels.first;
                                      layoutState.updatePanelWidth(firstPanelId, delta.delta.dx);
                                    },
                                    onDragEnd: (_) {
                                      layoutState.savePanelWidths();
                                    },
                                  ),
                                  // 使用多面板组件
                                  RepositoryProvider<PromptRepository>(
                                    create: (context) => controllerState.promptRepository,
                                    child: MultiAIPanelView(
                                      novelId: controllerState.novel.id,
                                      chapterId: state.activeChapterId,
                                      layoutManager: layoutState,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 侧边栏切换按钮
            if (!layoutState.isEditorSidebarVisible)
              Positioned(
                left: 0,
                top: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: layoutState.toggleEditorSidebar,
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
                            .withAlpha(25),
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
            // 设置面板
            if (layoutState.isSettingsPanelVisible)
              Positioned.fill(
                child: GestureDetector(
                  onTap: layoutState.toggleSettingsPanel,
                  child: Container(
                    color: Colors.black.withAlpha(128),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: controllerState.currentUserId == null
                            ? EditorDialogManager.buildLoginRequiredPanel(
                                context,
                                layoutState.toggleSettingsPanel,
                              )
                            : SettingsPanel(
                                userId: controllerState.currentUserId!,
                                onClose: layoutState.toggleSettingsPanel,
                                editorSettings: EditorSettings.fromMap(state.settings),
                                onEditorSettingsChanged: (settings) {
                                  context.read<editor_bloc.EditorBloc>().add(
                                      editor_bloc.UpdateEditorSettings(settings: settings.toMap()));
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            // 浮动按钮 - 当没有AI聊天面板时显示
            if (!layoutState.isAIChatSidebarVisible && !state.isSaving)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  heroTag: 'chat',
                  onPressed: layoutState.toggleAIChatSidebar,
                  backgroundColor: Colors.grey.shade700,
                  tooltip: '打开AI聊天',
                  child: const Icon(
                    Icons.chat,
                    color: Colors.white,
                  ),
                ),
              ),
            // 保存中浮动按钮
            if (state.isSaving)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
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
                ),
              ),
            // 加载动画覆盖层
            if (isLoadingMore)
              _buildLoadingOverlay(context),
          ],
        );
      },
    );
  }

  // 构建加载动画覆盖层
  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 32.0),
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.8),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '正在加载更多内容...',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 显示编辑器侧边栏宽度调整对话框
  void _showEditorSidebarWidthDialog(BuildContext context) {
    final layoutState = Provider.of<EditorLayoutManager>(context, listen: false);
    EditorDialogManager.showEditorSidebarWidthDialog(
      context,
      layoutState.editorSidebarWidth,
      EditorLayoutManager.minEditorSidebarWidth,
      EditorLayoutManager.maxEditorSidebarWidth,
      (value) {
        layoutState.editorSidebarWidth = value;
      },
      layoutState.saveEditorSidebarWidth,
    );
  }
}
