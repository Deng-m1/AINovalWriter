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
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
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
    
    // 监听内容更新通知器
    return ValueListenableBuilder<String>(
      valueListenable: stateManager.contentUpdateNotifier,
      builder: (context, updateValue, child) {
        // 使用BlocBuilder获取当前编辑器状态
        return BlocBuilder<editor_bloc.EditorBloc, editor_bloc.EditorState>(
          builder: (context, state) {
            // 根据状态渲染UI
            if (state is editor_bloc.EditorLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is editor_bloc.EditorLoaded) {
              // 使用节流函数决定是否需要检查控制器
              if (stateManager.shouldCheckControllers(state)) {
                controller.ensureControllersForNovel(state.novel);
              }
              return _buildMainLayout(context, state);
            } else if (state is editor_bloc.EditorError) {
              return Center(child: Text('错误: ${state.message}'));
            } else {
              return const Center(child: Text('未知状态'));
            }
          },
        );
      }
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
                        onWritePressed: (controllerState.isPlanViewActive || controllerState.isNextOutlineViewActive)
                            ? (controllerState.isPlanViewActive ? controllerState.togglePlanView : controllerState.toggleNextOutlineView)
                            : null,
                        onNextOutlinePressed: controllerState.toggleNextOutlineView,
                        onAIGenerationPressed: layoutState.toggleAISceneGenerationPanel,
                        onAISummaryPressed: layoutState.toggleAISummaryPanel,
                        onAutoContinueWritingPressed: onAutoContinueWritingPressed,
                        isAIGenerationActive: layoutState.isAISceneGenerationPanelVisible || layoutState.isAISummaryPanelVisible,
                        isNextOutlineActive: controllerState.isNextOutlineViewActive,
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
                                    : controllerState.isNextOutlineViewActive
                                      ? NextOutlineView(
                                          novelId: controllerState.novel.id,
                                          novelTitle: controllerState.novel.title,
                                          onSwitchToWrite: controllerState.toggleNextOutlineView,
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
            // 添加全屏加载动画覆盖层
            if (controllerState.isFullscreenLoading)
              FullscreenLoadingOverlay(
                loadingMessage: controllerState.loadingMessage,
                showProgressIndicator: true,
                progress: controllerState.loadingProgress >= 0 ? controllerState.loadingProgress : -1,
              ),
          ],
        );
      },
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

  Widget _buildLoadingOverlay(BuildContext context) {
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
                if (controller.isLoadingMore)
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
                
                if (!controller.isLoadingMore) ...[
                  if (controller.hasReachedEnd)
                    _buildEndOfContentIndicator("已到达底部"),
                  if (controller.hasReachedStart)
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
