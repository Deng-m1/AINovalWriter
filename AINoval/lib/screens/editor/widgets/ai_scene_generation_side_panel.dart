import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/utils/logger.dart';

/// AI场景生成侧边栏，用于显示从摘要生成的场景内容
class AISceneGenerationSidePanel extends StatefulWidget {
  const AISceneGenerationSidePanel({
    Key? key,
    required this.onClose,
    required this.onInsert,
  }) : super(key: key);

  /// 关闭面板时的回调
  final VoidCallback onClose;
  
  /// 插入内容到编辑器的回调
  final Function(String content) onInsert;

  @override
  State<AISceneGenerationSidePanel> createState() => _AISceneGenerationSidePanelState();
}

class _AISceneGenerationSidePanelState extends State<AISceneGenerationSidePanel> {
  /// 编辑器控制器
  final TextEditingController _controller = TextEditingController();
  
  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();
  
  /// 是否已滚动到底部
  bool _isScrolledToBottom = true;
  
  @override
  void initState() {
    super.initState();
    
    // 监听滚动事件，判断是否在底部
    _scrollController.addListener(_scrollListener);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 滚动监听器，判断是否在底部
  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isBottom = _scrollController.position.pixels >= 
                     _scrollController.position.maxScrollExtent - 50;
      if (isBottom != _isScrolledToBottom) {
        setState(() {
          _isScrolledToBottom = isBottom;
        });
      }
    }
  }
  
  /// 复制内容到剪贴板
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容已复制到剪贴板')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is EditorLoaded && state.generatedSceneContent != null) {
          // 更新编辑器内容
          _controller.text = state.generatedSceneContent!;
          
          // 如果用户滚动在底部，自动滚动到最新内容
          if (_isScrolledToBottom && _scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
          }
        }
      },
      builder: (context, state) {
        if (state is! EditorLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final editorState = state as EditorLoaded;
        final isGenerating = editorState.aiSceneGenerationStatus == AIGenerationStatus.generating;
        final isCompleted = editorState.aiSceneGenerationStatus == AIGenerationStatus.completed;
        final isFailed = editorState.aiSceneGenerationStatus == AIGenerationStatus.failed;
        
        return Container(
          width: 350, // 固定宽度
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'AI 生成的场景',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    // 状态显示
                    if (isGenerating)
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
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
                    else if (isCompleted)
                      const Text(
                        '已完成',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      )
                    else if (isFailed)
                      const Text(
                        '生成失败',
                        style: TextStyle(fontSize: 12, color: Colors.red),
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
                        scrollController: _scrollController,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '生成的内容将显示在这里...',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
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
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 操作栏
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 复制按钮
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: '复制内容',
                      onPressed: _controller.text.isNotEmpty
                          ? _copyToClipboard
                          : null,
                    ),
                    // 插入原文按钮
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: '插入到编辑器',
                      onPressed: (isCompleted || !isGenerating) && _controller.text.isNotEmpty
                          ? () => widget.onInsert(_controller.text)
                          : null,
                    ),
                    // 停止生成按钮
                    if (isGenerating)
                      IconButton(
                        icon: const Icon(Icons.stop_circle_outlined),
                        tooltip: '停止生成',
                        onPressed: () {
                          context.read<EditorBloc>().add(const StopSceneGeneration());
                        },
                      ),
                    // 关闭按钮
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: widget.onClose,
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