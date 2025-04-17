import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/screens/chat/widgets/ai_chat_sidebar.dart';
import 'package:ainoval/screens/editor/components/draggable_divider.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:ainoval/screens/editor/widgets/ai_generation_panel.dart';
import 'package:ainoval/screens/editor/widgets/ai_summary_panel.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 多AI面板视图组件
/// 支持以卡片形式并排显示多个AI辅助面板，可拖拽调整大小
class MultiAIPanelView extends StatefulWidget {
  const MultiAIPanelView({
    Key? key,
    required this.novelId,
    required this.chapterId,
    required this.layoutManager,
  }) : super(key: key);

  final String novelId;
  final String? chapterId;
  final EditorLayoutManager layoutManager;

  @override
  State<MultiAIPanelView> createState() => _MultiAIPanelViewState();
}

class _MultiAIPanelViewState extends State<MultiAIPanelView> {
  @override
  Widget build(BuildContext context) {
    final visiblePanels = widget.layoutManager.visiblePanels;
    
    if (visiblePanels.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: double.infinity,
      child: Row(
        children: [
          // 添加面板之间的拖拽分隔线和面板内容
          for (int i = 0; i < visiblePanels.length; i++) ...[
            if (i > 0) _buildDraggableDivider(visiblePanels[i]),
            _buildPanelContent(visiblePanels[i], i),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDraggableDivider(String panelId) {
    return DraggableDivider(
      onDragUpdate: (details) {
        final delta = details.delta.dx;
        widget.layoutManager.updatePanelWidth(panelId, delta);
      },
      onDragEnd: (_) {
        widget.layoutManager.savePanelWidths();
      },
    );
  }
  
  Widget _buildPanelContent(String panelId, int index) {
    final width = widget.layoutManager.panelWidths[panelId] ?? 
                 EditorLayoutManager.minPanelWidth;
    
    // 使用Material和Card为面板添加卡片风格
    return SizedBox(
      width: width,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5), 
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 面板内容
            _buildPanel(panelId),
            
            // 可拖动的顶部把手
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildDragHandle(panelId, index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(String panelId, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLastPanel = widget.layoutManager.isLastPanel(panelId);
    
    // 面板类型标题映射
    final panelTitles = {
      EditorLayoutManager.aiChatPanel: 'AI聊天',
      EditorLayoutManager.aiSummaryPanel: 'AI摘要',
      EditorLayoutManager.aiScenePanel: 'AI生成',
    };
    
    final panelTitle = panelTitles[panelId] ?? '未知面板';
    
    return GestureDetector(
      onPanStart: (details) {
        // 开始拖动
      },
      onPanUpdate: (details) {
        // 拖动更新位置
      },
      onPanEnd: (details) {
        // 结束拖动，重新排序
      },
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withOpacity(0.7),
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 面板图标和标题
            Row(
              children: [
                Icon(
                  _getPanelIcon(panelId),
                  size: 14,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  panelTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            
            // 拖动和关闭按钮
            Row(
              children: [
                // 拖动手柄图标
                if (widget.layoutManager.visiblePanels.length > 1)
                  Icon(
                    Icons.drag_handle,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  
                // 关闭按钮
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      _closePanel(panelId);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 根据面板类型获取对应图标
  IconData _getPanelIcon(String panelId) {
    switch (panelId) {
      case EditorLayoutManager.aiChatPanel:
        return Icons.chat_outlined;
      case EditorLayoutManager.aiSummaryPanel:
        return Icons.summarize_outlined;
      case EditorLayoutManager.aiScenePanel:
        return Icons.auto_awesome_outlined;
      default:
        return Icons.dashboard_outlined;
    }
  }
  
  // 关闭指定面板
  void _closePanel(String panelId) {
    switch (panelId) {
      case EditorLayoutManager.aiChatPanel:
        widget.layoutManager.toggleAIChatSidebar();
        break;
      case EditorLayoutManager.aiSummaryPanel:
        widget.layoutManager.toggleAISummaryPanel();
        break;
      case EditorLayoutManager.aiScenePanel:
        widget.layoutManager.toggleAISceneGenerationPanel();
        break;
    }
  }
  
  Widget _buildPanel(String panelId) {
    switch (panelId) {
      case EditorLayoutManager.aiChatPanel:
        return _buildAIChatPanel();
      case EditorLayoutManager.aiSummaryPanel:
        return _buildAISummaryPanel();
      case EditorLayoutManager.aiScenePanel:
        return _buildAISceneGenerationPanel();
      default:
        return const Center(child: Text('未知面板类型'));
    }
  }
  
  Widget _buildAIChatPanel() {
    return Padding(
      padding: const EdgeInsets.only(top: 24), // 为顶部拖动把手留出空间
      child: AIChatSidebar(
        novelId: widget.novelId,
        chapterId: widget.chapterId,
        onClose: widget.layoutManager.toggleAIChatSidebar,
        isCardMode: true,
      ),
    );
  }
  
  Widget _buildAISummaryPanel() {
    // 使用现有的PromptRepository Provider
    final promptRepository = context.read<PromptRepository>();
    
    return Padding(
      padding: const EdgeInsets.only(top: 24), // 为顶部拖动把手留出空间
      child: BlocProvider<PromptBloc>(
        create: (context) => PromptBloc(
          promptRepository: promptRepository,
        ),
        child: AISummaryPanel(
          novelId: widget.novelId,
          onClose: widget.layoutManager.toggleAISummaryPanel,
          isCardMode: true,
        ),
      ),
    );
  }
  
  Widget _buildAISceneGenerationPanel() {
    // 使用现有的PromptRepository Provider
    final promptRepository = context.read<PromptRepository>();
    
    return Padding(
      padding: const EdgeInsets.only(top: 24), // 为顶部拖动把手留出空间
      child: BlocProvider<PromptBloc>(
        create: (context) => PromptBloc(
          promptRepository: promptRepository,
        ),
        child: AIGenerationPanel(
          novelId: widget.novelId,
          onClose: widget.layoutManager.toggleAISceneGenerationPanel,
          isCardMode: true,
        ),
      ),
    );
  }
} 