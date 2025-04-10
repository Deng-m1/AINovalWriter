import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

/// AI流式生成内容显示组件
/// 在编辑器右侧面板中展示流式生成的内容，使用打字机效果
class AIStreamGenerationDisplay extends StatefulWidget {
  const AIStreamGenerationDisplay({
    Key? key,
    required this.onClose,
    this.onOpenInEditor,
  }) : super(key: key);

  /// 关闭面板的回调
  final VoidCallback onClose;
  
  /// 在编辑器中打开内容的回调
  final Function(String content)? onOpenInEditor;

  @override
  State<AIStreamGenerationDisplay> createState() => _AIStreamGenerationDisplayState();
}

class _AIStreamGenerationDisplayState extends State<AIStreamGenerationDisplay> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    
    // 初始化时检查是否有正在进行的生成，如有则自动滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<EditorBloc>().state;
      if (state is EditorLoaded && 
          state.aiSceneGenerationStatus == AIGenerationStatus.generating &&
          state.generatedSceneContent != null && 
          state.generatedSceneContent!.isNotEmpty) {
        _scrollToBottom();
        AppLogger.i('AIStreamGenerationDisplay', '初始化时检测到生成内容，自动滚动到底部');
      }
    });
    
    // 启动定期滚动更新
    _startAutoScrollTimer();
  }
  
  void _startAutoScrollTimer() {
    // 每500毫秒检查一次是否需要滚动
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final state = context.read<EditorBloc>().state;
      if (state is EditorLoaded && 
          state.isStreamingGeneration && 
          state.aiSceneGenerationStatus == AIGenerationStatus.generating) {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 自动滚动到底部
  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      AppLogger.d('AIStreamGenerationDisplay', '滚动控制器还没有客户端，延迟滚动');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      return;
    }
    
    try {
      AppLogger.d('AIStreamGenerationDisplay', '执行滚动到底部');
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } catch (e) {
      AppLogger.e('AIStreamGenerationDisplay', '滚动到底部失败', e);
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
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is EditorLoaded && 
            state.isStreamingGeneration && 
            state.generatedSceneContent != null &&
            state.generatedSceneContent!.isNotEmpty) {
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        if (state is! EditorLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final isGenerating = state.aiSceneGenerationStatus == AIGenerationStatus.generating;
        final hasGenerated = state.aiSceneGenerationStatus == AIGenerationStatus.completed;
        final hasFailed = state.aiSceneGenerationStatus == AIGenerationStatus.failed;
        final content = state.generatedSceneContent ?? '';
        
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
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
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
                      'AI 生成场景',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    // 状态指示器
                    if (isGenerating)
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '正在生成...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      )
                    else if (hasGenerated)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
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
                    else if (hasFailed)
                      Row(
                        children: [
                          Icon(
                            Icons.error,
                            size: 16,
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
                    IconButton(
                      icon: const Icon(Icons.close),
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
                    if (content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content,
                                style: const TextStyle(
                                  height: 1.6,
                                ),
                              ),
                              // 如果正在生成，在末尾显示输入指示器
                              if (isGenerating)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '正在生成',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else if (!isGenerating && !hasFailed)
                      const Center(
                        child: Text('生成的内容将显示在这里...'),
                      )
                    else if (isGenerating && content.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              '正在准备内容...',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                    // 错误信息
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
                            '错误: ${state.aiGenerationError}',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 底部操作栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
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
                    // 左侧按钮
                    if (isGenerating)
                      TextButton.icon(
                        onPressed: () {
                          context.read<EditorBloc>().add(StopSceneGeneration());
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('停止生成'),
                      )
                    else
                      TextButton.icon(
                        onPressed: hasGenerated && content.isNotEmpty
                            ? () {
                                // 创建新场景并使用生成的内容
                                if (widget.onOpenInEditor != null) {
                                  widget.onOpenInEditor!(content);
                                  AppLogger.i('AIStreamGenerationDisplay', '在编辑器中打开生成内容');
                                  widget.onClose();
                                }
                              }
                            : null,
                        icon: const Icon(Icons.save),
                        label: const Text('保存为场景'),
                      ),
                    
                    // 右侧按钮
                    IconButton(
                      onPressed: hasGenerated && content.isNotEmpty
                          ? () => _copyToClipboard(content)
                          : null,
                      icon: const Icon(Icons.copy),
                      tooltip: '复制全部内容',
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