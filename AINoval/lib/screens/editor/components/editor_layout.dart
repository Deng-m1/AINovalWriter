import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/screens/editor/components/draggable_divider.dart';
import 'package:ainoval/screens/editor/components/editor_app_bar.dart';
import 'package:ainoval/screens/editor/components/editor_main_area.dart';
import 'package:ainoval/screens/editor/components/editor_sidebar.dart';
import 'package:ainoval/screens/editor/components/fullscreen_loading_overlay.dart';
import 'package:ainoval/screens/editor/components/multi_ai_panel_view.dart';
import 'package:ainoval/screens/editor/components/plan_view.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/screens/editor/managers/editor_dialog_manager.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:ainoval/screens/editor/managers/editor_state_manager.dart';
import 'package:ainoval/screens/editor/widgets/novel_settings_view.dart';
import 'package:ainoval/screens/next_outline/next_outline_view.dart';
import 'package:ainoval/screens/settings/settings_panel.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/aliyun_oss_storage_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/user_ai_model_config_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/foundation.dart';
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
    this.onAutoContinueWritingPressed,
  });

  final EditorScreenController controller;
  final EditorLayoutManager layoutManager;
  final EditorStateManager stateManager;
  final VoidCallback? onAutoContinueWritingPressed;

  @override
  Widget build(BuildContext context) {
    // 清除内存缓存，确保每次build周期都使用新的内存缓存
    stateManager.clearMemoryCache();

    // 监听 EditorScreenController 的状态变化，特别是 isFullscreenLoading
    return ChangeNotifierProvider.value( // Ensure we are listening to the controller provided
      value: controller,
      child: Consumer<EditorScreenController>( // Use Consumer to get the latest controller state
        builder: (context, editorController, _) {
          // 优先显示全屏加载动画
          if (editorController.isFullscreenLoading) {
            return FullscreenLoadingOverlay(
              loadingMessage: editorController.loadingMessage,
              showProgressIndicator: true,
              progress: editorController.loadingProgress >= 0 ? editorController.loadingProgress : -1,
            );
          }

          // 如果全屏加载已结束，则构建主要布局
          return ValueListenableBuilder<String>(
            valueListenable: stateManager.contentUpdateNotifier,
            builder: (context, updateValue, child) {
              // 使用BlocBuilder获取当前编辑器状态
              return BlocBuilder<editor_bloc.EditorBloc, editor_bloc.EditorState>(
                bloc: editorController.editorBloc, // Explicitly use the bloc from the controller
                builder: (context, state) {
                  // 根据状态渲染UI
                  if (state is editor_bloc.EditorLoading) {
                    // 此时 isFullscreenLoading 应该是 false
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is editor_bloc.EditorLoaded) {
                    // 使用节流函数决定是否需要检查控制器
                    if (stateManager.shouldCheckControllers(state)) {
                      editorController.ensureControllersForNovel(state.novel);
                    }
                    return _buildMainLayout(context, state, editorController); // Pass controller
                  } else if (state is editor_bloc.EditorError) {
                    return Center(child: Text('错误: \${state.message}'));
                  } else {
                    // 走到这里意味着 isFullscreenLoading 为 false，且 Bloc 状态未知
                    return const Center(child: Text('未知状态'));
                  }
                },
              );
            }
          );
        },
      ),
    );
  }

  // 构建主布局
  Widget _buildMainLayout(BuildContext context, editor_bloc.EditorLoaded editorBlocState, EditorScreenController editorController) {
    // No longer need Consumer2 here if editorController is passed directly
    final layoutState = Provider.of<EditorLayoutManager>(context); // Can get this if needed

    final hasVisibleAIPanels = layoutState.visiblePanels.isNotEmpty;
    
    // isLoadingMore is true if the bloc state is loading or the controller's isLoadingMore is true
    // but ensure we are not in a full screen loading state already handled outside.
    final isLoadingMore = (editorBlocState.isLoading || editorController.isLoadingMore) && !editorController.isFullscreenLoading;

    return Stack(
      children: [
        Row(
          children: [
            // 左侧导航
            if (layoutState.isEditorSidebarVisible) ...[
              SizedBox(
                width: layoutState.editorSidebarWidth,
                child: EditorSidebar(
                  novel: editorController.novel,
                  tabController: editorController.tabController,
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
                    novelTitle: editorController.novel.title,
                    wordCount: stateManager.calculateTotalWordCount(editorBlocState.novel),
                    isSaving: editorBlocState.isSaving,
                    lastSaveTime: editorBlocState.lastSaveTime,
                    onBackPressed: () => Navigator.pop(context),
                    onChatPressed: layoutState.toggleAIChatSidebar,
                    isChatActive: layoutState.isAIChatSidebarVisible,
                    onAiConfigPressed: layoutState.toggleSettingsPanel,
                    isSettingsActive: layoutState.isSettingsPanelVisible,
                    onPlanPressed: editorController.togglePlanView,
                    isPlanActive: editorController.isPlanViewActive,
                    onWritePressed: (editorController.isPlanViewActive || editorController.isNextOutlineViewActive)
                        ? (editorController.isPlanViewActive ? editorController.togglePlanView : editorController.toggleNextOutlineView)
                        : null,
                    onNextOutlinePressed: editorController.toggleNextOutlineView,
                    onAIGenerationPressed: layoutState.toggleAISceneGenerationPanel,
                    onAISummaryPressed: layoutState.toggleAISummaryPanel,
                    onAutoContinueWritingPressed: layoutState.toggleAIContinueWritingPanel,
                    isAIGenerationActive: layoutState.isAISceneGenerationPanelVisible || layoutState.isAISummaryPanelVisible || layoutState.isAIContinueWritingPanelVisible,
                    isNextOutlineActive: editorController.isNextOutlineViewActive,
                  ),
                  // 主编辑区域与聊天侧边栏
                  Expanded(
                    child: layoutState.isNovelSettingsVisible
                      ? MultiRepositoryProvider(
                          providers: [
                            RepositoryProvider<EditorRepository>(
                              create: (context) => editorController.editorRepository,
                            ),
                            RepositoryProvider<StorageRepository>(
                              create: (context) => AliyunOssStorageRepository(editorController.apiClient),
                            ),
                          ],
                          child: NovelSettingsView(
                            novel: editorController.novel,
                            onSettingsClose: layoutState.toggleNovelSettings,
                          ),
                        )
                      : Row(
                          children: [
                            // 根据当前视图模式选择显示内容
                            Expanded(
                              child: editorController.isPlanViewActive
                                ? PlanView(
                                    novelId: editorController.novel.id,
                                    planBloc: editorController.planBloc,
                                    onSwitchToWrite: editorController.togglePlanView,
                                  )
                                : editorController.isNextOutlineViewActive
                                  ? NextOutlineView(
                                      novelId: editorController.novel.id,
                                      novelTitle: editorController.novel.title,
                                      onSwitchToWrite: editorController.toggleNextOutlineView,
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16, right: 16, bottom: 16),
                                      child: EditorMainArea(
                                        key: editorController.editorMainAreaKey,
                                        novel: editorBlocState.novel,
                                        editorBloc: editorController.editorBloc,
                                        sceneControllers: editorController.sceneControllers,
                                        sceneSummaryControllers:
                                            editorController.sceneSummaryControllers,
                                        activeActId: editorBlocState.activeActId,
                                        activeChapterId: editorBlocState.activeChapterId,
                                        activeSceneId: editorBlocState.activeSceneId,
                                        scrollController: editorController.scrollController,
                                        sceneKeys: editorController.sceneKeys,
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
                                create: (context) => editorController.promptRepository,
                                child: MultiAIPanelView(
                                  novelId: editorController.novel.id,
                                  chapterId: editorBlocState.activeChapterId,
                                  layoutManager: layoutState,
                                  userId: editorController.currentUserId,
                                  userAiModelConfigRepository: UserAIModelConfigRepositoryImpl(apiClient: editorController.apiClient),
                                  onContinueWritingSubmit: (parameters) {
                                    AppLogger.i('EditorLayout', 'Continue Writing Submitted: $parameters');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('自动续写任务已提交: $parameters'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
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
                    child: editorController.currentUserId == null
                        ? EditorDialogManager.buildLoginRequiredPanel(
                            context,
                            layoutState.toggleSettingsPanel,
                          )
                        : SettingsPanel(
                            userId: editorController.currentUserId!,
                            onClose: layoutState.toggleSettingsPanel,
                            editorSettings: EditorSettings.fromMap(editorBlocState.settings),
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
        if (!layoutState.isAIChatSidebarVisible && !editorBlocState.isSaving)
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
        if (editorBlocState.isSaving)
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
        // 加载动画覆盖层 (用于非全屏的 "加载更多")
        if (isLoadingMore) // This condition now implies !editorController.isFullscreenLoading
          _buildLoadingOverlay(context, editorController), // Pass controller
        // 全屏加载动画覆盖层 - 这部分的主要控制已移到顶层 build 方法
        // 如果 EditorLoaded 状态内部也可能触发特定类型的全屏加载，可以保留一个更局部的控制
        // 但为了避免混淆，最好让 EditorScreenController.isFullscreenLoading 统一控制
        // if (editorController.isFullscreenLoading) // Redundant if handled at the top level
        //   FullscreenLoadingOverlay(
        //     loadingMessage: editorController.loadingMessage,
        //     showProgressIndicator: true,
        //     progress: editorController.loadingProgress >= 0 ? editorController.loadingProgress : -1,
        //   ),
      ],
    );
  }

  // 构建加载动画覆盖层
  Widget _buildEndOfContentIndicator(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context, EditorScreenController editorController) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 32.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withAlpha(0),
              Colors.white.withAlpha(204),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (editorController.isLoadingMore) // Use passed controller
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
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
                
                if (!editorController.isLoadingMore) ...[ // Use passed controller
                  if (editorController.hasReachedEnd) // Use passed controller
                    _buildEndOfContentIndicator("已到达底部"),
                  if (editorController.hasReachedStart) // Use passed controller
                    _buildEndOfContentIndicator("已到达顶部"),
                ],
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

  // 提取滚动逻辑到单独的方法中，并使用更平滑的滚动
  void _scrollToActiveSceneIfNeeded(EditorScreenController controller, String targetKeyId) {
    try {
      final editorMainAreaKey = controller.editorMainAreaKey;
      if (editorMainAreaKey.currentState != null) {
        // 使用改进的平滑滚动方法
        editorMainAreaKey.currentState!.scrollToActiveSceneSmooth();
        AppLogger.i('EditorLayout', '使用平滑滚动到活动场景: $targetKeyId');
      } else {
        AppLogger.w('EditorLayout', '无法找到EditorMainArea组件，无法滚动');
      }
    } catch (e) {
      AppLogger.e('EditorLayout', '滚动到活动场景时出错', e);
    }
  }
}
