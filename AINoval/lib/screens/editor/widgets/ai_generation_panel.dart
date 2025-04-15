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
    this.isCardMode = false,
  }) : super(key: key);

  final String novelId;
  final VoidCallback onClose;
  final bool isCardMode; // 是否以卡片模式显示

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
  bool _isGenerating = false;
  String _generatedText = '';

  @override
  void initState() {
    super.initState();
    // 加载提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
    
    // 一次性加载提示词模板
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 延迟加载模板，避免同时触发多个事件
      Future.delayed(const Duration(milliseconds: 200), () {
        final promptState = context.read<PromptBloc>().state;
        // 只有当尚未加载模板时才加载
        if (promptState is PromptLoaded && 
            promptState.summaryPrompts.isEmpty && 
            promptState.stylePrompts.isEmpty) {
          context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
        }
      });
    });
    
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
        const SnackBar(
          content: Text('内容已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  /// 构建章节下拉菜单选项
  List<DropdownMenuItem<String>> _buildChapterDropdownItems(Novel novel) {
    final items = <DropdownMenuItem<String>>[];

    for (final act in novel.acts) {
      // 添加Act分组标题
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              act.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );

      // 添加Act下的Chapter
      for (final chapter in act.chapters) {
        items.add(
          DropdownMenuItem<String>(
            value: chapter.id,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 12), // 缩进
                  const Icon(Icons.menu_book_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chapter.title,
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return items;
  }

  /// 显示提示词模板选择对话框
  void _showPromptTemplateSelectionDialog(PromptType type) {
    final searchController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => BlocBuilder<PromptBloc, PromptState>(
        builder: (context, state) {
          // 获取对应类型的模板
          final templates = type == PromptType.summary 
              ? state.summaryPrompts 
              : state.stylePrompts;
          
          // 应用搜索过滤
          final filteredTemplates = templates.where((template) {
            if (searchQuery.isEmpty) return true;
            return template.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  template.content.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
          
          final title = type == PromptType.summary 
              ? '选择摘要模板' 
              : '选择风格模板';
          
          final controllerToUpdate = type == PromptType.summary 
              ? _summaryController 
              : _styleController;
          
          return AlertDialog(
            title: Text(title),
            contentPadding: const EdgeInsets.only(top: 20, left: 24, right: 24),
            content: SizedBox(
              width: 550,
              height: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 搜索框
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '搜索模板...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (value) {
                      searchQuery = value;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 模板列表
                  Expanded(
                    child: filteredTemplates.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.note_alt_outlined,
                                  size: 48,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchQuery.isEmpty 
                                      ? '暂无模板，请先添加模板' 
                                      : '没有找到匹配的模板',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredTemplates.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final template = filteredTemplates[index];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    template.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      template.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, 
                                    vertical: 8,
                                  ),
                                  onTap: () {
                                    // 更新对应的编辑器内容
                                    controllerToUpdate.text = template.content;
                                    Navigator.of(context).pop();
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined, 
                                          size: 18,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        tooltip: '编辑模板',
                                        style: IconButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          // 延迟执行，避免对话框关闭后立即打开另一个对话框
                                          Future.delayed(const Duration(milliseconds: 100), () {
                                            _showEditPromptTemplateDialog(template);
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline, 
                                          size: 18,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                        tooltip: '删除模板',
                                        style: IconButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          // 删除确认对话框
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('确认删除'),
                                              content: Text('确定要删除模板 "${template.title}" 吗？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(),
                                                  child: const Text('取消'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    // 删除模板
                                                    context.read<PromptBloc>().add(
                                                      DeletePromptTemplateRequested(template.id),
                                                    );
                                                    Navigator.of(context).pop();
                                                  },
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: Theme.of(context).colorScheme.error,
                                                    foregroundColor: Theme.of(context).colorScheme.onError,
                                                  ),
                                                  child: const Text('删除'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('添加模板'),
                onPressed: () {
                  Navigator.of(context).pop();
                  // 延迟执行，避免对话框关闭后立即打开另一个对话框
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _showAddPromptTemplateDialog(type);
                  });
                },
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// 显示编辑提示词模板对话框
  void _showEditPromptTemplateDialog(PromptItem template) {
    final titleController = TextEditingController(text: template.title);
    final contentController = TextEditingController(text: template.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.edit_note,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('编辑提示词模板'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 模板类型标识
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: template.type == PromptType.summary
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        template.type == PromptType.summary
                            ? Icons.description_outlined
                            : Icons.style,
                        size: 16,
                        color: template.type == PromptType.summary
                            ? Colors.blue
                            : Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        template.type == PromptType.summary ? '摘要模板' : '风格模板',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: template.type == PromptType.summary
                              ? Colors.blue
                              : Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // 标题输入
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: '模板名称',
                    hintText: '输入一个简短的名称',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.title),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLength: 20,
                ),
                const SizedBox(height: 20),
                
                // 内容输入
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: '模板内容',
                    alignLabelWithHint: true,
                    hintText: template.type == PromptType.summary 
                        ? '输入摘要提示词内容' 
                        : '输入风格提示词内容',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLines: 8,
                  minLines: 5,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('保存'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                // 删除旧模板
                context.read<PromptBloc>().add(
                  DeletePromptTemplateRequested(template.id),
                );
                
                // 添加新模板（更新后的）
                context.read<PromptBloc>().add(
                  AddPromptTemplateRequested(
                    title: titleController.text,
                    content: contentController.text,
                    type: template.type,
                  ),
                );
                
                Navigator.of(context).pop();
                
                // 显示更新成功提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('模板已更新'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 显示添加提示词模板对话框
  void _showAddPromptTemplateDialog(PromptType type) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(type == PromptType.summary ? '添加摘要提示词模板' : '添加风格提示词模板'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 模板类型标识
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: type == PromptType.summary
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type == PromptType.summary
                            ? Icons.description_outlined
                            : Icons.style,
                        size: 16,
                        color: type == PromptType.summary
                            ? Colors.blue
                            : Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        type == PromptType.summary ? '摘要模板' : '风格模板',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: type == PromptType.summary
                              ? Colors.blue
                              : Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // 标题输入
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: '模板名称',
                    hintText: '输入一个简短的名称',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.title),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLength: 20,
                ),
                const SizedBox(height: 20),
                
                // 内容输入
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: '模板内容',
                    alignLabelWithHint: true,
                    hintText: type == PromptType.summary 
                        ? '输入摘要提示词内容' 
                        : '输入风格提示词内容',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLines: 8,
                  minLines: 5,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                // 提示信息
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          type == PromptType.summary
                              ? '创建一个好的摘要模板可以帮助AI更准确地理解场景内容，生成更贴切的摘要。'
                              : '风格模板将影响AI生成内容的文风和表达方式，可以根据需要自定义不同风格。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('保存'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                // 添加提示词模板
                context.read<PromptBloc>().add(
                  AddPromptTemplateRequested(
                    title: titleController.text,
                    content: contentController.text,
                    type: type,
                  ),
                );
                Navigator.of(context).pop();
                
                // 显示添加成功提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已添加新模板'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 显示编辑默认提示词对话框
  void _showEditDefaultPromptsDialog(BuildContext context) {
    // 创建提示词控制器
    final sceneToSummaryController = TextEditingController();
    final summaryToSceneController = TextEditingController();
    
    // 从Bloc中获取当前提示词
    final promptState = context.read<PromptBloc>().state;
    
    // 填充提示词控制器
    if (promptState.prompts.containsKey(AIFeatureType.sceneToSummary)) {
      sceneToSummaryController.text = promptState.prompts[AIFeatureType.sceneToSummary]!.activePrompt;
    }
    
    if (promptState.prompts.containsKey(AIFeatureType.summaryToScene)) {
      summaryToSceneController.text = promptState.prompts[AIFeatureType.summaryToScene]!.activePrompt;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.settings_suggest,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('编辑默认提示词'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 场景生成摘要提示词
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.summarize,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '场景生成摘要',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: sceneToSummaryController,
                  decoration: InputDecoration(
                    labelText: '场景生成摘要提示词',
                    alignLabelWithHint: true,
                    hintText: '输入用于生成摘要的提示词',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLines: 8,
                  minLines: 5,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 摘要生成场景提示词
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '摘要生成场景',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: summaryToSceneController,
                  decoration: InputDecoration(
                    labelText: '摘要生成场景提示词',
                    alignLabelWithHint: true,
                    hintText: '输入用于生成场景的提示词',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLines: 8,
                  minLines: 5,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 提示信息
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '默认提示词会影响所有未使用特定模板的AI生成。编辑这些提示词可以全局控制AI生成的方向和质量。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('保存'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              // 保存场景生成摘要提示词
              if (sceneToSummaryController.text.isNotEmpty) {
                context.read<PromptBloc>().add(
                  SavePromptRequested(
                    AIFeatureType.sceneToSummary,
                    sceneToSummaryController.text,
                  ),
                );
              }
              
              // 保存摘要生成场景提示词
              if (summaryToSceneController.text.isNotEmpty) {
                context.read<PromptBloc>().add(
                  SavePromptRequested(
                    AIFeatureType.summaryToScene,
                    summaryToSceneController.text,
                  ),
                );
              }
              
              // 显示保存成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('提示词已保存'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  /// 重新初始化生成状态
  void _resetGenerationState() {
    _userScrolled = false;
    _contentEdited = false;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI场景生成',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (editorState.aiSceneGenerationStatus == AIGenerationStatus.generating) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '生成中',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      // 添加编辑提示词按钮
                      BlocBuilder<PromptBloc, PromptState>(
                        builder: (context, promptState) {
                          return Tooltip(
                            message: '编辑默认提示词',
                            child: TextButton.icon(
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('编辑提示词'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                textStyle: const TextStyle(fontSize: 13),
                              ),
                              onPressed: () {
                                _showEditDefaultPromptsDialog(context);
                              },
                            ),
                          );
                        },
                      ),
                      // 添加帮助按钮
                      Tooltip(
                        message: '使用说明',
                        child: IconButton(
                          icon: Icon(
                            Icons.help_outline, 
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(8),
                          onPressed: () {
                            // 显示使用说明对话框
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('AI场景生成使用说明'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('1. 在"场景摘要/大纲"中描述你想要生成的场景内容'),
                                      const SizedBox(height: 8),
                                      const Text('2. 可以添加风格指令来控制AI生成的文风和风格特点'),
                                      const SizedBox(height: 8),
                                      const Text('3. 选择目标章节可以让AI更好地理解场景在小说中的位置'),
                                      const SizedBox(height: 8),
                                      const Text('4. 使用"流式生成"可以实时查看生成过程，而"快速生成"会一次性返回结果'),
                                      const SizedBox(height: 12),
                                      Text(
                                        '提示：生成完成后，您可以直接编辑生成的内容，然后添加为新场景',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
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
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.all(8),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '场景摘要/大纲',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              BlocBuilder<PromptBloc, PromptState>(
                builder: (context, promptState) {
                  if (promptState is PromptLoaded && promptState.summaryPrompts.isNotEmpty) {
                    return TextButton.icon(
                      icon: Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: const Text('选择模板'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () {
                        // 弹出模板选择对话框
                        _showPromptTemplateSelectionDialog(PromptType.summary);
                      },
                    );
                  }
                  return IconButton(
                    icon: Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                    ),
                    tooltip: '加载提示词中...',
                    onPressed: () {
                      // 如果加载失败，点击重新加载
                      if (promptState is PromptError) {
                        context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
                      }
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _summaryController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '请输入场景大纲或摘要，AI将根据此内容生成完整场景',
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
                suffixIcon: _summaryController.text.isNotEmpty 
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _summaryController.clear();
                          });
                        },
                      )
                    : null,
              ),
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),

          // 风格指令输入
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '风格指令（可选）',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              BlocBuilder<PromptBloc, PromptState>(
                builder: (context, promptState) {
                  if (promptState is PromptLoaded && promptState.stylePrompts.isNotEmpty) {
                    return TextButton.icon(
                      icon: Icon(
                        Icons.style,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: const Text('选择风格'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () {
                        // 弹出风格模板选择对话框
                        _showPromptTemplateSelectionDialog(PromptType.style);
                      },
                    );
                  }
                  return IconButton(
                    icon: Icon(
                      Icons.style_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                    ),
                    tooltip: '加载风格提示词中...',
                    onPressed: () {
                      // 如果加载失败，点击重新加载
                      if (promptState is PromptError) {
                        context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
                      }
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _styleController,
              decoration: InputDecoration(
                hintText: '例如：多对话，少描写，悬疑风格',
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
                suffixIcon: _styleController.text.isNotEmpty 
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18, 
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _styleController.clear();
                          });
                        },
                      )
                    : null,
              ),
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),

          // 章节选择（可选）
          if (state.novel.acts.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '目标章节（可选）',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.activeChapterId != null)
                  TextButton.icon(
                    onPressed: () {
                      // 查找当前章节信息
                      String chapterTitle = "";
                      for (final act in state.novel.acts) {
                        for (final chapter in act.chapters) {
                          if (chapter.id == state.activeChapterId) {
                            chapterTitle = chapter.title;
                            break;
                          }
                        }
                        if (chapterTitle.isNotEmpty) break;
                      }
                      
                      if (chapterTitle.isNotEmpty) {
                        // 添加章节相关信息到摘要
                        final currentText = _summaryController.text;
                        final chapterContext = "本场景为《$chapterTitle》章节的一部分，";
                        if (currentText.isNotEmpty) {
                          _summaryController.text = '$chapterContext$currentText';
                        } else {
                          _summaryController.text = chapterContext;
                        }
                      }
                    },
                    icon: const Icon(Icons.add_box_outlined, size: 16),
                    label: const Text('添加到摘要'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  menuMaxHeight: 300,
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
                            Tooltip(
                              message: '重新生成',
                              child: IconButton(
                                onPressed: () {
                                  // 重新生成内容
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
                                  
                                  // 重置用户滚动标记和编辑标记
                                  _userScrolled = false;
                                  _contentEdited = false;
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                tooltip: '重新生成',
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            Tooltip(
                              message: '复制全文',
                              child: IconButton(
                                onPressed: () => _copyToClipboard(_generatedContentController.text),
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: '复制全文',
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            Tooltip(
                              message: '添加为新场景',
                              child: IconButton(
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
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: TextField(
                              controller: _generatedContentController,
                              scrollController: _scrollController,
                              maxLines: null,
                              expands: true,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                hintText: '生成内容将在这里显示...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
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
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '正在生成中...',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade100.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          '生成失败',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.aiGenerationError ?? "未知错误，请稍后重试",
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
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
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('立即重试'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ] else ...[
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '填写场景摘要，使用AI生成内容',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
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
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('流式生成场景'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                          icon: const Icon(Icons.flash_on, size: 18),
                          label: const Text('快速生成场景'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('取消生成'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Future<void> _generate() async {
    if (_isGenerating) return;

    _resetGenerationState();
    
    setState(() {
      _isGenerating = true;
      _generatedText = '';
    });
  }
}