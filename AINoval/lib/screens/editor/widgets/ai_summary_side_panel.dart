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
  
  @override
  void initState() {
    super.initState();
    
    // 从EditorBloc获取生成的摘要
    final state = context.read<EditorBloc>().state;
    if (state is EditorLoaded && state.generatedSummary != null) {
      _controller.text = state.generatedSummary!;
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                      'AI 生成的摘要',
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
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '生成的摘要将显示在这里...',
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
                    // 重新生成按钮
                    if (!isGenerating && editorState.activeSceneId != null)
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新生成'),
                        onPressed: () {
                          context.read<EditorBloc>().add(
                            GenerateSceneSummaryRequested(
                              sceneId: editorState.activeSceneId!,
                            ),
                          );
                        },
                      ),
                    const Spacer(),
                    // 复制按钮
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: '复制摘要',
                      onPressed: _controller.text.isNotEmpty
                          ? _copyToClipboard
                          : null,
                    ),
                    // 应用按钮
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: '应用到场景',
                      onPressed: (isCompleted || !isGenerating) && _controller.text.isNotEmpty
                          ? () => widget.onApply(_controller.text)
                          : null,
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