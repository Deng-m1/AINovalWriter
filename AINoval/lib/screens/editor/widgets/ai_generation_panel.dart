import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:flutter/services.dart';


/// AI生成面板，提供根据摘要生成场景的功能
class AIGenerationPanel extends StatefulWidget {
  const AIGenerationPanel({
    Key? key,
    required this.novelId,
    required this.onClose,
  }) : super(key: key);

  final String novelId;
  final VoidCallback onClose;

  @override
  State<AIGenerationPanel> createState() => _AIGenerationPanelState();
}

class _AIGenerationPanelState extends State<AIGenerationPanel> {
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _styleController = TextEditingController();
  final TextEditingController _generatedContentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _userScrolled = false;
  bool _contentEdited = false;

  @override
  void initState() {
    super.initState();
    // 加载提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
    
    // 监听滚动事件，检测用户是否主动滚动
    _scrollController.addListener(_handleUserScroll);
    
    // 读取待处理的摘要内容
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final editorState = context.read<EditorBloc>().state;
      if (editorState is EditorLoaded && editorState.pendingSummary != null && editorState.pendingSummary!.isNotEmpty) {
        _summaryController.text = editorState.pendingSummary!;
        
        // 清除待处理摘要，避免下次打开时仍然显示
        context.read<EditorBloc>().add(const SetPendingSummary(summary: ''));
      }
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _styleController.dispose();
    _generatedContentController.dispose();
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
        const SnackBar(content: Text('内容已复制到剪贴板')),
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

        // 调试日志：检查摘要控制器内容
        AppLogger.d('AIGenerationPanel', '摘要控制器内容长度: ${_summaryController.text.length}');
        if (_summaryController.text.isEmpty && editorState.pendingSummary != null) {
          AppLogger.d('AIGenerationPanel', '摘要控制器为空，但有待处理摘要: ${editorState.pendingSummary!}');
        }

        // 如果生成内容发生更新且未被手动编辑，则更新编辑器内容
        if (editorState.generatedSceneContent != null && 
            !_contentEdited && 
            _generatedContentController.text != editorState.generatedSceneContent) {
          _generatedContentController.text = editorState.generatedSceneContent!;
          
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
                    'AI场景生成',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      // 状态指示器
                      if (editorState.aiSceneGenerationStatus == AIGenerationStatus.generating)
                        Row(
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
              child: _buildSceneGenerationPanel(context, editorState),
            ),
          ],
        );
      },
    );
  }

  /// 构建场景生成面板
  Widget _buildSceneGenerationPanel(BuildContext context, EditorLoaded state) {
    final isGenerating = state.aiSceneGenerationStatus == AIGenerationStatus.generating;
    final hasGenerated = state.aiSceneGenerationStatus == AIGenerationStatus.completed &&
                       state.generatedSceneContent != null;
    final hasFailed = state.aiSceneGenerationStatus == AIGenerationStatus.failed;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 摘要文本输入
          Text(
            '场景摘要/大纲',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: _summaryController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '请输入场景大纲或摘要，AI将根据此内容生成完整场景',
                contentPadding: EdgeInsets.all(12),
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 风格指令输入
          Text(
            '风格指令（可选）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: _styleController,
              decoration: const InputDecoration(
                hintText: '例如：多对话，少描写，悬疑风格',
                contentPadding: EdgeInsets.all(12),
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 章节选择（可选）
          if (state.novel.acts.isNotEmpty) ...[
            Text(
              '目标章节（可选）',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: state.activeChapterId,
                  items: _buildChapterDropdownItems(state.novel),
                  onChanged: (chapterId) {
                    if (chapterId != null) {
                      // 查找选中章节所属的Act
                      String? actId;
                      for (final act in state.novel.acts) {
                        for (final chapter in act.chapters) {
                          if (chapter.id == chapterId) {
                            actId = act.id;
                            break;
                          }
                        }
                        if (actId != null) break;
                      }

                      if (actId != null) {
                        // 更新活跃章节
                        context.read<EditorBloc>().add(SetActiveChapter(
                          actId: actId,
                          chapterId: chapterId,
                        ));
                      }
                    }
                  },
                  style: Theme.of(context).textTheme.bodyMedium,
                  hint: Text(
                    '选择一个目标章节',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // 生成结果或操作区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasGenerated || isGenerating) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '生成结果', 
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasGenerated)
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _copyToClipboard(_generatedContentController.text),
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: '复制',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: const EdgeInsets.all(8),
                            ),
                            IconButton(
                              onPressed: () {
                                // 将生成内容应用到编辑器
                                if (state.activeActId != null && state.activeChapterId != null) {
                                  // 获取布局管理器
                                  final layoutManager = Provider.of<EditorLayoutManager>(context, listen: false);
                                  
                                  // 创建新场景并使用生成内容
                                  final sceneId = 'scene_${DateTime.now().millisecondsSinceEpoch}';
                                  
                                  // 添加新场景
                                  context.read<EditorBloc>().add(AddNewScene(
                                    novelId: widget.novelId,
                                    actId: state.activeActId!,
                                    chapterId: state.activeChapterId!,
                                    sceneId: sceneId,
                                  ));
                                  
                                  // 等待短暂时间，确保场景已添加
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    // 设置场景内容
                                    context.read<EditorBloc>().add(UpdateSceneContent(
                                      novelId: widget.novelId,
                                      actId: state.activeActId!,
                                      chapterId: state.activeChapterId!,
                                      sceneId: sceneId,
                                      content: _generatedContentController.text,
                                    ));
                                    
                                    // 设置为活动场景
                                    context.read<EditorBloc>().add(SetActiveScene(
                                      actId: state.activeActId!,
                                      chapterId: state.activeChapterId!,
                                      sceneId: sceneId,
                                    ));
                                    
                                    // 关闭生成面板
                                    widget.onClose();
                                    
                                    // 显示通知
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已创建新场景并应用生成内容')),
                                    );
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              tooltip: '添加为新场景',
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
                          child: TextField(
                            controller: _generatedContentController,
                            scrollController: _scrollController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(4),
                              hintText: '生成内容将在这里显示...',
                            ),
                            style: TextStyle(
                              height: 1.8,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            onChanged: (value) {
                              _contentEdited = true;
                            },
                            enabled: !isGenerating, // 生成过程中禁用编辑
                          ),
                        ),
                        
                        // 生成失败提示
                        if (hasFailed && state.aiGenerationError != null)
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
                                state.aiGenerationError!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          
                        // 生成进度指示器（底部提示，不遮挡文字）  
                        if (isGenerating && state.generatedSceneContent != null && state.generatedSceneContent!.isNotEmpty)
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
                ] else if (hasFailed) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '生成失败: ${state.aiGenerationError ?? "未知错误"}',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ] else 
                  const Expanded(child: SizedBox.shrink()),
                
                const SizedBox(height: 16),
                
                // 生成按钮区域
                if (!isGenerating) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_summaryController.text.isNotEmpty || hasGenerated) ? () {
                            AppLogger.i('AIGenerationPanel', '点击流式生成场景按钮');
                            
                            try {
                              // 检查当前状态，确保不会重复触发生成
                              final currentState = context.read<EditorBloc>().state;
                              if (currentState is EditorLoaded && 
                                  currentState.aiSceneGenerationStatus == AIGenerationStatus.generating) {
                                AppLogger.w('AIGenerationPanel', '已有生成任务正在进行，忽略此次点击');
                                
                                // 注意：由于已删除流式生成显示面板，所以这里直接关闭此面板即可
                                widget.onClose();
                                return;
                              }
                              
                              // 获取布局管理器
                              final layoutManager = Provider.of<EditorLayoutManager>(context, listen: false);
                              
                              // 触发场景生成请求
                              context.read<EditorBloc>().add(
                                GenerateSceneFromSummaryRequested(
                                  novelId: state.novel.id,
                                  summary: _summaryController.text,
                                  chapterId: state.activeChapterId,
                                  styleInstructions: _styleController.text.isNotEmpty
                                      ? _styleController.text
                                      : null,
                                  useStreamingMode: true,
                                ),
                              );
                              
                              // 重置用户滚动标记
                              _userScrolled = false;
                              _contentEdited = false;
                              
                              AppLogger.i('AIGenerationPanel', '已开始流式生成场景');
                            } catch (e) {
                              AppLogger.e('AIGenerationPanel', '流式生成场景按钮处理错误', e);
                              // 显示错误提示
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('启动AI生成时出错: ${e.toString()}')),
                              );
                            }
                          } : null,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('流式生成场景'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_summaryController.text.isNotEmpty || hasGenerated) ? () {
                            AppLogger.i('AIGenerationPanel', '点击快速生成场景按钮');
                            
                            try {
                              // 触发场景生成（非流式）
                              context.read<EditorBloc>().add(
                                GenerateSceneFromSummaryRequested(
                                  novelId: state.novel.id,
                                  summary: _summaryController.text,
                                  chapterId: state.activeChapterId,
                                  styleInstructions: _styleController.text.isNotEmpty
                                      ? _styleController.text
                                      : null,
                                  useStreamingMode: false,
                                ),
                              );
                              
                              // 重置用户滚动标记
                              _userScrolled = false;
                              _contentEdited = false;
                              
                              AppLogger.i('AIGenerationPanel', '已开始快速生成场景');
                            } catch (e) {
                              AppLogger.e('AIGenerationPanel', '快速生成场景按钮处理错误', e);
                              // 显示错误提示
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('启动AI生成时出错: ${e.toString()}')),
                              );
                            }
                          } : null,
                          icon: const Icon(Icons.flash_on, size: 16),
                          label: const Text('快速生成场景'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // 重试按钮（仅在失败时显示）
                  if (hasFailed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (_summaryController.text.isNotEmpty || hasGenerated) ? () {
                            // 重试生成
                            context.read<EditorBloc>().add(
                              GenerateSceneFromSummaryRequested(
                                novelId: state.novel.id,
                                summary: _summaryController.text,
                                chapterId: state.activeChapterId,
                                styleInstructions: _styleController.text.isNotEmpty
                                    ? _styleController.text
                                    : null,
                                useStreamingMode: true,
                              ),
                            );
                            
                            // 重置用户滚动标记
                            _userScrolled = false;
                            _contentEdited = false;
                          } : null,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('重试'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                ] else ...[
                  // 取消生成按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // 取消生成
                        context.read<EditorBloc>().add(
                          const StopSceneGeneration(),
                        );
                      },
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('取消生成'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建章节下拉菜单选项
  List<DropdownMenuItem<String>> _buildChapterDropdownItems(Novel novel) {
    final items = <DropdownMenuItem<String>>[];

    for (final act in novel.acts) {
      // 添加Act分组标题
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          child: Text(
            act.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      );

      // 添加Act下的Chapter
      for (final chapter in act.chapters) {
        items.add(
          DropdownMenuItem<String>(
            value: chapter.id,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(chapter.title),
            ),
          ),
        );
      }
    }

    return items;
  }
}