import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/screens/editor/managers/editor_layout_manager.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

/// AI摘要生成面板，提供根据场景内容生成摘要的功能
class AISummaryPanel extends StatefulWidget {
  const AISummaryPanel({
    Key? key,
    required this.novelId,
    required this.onClose,
    this.isCardMode = false,
  }) : super(key: key);

  final String novelId;
  final VoidCallback onClose;
  final bool isCardMode; // 是否以卡片模式显示

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
    // 删除重复的初始化，已在属性声明时初始化过
    _contentEdited = false;
    
    // 加载提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
    
    // 监听滚动事件，检测用户是否主动滚动
    _scrollController.addListener(_handleUserScroll);
    
    // 从PromptBloc获取生成的摘要并更新到控制器
    final promptState = context.read<PromptBloc>().state;
    if (promptState.generatedContent.isNotEmpty) {
      AppLogger.i('AISummaryPanel', '从PromptBloc初始状态获取到摘要内容');
      _summaryController.text = promptState.generatedContent;
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 从PromptBloc获取生成的摘要并更新到控制器
    final promptState = context.read<PromptBloc>().state;
    if (promptState.generatedContent.isNotEmpty) {
      AppLogger.i('AISummaryPanel', '从PromptBloc初始状态获取到摘要内容');
      _summaryController.text = promptState.generatedContent;
    }
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

        return BlocConsumer<PromptBloc, PromptState>(
          listenWhen: (previous, current) => 
              previous.generatedContent != current.generatedContent || 
              previous.isGenerating != current.isGenerating,
          listener: (context, promptState) {
            if (!promptState.isGenerating && promptState.generatedContent.isNotEmpty) {
              AppLogger.i('AISummaryPanel', '检测到新的生成内容，长度: ${promptState.generatedContent.length}');
              // 更新TextField的内容
              _summaryController.text = promptState.generatedContent;
              _contentEdited = false;
            }
          },
          builder: (context, promptState) {
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
                      Row(
                        children: [
                          Icon(
                            Icons.summarize,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI摘要助手',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                                    const SizedBox(width: 8),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // 帮助按钮
                          Tooltip(
                            message: '使用说明',
                            child: IconButton(
                              icon: Icon(
                                Icons.help_outline, 
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('AI摘要生成说明'),
                                    content: const SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('1. 选择要生成摘要的场景'),
                                          SizedBox(height: 8),
                                          Text('2. 点击"生成摘要"按钮'),
                                          SizedBox(height: 8),
                                          Text('3. 生成完成后，可以直接编辑摘要内容'),
                                          SizedBox(height: 8),
                                          Text('4. 点击"保存摘要"按钮将摘要保存到场景'),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('了解了'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '当前场景',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // 提示词选择按钮
                      BlocBuilder<PromptBloc, PromptState>(
                        builder: (context, promptState) {
                          if (promptState.summaryPrompts.isNotEmpty) {
                            return TextButton.icon(
                              icon: Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              label: const Text('摘要模板'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                _showPromptTemplateSelectionDialog(PromptType.summary);
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (activeScene != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activeScene.title,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    if (activeScene.summary != null && activeScene.summary.content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '现有摘要:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeScene.summary.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        '该场景尚未创建摘要',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    
                  ] else ...[
                    const Text('未选择场景'),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // 生成按钮
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: activeScene == null || activeScene.content.isEmpty
                          ? null
                          : () => _generateSummary(context, state),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 16),
                          const SizedBox(width: 8),
                          const Text('生成摘要'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 分割线
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // 生成的摘要
          Expanded(
            child: BlocBuilder<PromptBloc, PromptState>(
              builder: (context, promptState) {
                final isGenerating = promptState.isGenerating;
                final hasGenerated = promptState.generatedContent.isNotEmpty;
                final hasError = promptState.generationError != null;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '生成的摘要',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (hasGenerated) ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: '复制到剪贴板',
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: const EdgeInsets.all(8),
                                onPressed: () {
                                  _copyToClipboard(promptState.generatedContent);
                                },
                              ),
                              const SizedBox(width: 4),
                              if (!_contentEdited && activeScene != null) ...[
                                FilledButton.tonal(
                                  onPressed: () {
                                    // 保存摘要到场景
                                    if (activeScene != null) {
                                      // 从活动场景获取章节和卷ID
                                      final actId = activeScene.actId;
                                      final chapterId = activeScene.chapterId;
                                      
                                      context.read<EditorBloc>().add(
                                        UpdateSummary(
                                          novelId: widget.novelId,
                                          actId: actId,
                                          chapterId: chapterId,
                                          sceneId: activeScene.id,
                                          summary: _summaryController.text,
                                        ),
                                      );
                                      
                                      // 显示保存成功提示
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('摘要已保存')),
                                      );
                                    }
                                  },
                                  child: const Text('保存摘要'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: isGenerating 
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('正在生成摘要...'),
                                  ],
                                ),
                              )
                            : hasError
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Theme.of(context).colorScheme.error,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '生成摘要时出错:\n${promptState.generationError}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : !hasGenerated
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.summarize,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                              size: 32,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              '点击"生成摘要"按钮开始生成',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : TextField(
                                        controller: _summaryController,
                                        maxLines: null,
                                        expands: true,
                                        decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.all(16),
                                          border: InputBorder.none,
                                          hintText: '生成的摘要将显示在这里',
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        onChanged: (_) {
                                          setState(() {
                                            _contentEdited = true;
                                          });
                                        },
                                      ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 显示提示词模板选择对话框
  void _showPromptTemplateSelectionDialog(PromptType type) {
    showDialog(
      context: context,
      builder: (context) => BlocBuilder<PromptBloc, PromptState>(
        builder: (context, state) {
          // 获取对应类型的模板
          final templates = state.summaryPrompts;
          
          return AlertDialog(
            title: const Text('选择摘要模板'),
            content: SizedBox(
              width: 400,
              height: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('点击模板将应用到生成过程'),
                  const SizedBox(height: 16),
                  
                  // 模板列表
                  templates.isEmpty
                      ? const Text('暂无模板，请先添加模板')
                      : Expanded(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: templates.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final template = templates[index];
                              return ListTile(
                                title: Text(template.title),
                                subtitle: Text(
                                  template.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 8,
                                ),
                                onTap: () {
                                  // 将模板设置为当前提示词
                                  if (state.selectedFeatureType != null) {
                                    context.read<PromptBloc>().add(
                                      SavePromptRequested(
                                        AIFeatureType.sceneToSummary,
                                        template.content,
                                      ),
                                    );
                                  }
                                  Navigator.of(context).pop();
                                  
                                  // 显示提示
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('已应用模板: ${template.title}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 生成摘要
  void _generateSummary(BuildContext context, EditorLoaded state) {
    final activeScene = _getActiveScene(state);
    if (activeScene == null) return;

    // 清空现有内容
    _summaryController.clear();
    _contentEdited = false;
    
    AppLogger.i('AISummaryPanel', '开始生成摘要，场景ID: ${activeScene.id}');

    // 发送生成请求
    context.read<PromptBloc>().add(
      GenerateSceneSummary(
        novelId: widget.novelId,
        sceneId: activeScene.id,
      ),
    );
    
    // 清空后显示加载中状态
    setState(() {});
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
