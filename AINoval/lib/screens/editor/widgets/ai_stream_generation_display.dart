import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
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
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _styleController = TextEditingController();
  bool _userScrolled = false;
  bool _showGeneratePanel = false;

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
    
    // 监听滚动事件，检测用户是否主动滚动
    _scrollController.addListener(_handleUserScroll);
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
  
  void _startAutoScrollTimer() {
    // 每500毫秒检查一次是否需要滚动
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final state = context.read<EditorBloc>().state;
      if (state is EditorLoaded && 
          state.isStreamingGeneration && 
          state.aiSceneGenerationStatus == AIGenerationStatus.generating &&
          !_userScrolled) { // 只有在用户没有主动滚动时自动滚动
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_handleUserScroll);
    _scrollController.dispose();
    _summaryController.dispose();
    _styleController.dispose();
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
  
  /// 生成场景
  void _generateScene(BuildContext context) {
    if (_summaryController.text.isEmpty) return;
    
    try {
      final state = context.read<EditorBloc>().state;
      if (state is! EditorLoaded) return;
      
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
      
      // 隐藏生成面板
      setState(() {
        _showGeneratePanel = false;
      });
      
      // 重置用户滚动标记
      _userScrolled = false;
      
    } catch (e) {
      AppLogger.e('AIStreamGenerationDisplay', '生成场景错误', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动AI生成时出错: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is EditorLoaded && 
            state.isStreamingGeneration && 
            state.generatedSceneContent != null &&
            state.generatedSceneContent!.isNotEmpty &&
            !_userScrolled) {
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
                      'AI 生成助手',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // 状态指示器
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
                            '正在流式生成...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      )
                    else if (hasGenerated)
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
                    else if (hasFailed)
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
              
              // 内容标签
              if (!_showGeneratePanel)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TabPageSelector(
                        selectedColor: Theme.of(context).colorScheme.primary,
                        color: Theme.of(context).colorScheme.outlineVariant,
                        controller: TabController(
                          initialIndex: 0,
                          length: 2,
                          vsync: const _TickerProviderImpl(),
                        ),
                      ),
                      const Spacer(),
                      // 添加生成场景按钮
                      if (!isGenerating) // 只在不生成时显示
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showGeneratePanel = true;
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('生成新场景'),
                          style: TextButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                    ],
                  ),
                ),
              
              // 生成面板 (新增)
              if (_showGeneratePanel)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '创建新场景',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _summaryController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: '场景摘要/大纲',
                          hintText: '请输入场景大纲或摘要...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _styleController,
                        decoration: InputDecoration(
                          labelText: '风格指令（可选）',
                          hintText: '多对话，少描写，悬疑风格...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _summaryController.text.isNotEmpty
                                  ? () => _generateScene(context)
                                  : null,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('开始生成'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _showGeneratePanel = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('取消'),
                          ),
                        ],
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
                          physics: const AlwaysScrollableScrollPhysics(), // 允许滚动
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content,
                                style: TextStyle(
                                  height: 1.8,
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              // 底部空间
                              if (isGenerating)
                                const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      )
                    else if (!isGenerating && !hasFailed)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '生成的内容将显示在这里',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isGenerating && content.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      ),
                      
                    // 生成指示器 (流式生成时在底部显示小提示)
                    if (isGenerating && content.isNotEmpty)
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
                    // 左侧按钮
                    if (isGenerating)
                      TextButton.icon(
                        onPressed: () {
                          context.read<EditorBloc>().add(StopSceneGeneration());
                        },
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('停止生成'),
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 13),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      )
                    else
                      FilledButton.icon(
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
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('保存为场景'),
                        style: FilledButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 13),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    
                    // 右侧按钮
                    Row(
                      children: [
                        if (!isGenerating && hasGenerated)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showGeneratePanel = true;
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: '重新生成',
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: const EdgeInsets.all(8),
                          ),
                        IconButton(
                          onPressed: hasGenerated && content.isNotEmpty
                              ? () => _copyToClipboard(content)
                              : null,
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: '复制全部内容',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(8),
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

/// 简单的TickerProvider实现，用于TabController
class _TickerProviderImpl extends TickerProvider {
  const _TickerProviderImpl();
  
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
} 