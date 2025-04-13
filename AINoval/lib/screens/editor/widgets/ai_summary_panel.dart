import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// AI摘要面板，提供场景摘要生成功能
class AISummaryPanel extends StatefulWidget {
  const AISummaryPanel({
    Key? key,
    required this.novelId,
    required this.onClose,
  }) : super(key: key);

  final String novelId;
  final VoidCallback onClose;

  @override
  State<AISummaryPanel> createState() => _AISummaryPanelState();
}

class _AISummaryPanelState extends State<AISummaryPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _userScrolled = false;

  @override
  void initState() {
    super.initState();
    // 加载提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
    
    // 监听滚动事件，检测用户是否主动滚动
    _scrollController.addListener(_handleUserScroll);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_handleUserScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _handleUserScroll() {
    if (_scrollController.hasClients) {
      // 如果用户向上滚动（滚动位置不在底部），标记为用户滚动
      if (_scrollController.position.pixels < 
          _scrollController.position.maxScrollExtent - 50) {
        _userScrolled = true;
      }
      
      // 如果用户滚动到底部，重置标记
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 10) {
        _userScrolled = false;
      }
    }
  }
  
  /// 复制内容到剪贴板
  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('摘要已复制到剪贴板')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, editorState) {
        if (editorState is! EditorLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // 面板标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AI摘要助手',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                    onPressed: widget.onClose,
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),

            // 面板内容
            Expanded(
              child: _buildSceneToSummaryPanel(context, editorState),
            ),
          ],
        );
      },
    );
  }

  // 构建场景生成摘要面板
  Widget _buildSceneToSummaryPanel(BuildContext context, EditorLoaded state) {
    final activeScene = _getActiveScene(state);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提示词信息
          BlocBuilder<PromptBloc, PromptState>(
            builder: (context, promptState) {
              final sceneToSummaryPrompt = promptState.prompts[AIFeatureType.sceneToSummary];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '使用的提示词', 
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // 跳转到设置页面
                            // TODO(prompt): 实现跳转到提示词设置页面的逻辑
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('编辑'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sceneToSummaryPrompt?.activePrompt ?? '加载中...',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // 当前场景信息
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前场景', 
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (activeScene != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.text_fields, 
                          size: 16, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activeScene?.toString() ?? '当前场景',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.format_size, 
                          size: 16, 
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '字数: ${activeScene?.toString().length ?? 0}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '请先选择一个场景',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 生成结果
          BlocBuilder<PromptBloc, PromptState>(
            builder: (context, promptState) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '生成结果', 
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (promptState.generatedContent.isNotEmpty)
                          IconButton(
                            onPressed: () => _copyToClipboard(promptState.generatedContent),
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: '复制',
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: const EdgeInsets.all(8),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          // 生成内容
                          if (promptState.generatedContent.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Text(
                                  promptState.generatedContent,
                                  style: TextStyle(
                                    height: 1.8,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            )
                          else if (!promptState.isGenerating)
                            Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '生成的摘要将显示在这里',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.outline,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 生成错误
                          if (promptState.generationError != null && !promptState.isGenerating)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  promptState.generationError!,
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                          // 加载指示器
                          if (promptState.isGenerating)
                            promptState.generatedContent.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '正在准备内容...',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Positioned(
                                  bottom: 0,
                                  right: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Theme.of(context).colorScheme.surface.withOpacity(0),
                                          Theme.of(context).colorScheme.surface,
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '正在生成中...',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 生成按钮
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: activeScene != null && !promptState.isGenerating
                          ? () {
                              // 生成摘要
                              context.read<PromptBloc>().add(
                                GenerateSceneSummary(
                                  novelId: widget.novelId,
                                  sceneId: activeScene.id,
                                ),
                              );
                              
                              // 重置用户滚动标记
                              _userScrolled = false;
                            }
                          : null,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('生成摘要'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 获取当前活动场景
  dynamic _getActiveScene(EditorLoaded state) {
    if (state.activeSceneId != null) {
      // 简化实现，直接返回场景 ID
      return state.activeSceneId;
    }
    return null;
  }
}
