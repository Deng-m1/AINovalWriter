import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/screens/chat/widgets/ai_chat_sidebar.dart';
import 'package:ainoval/screens/editor/components/draggable_divider.dart';
import 'package:ainoval/screens/editor/components/editor_app_bar.dart';
import 'package:ainoval/screens/editor/components/editor_main_area.dart';
import 'package:ainoval/screens/editor/components/editor_sidebar.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

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
            final targetKeyId = '${state.activeActId}_${state.activeChapterId}_${state.activeSceneId}';
            var key = controller.sceneKeys[targetKeyId]; // Try initial lookup

            // Use post-frame callback regardless, to ensure layout is complete
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // --- Re-check key inside post-frame callback ---
              key ??= controller.sceneKeys[targetKeyId]; // If key was null, try looking up again

              if (key != null) {
                // Check context again inside the callback, as it might become null
                if (key!.currentContext != null) { // Use null assertion after check
                  Scrollable.ensureVisible(
                    key!.currentContext!, // Use null assertion
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    alignment: 0.1,
                  );
                }
              }
            });
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

              // 严格限制重建条件，只有这些关键状态变化时才重建
              return prevLoaded.isSaving != currLoaded.isSaving ||
                  prevLoaded.isLoading != currLoaded.isLoading ||
                  prevLoaded.errorMessage != currLoaded.errorMessage ||
                  prevLoaded.activeActId != currLoaded.activeActId ||
                  prevLoaded.activeChapterId != currLoaded.activeChapterId ||
                  prevLoaded.activeSceneId != currLoaded.activeSceneId ||
                  // 小说基本结构变化检查
                  prevLoaded.novel.acts.length != currLoaded.novel.acts.length;
            }

            return true; // 其他情况保守处理，进行重建
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
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
                // 右侧AI生成面板
                if (layoutState.isAISceneGenerationPanelVisible || layoutState.isAISummaryPanelVisible) ...[
                  DraggableDivider(
                    onDragUpdate: (delta) {
                      layoutState.updateChatSidebarWidth(delta.delta.dx);
                    },
                    onDragEnd: (_) {
                      layoutState.saveChatSidebarWidth();
                    },
                  ),
                  SizedBox(
                    width: layoutState.chatSidebarWidth,
                    child: MultiRepositoryProvider(
                      providers: [
                        RepositoryProvider<PromptRepository>(
                          create: (context) => controllerState.promptRepository,
                        ),
                      ],
                      child: BlocProvider<PromptBloc>(
                        create: (context) => PromptBloc(
                          promptRepository: RepositoryProvider.of<PromptRepository>(context),
                        ),
                        child: layoutState.isAISceneGenerationPanelVisible
                          ? AIGenerationPanel(
                              novelId: controllerState.novel.id,
                              onClose: layoutState.toggleAISceneGenerationPanel,
                            )
                          : AISummaryPanel(
                              novelId: controllerState.novel.id,
                              onClose: layoutState.toggleAISummaryPanel,
                            ),
                      ),
                    ),
                  )
                ]
                // 右侧AI聊天面板
                else if (layoutState.isAIChatSidebarVisible) ...[
                  DraggableDivider(
                    onDragUpdate: (delta) {
                      layoutState.updateChatSidebarWidth(delta.delta.dx);
                    },
                    onDragEnd: (_) {
                      layoutState.saveChatSidebarWidth();
                    },
                  ),
                  SizedBox(
                    width: layoutState.chatSidebarWidth,
                    child: BlocBuilder<editor_bloc.EditorBloc, editor_bloc.EditorState>(
                      buildWhen: (previous, current) {
                        // 只在状态类型变化或chapterId变化时重建
                        if (previous.runtimeType != current.runtimeType) {
                          return true;
                        }
                        if (previous is editor_bloc.EditorLoaded && current is editor_bloc.EditorLoaded) {
                          return previous.activeChapterId != current.activeChapterId;
                        }
                        return true;
                      },
                      builder: (context, state) {
                        if (state is editor_bloc.EditorLoaded) {
                          return AIChatSidebar(
                            novelId: controllerState.novel.id,
                            chapterId: state.activeChapterId,
                            onClose: layoutState.toggleAIChatSidebar,
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  )
                ],
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
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            // 浮动按钮
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
          ],
        );
      },
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
