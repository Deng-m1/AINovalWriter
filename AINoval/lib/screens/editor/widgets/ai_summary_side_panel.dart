import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/utils/logger.dart';

/// AI摘要生成侧边栏，用于显示从场景生成的摘要内容
class AISummarySidePanel extends StatefulWidget {
  const AISummarySidePanel({
    Key? key,
    required this.onClose,
    required this.onApply,
  }) : super(key: key);
  
  /// 关闭面板时的回调
  final VoidCallback onClose;
  
  /// 应用摘要到编辑器的回调
  final Function(String summary) onApply;

  @override
  State<AISummarySidePanel> createState() => _AISummarySidePanelState();
}

class _AISummarySidePanelState extends State<AISummarySidePanel> {
  /// 编辑器控制器
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _userScrolled = false;
  
  @override
  void initState() {
    super.initState();
    
    // 从EditorBloc获取生成的摘要
    final state = context.read<EditorBloc>().state;
    if (state is EditorLoaded && state.generatedSummary != null) {
      _controller.text = state.generatedSummary!;
    }
    
    // 监听滚动事件，检测用户是否主动滚动
    _scrollController.addListener(_handleUserScroll);
  }
  
  @override
  void dispose() {
    _controller.dispose();
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
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('摘要已复制到剪贴板')),
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is EditorLoaded && state.generatedSummary != null) {
          // 更新编辑器内容
          _controller.text = state.generatedSummary!;
          
          // 只有用户未滚动时才自动滚动到底部
          if (!_userScrolled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0, // 滚动到顶部
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
      },
      builder: (context, state) {
        if (state is! EditorLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final editorState = state as EditorLoaded;
        final isGenerating = editorState.aiSummaryGenerationStatus == AIGenerationStatus.generating;
        final isCompleted = editorState.aiSummaryGenerationStatus == AIGenerationStatus.completed;
        final isFailed = editorState.aiSummaryGenerationStatus == AIGenerationStatus.failed;
        
        return Container(
          width: 350, // 固定宽度
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  children: [
                    Text(
                      'AI 生成的摘要',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // 状态显示
                    if (isGenerating)
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
                      )
                    else if (isCompleted)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '生成完成',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      )
                    else if (isFailed)
                      Row(
                        children: [
                          Icon(
                            Icons.error,
                            size: 14,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '生成失败',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
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
              ),
              
              // 内容区域
              Expanded(
                child: Stack(
                  children: [
                    // 文本编辑器
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        scrollController: _scrollController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '生成的摘要将显示在这里...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.8,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    
                    // 正在生成中的指示器
                    if (isGenerating)
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
                    
                    // 错误信息
                    if (isFailed && editorState.aiGenerationError != null)
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
                            '错误: ${editorState.aiGenerationError}',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 操作栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 重新生成按钮
                    if (!isGenerating && editorState.activeSceneId != null)
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重新生成'),
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 13),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          context.read<EditorBloc>().add(
                            GenerateSceneSummaryRequested(
                              sceneId: editorState.activeSceneId!,
                            ),
                          );
                          // 重置用户滚动标记
                          _userScrolled = false;
                        },
                      ),
                    const Spacer(),
                    // 操作按钮组
                    Row(
                      children: [
                        // 复制按钮
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: '复制摘要',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(8),
                          onPressed: _controller.text.isNotEmpty
                              ? _copyToClipboard
                              : null,
                        ),
                        // 应用按钮
                        FilledButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('应用到场景'),
                          style: FilledButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 13),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: (isCompleted || !isGenerating) && _controller.text.isNotEmpty
                              ? () => widget.onApply(_controller.text)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 