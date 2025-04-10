import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // 加载提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AI摘要助手',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('使用的提示词', style: Theme.of(context).textTheme.labelMedium),
                        TextButton(
                          onPressed: () {
                            // 跳转到设置页面
                            // TODO(prompt): 实现跳转到提示词设置页面的逻辑
                          },
                          child: const Text('编辑'),
                        ),
                      ],
                    ),
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
          Text('当前场景', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          if (activeScene != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeScene?.toString() ?? '当前场景',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  // 假设场景对象有字数属性
                  Text(
                    '字数: ${activeScene?.toString().length ?? 0}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 生成按钮
            Center(
              child: FilledButton.icon(
                onPressed: () {
                  // 生成摘要
                  context.read<PromptBloc>().add(
                    GenerateSceneSummary(
                      novelId: widget.novelId,
                      sceneId: activeScene.id,
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成摘要'),
              ),
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('请先选择一个场景'),
              ),
            ),
          ],

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
                        Text('生成结果', style: Theme.of(context).textTheme.titleMedium),
                        if (promptState.generatedContent.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              // 复制到剪贴板
                            },
                            icon: const Icon(Icons.copy),
                            tooltip: '复制',
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: SingleChildScrollView(
                                child: Text(promptState.generatedContent),
                              ),
                            ),

                          // 生成错误
                          if (promptState.generationError != null && !promptState.isGenerating)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(25),
                                  border: Border.all(color: Colors.red),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  promptState.generationError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ),

                          // 加载指示器
                          if (promptState.isGenerating)
                            Container(
                              color: Colors.black.withAlpha(25),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text(
                                      '正在生成摘要...',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
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
