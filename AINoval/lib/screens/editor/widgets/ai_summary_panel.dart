import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

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
  final TextEditingController _summaryController = TextEditingController();
  bool _userScrolled = false;
  bool _contentEdited = false;

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
    _summaryController.dispose();
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
                  Row(
                    children: [
                      // 状态指示器
                      BlocBuilder<PromptBloc, PromptState>(
                        builder: (context, promptState) {
                          if (promptState.isGenerating) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '正在生成...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: const EdgeInsets.all(4),
                        onPressed: widget.onClose,
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 面板内容
            Expanded(
              child: _buildSummaryContentPanel(context, editorState),
            ),
          ],
        );
      },
    );
  }

  // 构建摘要内容面板
  Widget _buildSummaryContentPanel(BuildContext context, EditorLoaded state) {
    final activeScene = _getActiveScene(state);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                            '场景位置：${_getSceneLocationString(state, activeScene)}',
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
                          '字数: ${activeScene.wordCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (activeScene.summary.content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined, 
                            size: 16, 
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '现有摘要: ${activeScene.summary.content}',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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
              // 如果生成内容有更新且未被手动编辑，则更新控制器内容
              if (promptState.generatedContent.isNotEmpty && 
                  !_contentEdited &&
                  _summaryController.text != promptState.generatedContent) {
                _summaryController.text = promptState.generatedContent;
                
                // 如果用户没有主动滚动，自动滚动到底部
                if (!_userScrolled && _scrollController.hasClients) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              }
              
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
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _copyToClipboard(_summaryController.text),
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: '复制',
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: const EdgeInsets.all(8),
                              ),
                              IconButton(
                                onPressed: () {
                                  // 将摘要应用到场景
                                  if (state.activeSceneId != null && 
                                      state.activeChapterId != null && 
                                      state.activeActId != null) {
                                    context.read<EditorBloc>().add(UpdateSummary(
                                      novelId: widget.novelId,
                                      actId: state.activeActId!,
                                      chapterId: state.activeChapterId!,
                                      sceneId: state.activeSceneId!,
                                      summary: _summaryController.text,
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('摘要已应用到场景')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save, size: 18),
                                tooltip: '应用为场景摘要',
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          // 生成内容显示区域（可编辑）
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant,
                                width: 0.5,
                              ),
                            ),
                            child: promptState.generatedContent.isNotEmpty
                              ? TextField(
                                  controller: _summaryController,
                                  scrollController: _scrollController,
                                  maxLines: null,
                                  expands: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(4),
                                  ),
                                  style: TextStyle(
                                    height: 1.8,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  onChanged: (value) {
                                    _contentEdited = true;
                                  },
                                  enabled: !promptState.isGenerating, // 生成过程中禁用编辑
                                )
                              : Center(
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
                          ),

                          // 生成错误提示
                          if (promptState.generationError != null && !promptState.isGenerating)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
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

                          // 生成进度指示器（底部提示，不遮挡文字）
                          if (promptState.isGenerating && promptState.generatedContent.isNotEmpty)
                            Positioned(
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
                    Row(
                      children: [
                        Expanded(
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
                                  
                                  // 重置用户滚动标记和编辑标记
                                  _userScrolled = false;
                                  _contentEdited = false;
                                }
                              : null,
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('生成摘要'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (promptState.generatedContent.isNotEmpty || _summaryController.text.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                // 根据摘要生成场景
                                final layoutManager = Provider.of<EditorLayoutManager>(context, listen: false);
                                widget.onClose();
                                layoutManager.toggleAISceneGenerationPanel();
                              },
                              icon: const Icon(Icons.create, size: 16),
                              label: const Text('根据摘要生成场景'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
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
    if (state.activeSceneId != null && state.activeActId != null && state.activeChapterId != null) {
      // 获取完整的场景对象而不仅仅是ID
      final scene = state.novel.getScene(state.activeActId!, state.activeChapterId!, sceneId: state.activeSceneId);
      if (scene != null) {
        // 返回场景对象
        return scene;
      }
    }
    return null;
  }

  String _getSceneLocationString(EditorLoaded state, Scene scene) {
    if (state.activeActId != null && state.activeChapterId != null) {
      // 尝试获取Act和Chapter的名称
      String actName = "未知幕";
      String chapterName = "未知章节";
      
      // 获取Act名称
      final act = state.novel.getAct(state.activeActId!);
      if (act != null) {
        actName = act.title;
        
        // 获取Chapter名称
        final chapter = act.getChapter(state.activeChapterId!);
        if (chapter != null) {
          chapterName = chapter.title;
        }
      }
      
      return '$actName > $chapterName';
    }
    return '未知场景位置';
  }
}
