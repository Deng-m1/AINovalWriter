import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/blocs/prompt/prompt_template_events.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/screens/settings/widgets/template_permission_indicator.dart';
import 'package:ainoval/screens/settings/widgets/ai_assist_toolbar.dart';
import 'package:ainoval/screens/settings/widgets/optimization_result_view.dart';
import 'package:ainoval/screens/settings/widgets/processing_indicator.dart';

/// 提示词编辑面板
class PromptEditorPanel extends StatefulWidget {
  /// 当前编辑的模板
  final PromptTemplate? template;
  
  /// 是否为新建模板
  final bool isNew;
  
  /// 功能类型（新建模板时使用）
  final AIFeatureType? featureType;
  
  /// 保存成功回调
  final VoidCallback? onSaveSuccess;
  
  /// 取消回调
  final VoidCallback? onCancel;
  
  /// 复制到私有模板回调
  final VoidCallback? onCopyToPrivate;
  
  const PromptEditorPanel({
    Key? key,
    this.template,
    this.isNew = false,
    this.featureType,
    this.onSaveSuccess,
    this.onCancel,
    this.onCopyToPrivate,
  }) : super(key: key);

  @override
  State<PromptEditorPanel> createState() => _PromptEditorPanelState();
}

class _PromptEditorPanelState extends State<PromptEditorPanel> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  bool _isEdited = false;
  bool _isOptimizing = false;
  double _optimizationProgress = 0.0;
  OptimizationResult? _optimizationResult;
  OptimizationStyle _selectedStyle = OptimizationStyle.professional;
  double _preserveRatio = 0.5;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _contentController = TextEditingController(text: widget.template?.content ?? '');
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isPublic = widget.template?.isPublic ?? false;
    final isEditable = !isPublic;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题 - 添加磨砂玻璃效果
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isPublic 
                        ? theme.colorScheme.primary.withOpacity(0.5)
                        : theme.colorScheme.secondary.withOpacity(0.5),
                      isPublic 
                        ? theme.colorScheme.primary.withOpacity(0.3)
                        : theme.colorScheme.secondary.withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isPublic
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : theme.colorScheme.secondary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPublic
                          ? theme.colorScheme.primary.withOpacity(0.2)
                          : theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.isNew ? Icons.add_circle_outline : Icons.edit_note,
                        color: isPublic
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _buildHeader(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isPublic
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 模板权限指示器
          TemplatePermissionIndicator(
            isPublic: isPublic,
            onCopyToPrivate: isPublic ? widget.onCopyToPrivate : null,
          ),
          
          // 编辑器区域
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark 
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.7)
                : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            padding: const EdgeInsets.all(16),
            height: 400,
            child: _buildEditorArea(isEditable),
          ),
          
          // AI辅助工具栏（只有私有模板或新建模板才显示）
          if (isEditable)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: AIAssistToolbar(
                isProcessing: _isOptimizing,
                selectedStyle: _selectedStyle,
                onStyleChanged: _handleStyleChanged,
                preserveRatio: _preserveRatio,
                onRatioChanged: _handleRatioChanged,
                onOptimizeRequested: _handleOptimizeRequest,
              ),
            ),
          
          // 处理指示器
          if (_isOptimizing)
            AnimatedOpacity(
              opacity: _isOptimizing ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: ProcessingIndicator(
                progress: _optimizationProgress,
                onCancel: _cancelOptimization,
              ),
            ),
          
          // 优化结果视图
          if (_optimizationResult != null)
            AnimatedOpacity(
              opacity: _optimizationResult != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: OptimizationResultView(
                original: _contentController.text,
                optimized: _optimizationResult!.optimizedContent,
                sections: _optimizationResult!.sections,
                statistics: _optimizationResult!.statistics,
                onAccept: _acceptOptimization,
                onReject: _rejectOptimization,
                onPartialAccept: _partiallyAcceptOptimization,
              ),
            ),
          
          // 底部操作按钮
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: _buildBottomActions(isEditable),
          ),
          
          const SizedBox(height: 20), // 底部额外空间，防止底部按钮被遮挡
        ],
      ),
    );
  }
  
  /// 构建标题栏
  String _buildHeader() {
    final title = widget.isNew 
        ? '创建提示词模板' 
        : '编辑提示词模板: ${widget.template?.name ?? ""}';
    
    return title;
  }
  
  /// 构建编辑区域
  Widget _buildEditorArea(bool isEditable) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 模板名称输入框
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow.withOpacity(0.5)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '模板名称',
              hintText: '请输入一个描述性的模板名称',
              helperText: '一个好的名称应简洁明了地描述模板的用途',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              enabled: isEditable,
              prefixIcon: const Icon(Icons.title),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              fillColor: isDark
                  ? theme.colorScheme.surfaceContainerLow.withOpacity(0.3)
                  : theme.colorScheme.surface,
              filled: true,
            ),
            onChanged: (_) => setState(() => _isEdited = true),
          ),
        ),
        const SizedBox(height: 16),
        
        // 变量占位符提示
        _buildVariablePlaceholders(),
        const SizedBox(height: 12),
        
        // 内容编辑器
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerLow.withOpacity(0.5)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: '模板内容',
                    hintText: widget.isNew 
                        ? '在此处添加您的提示词模板内容...\n\n提示: 好的模板应该包含明确的指令、适当的变量和足够的上下文信息。'
                        : '编辑模板内容...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    enabled: isEditable,
                    contentPadding: const EdgeInsets.all(16),
                    fillColor: isDark
                        ? theme.colorScheme.surfaceContainerLow.withOpacity(0.3)
                        : theme.colorScheme.surface,
                    filled: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setState(() => _isEdited = true),
                  style: const TextStyle(
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                
                // 如果是新建模板且内容为空，显示引导提示
                if (widget.isNew && _contentController.text.isEmpty)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _buildGuideTip(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// 构建变量占位符提示
  Widget _buildVariablePlaceholders() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final featureType = widget.template?.featureType ?? widget.featureType;
    
    // 根据功能类型提供不同的变量占位符
    List<Map<String, dynamic>> variables = [];
    if (featureType == AIFeatureType.sceneToSummary) {
      variables = [
        {'name': 'scene_content', 'desc': '场景内容', 'icon': Icons.description},
        {'name': 'novel_context', 'desc': '小说上下文', 'icon': Icons.book},
      ];
    } else if (featureType == AIFeatureType.summaryToScene) {
      variables = [
        {'name': 'summary', 'desc': '摘要内容', 'icon': Icons.summarize},
        {'name': 'novel_context', 'desc': '小说上下文', 'icon': Icons.book},
      ];
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                ? [
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    theme.colorScheme.surfaceContainerHigh.withOpacity(0.3),
                  ]
                : [
                    theme.colorScheme.primaryContainer.withOpacity(0.15),
                    theme.colorScheme.primaryContainer.withOpacity(0.05),
                  ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.code,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '可用变量占位符',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: '生成时，变量占位符会被替换为实际内容',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: variables.map((variable) => _buildVariableChip(
                  variable['name'], 
                  variable['desc'],
                  variable['icon'],
                )).toList(),
              ),
              if (variables.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '点击变量插入到编辑器中',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建变量芯片
  Widget _buildVariableChip(String variable, String description, IconData icon) {
    return Tooltip(
      message: description,
      child: InkWell(
        onTap: () {
          // 在光标位置插入变量
          final TextEditingController controller = _contentController;
          final int cursorPos = controller.selection.baseOffset;
          
          if (cursorPos >= 0) {
            final String text = controller.text;
            final String newText = text.substring(0, cursorPos) +
                '{$variable}' +
                text.substring(cursorPos);
            
            controller.text = newText;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: cursorPos + variable.length + 2), // +2 for the curly braces
            );
          } else {
            // 如果光标位置无效，则附加到末尾
            controller.text = controller.text + '{$variable}';
          }
          
          setState(() => _isEdited = true);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '{$variable}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建底部操作按钮
  Widget _buildBottomActions(bool isEditable) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 取消按钮
        OutlinedButton(
          onPressed: widget.onCancel,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          child: const Text('取消'),
        ),
        const SizedBox(width: 16),
        
        // 保存按钮（只有私有模板或新建模板才可用）
        if (isEditable)
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('保存模板'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: _isEdited ? _saveTemplate : null,
          ),
      ],
    );
  }
  
  /// 构建引导提示
  Widget _buildGuideTip() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.9),
            theme.colorScheme.primaryContainer.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '创作提示',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '点击上方的变量标签插入占位符，使用AI辅助工具可以优化您的提示词，让AI生成更符合您期望的内容。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 处理样式变更
  void _handleStyleChanged(OptimizationStyle style) {
    setState(() {
      _selectedStyle = style;
    });
  }
  
  /// 处理保留比例变更
  void _handleRatioChanged(double value) {
    setState(() {
      _preserveRatio = value;
    });
  }
  
  /// 处理优化请求
  void _handleOptimizeRequest() {
    final content = _contentController.text;
    final featureType = widget.template?.featureType ?? widget.featureType;
    
    if (content.isEmpty || featureType == null) {
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模板内容不能为空')),
      );
      return;
    }
    
    final request = OptimizePromptRequest(
      content: content,
      style: _selectedStyle,
      preserveRatio: _preserveRatio,
    );
    
    final templateId = widget.template?.id ?? 'new_template';
    
    setState(() {
      _isOptimizing = true;
      _optimizationProgress = 0.0;
      _optimizationResult = null;
    });
    
    // 调用BLoC流式优化
    context.read<PromptBloc>().add(
      OptimizePromptStreamRequested(
        templateId: templateId,
        request: request,
        onProgress: _updateProgress,
        onResult: _handleOptimizationResult,
        onError: _handleOptimizationError,
      ),
    );
  }
  
  /// 更新优化进度
  void _updateProgress(double progress) {
    if (mounted) {
      setState(() {
        _optimizationProgress = progress;
      });
    }
  }
  
  /// 处理优化结果
  void _handleOptimizationResult(OptimizationResult result) {
    if (mounted) {
      setState(() {
        _isOptimizing = false;
        _optimizationProgress = 1.0;
        _optimizationResult = result;
      });
    }
  }
  
  /// 处理优化错误
  void _handleOptimizationError(String errorMessage) {
    if (mounted) {
      setState(() {
        _isOptimizing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('优化失败: $errorMessage')),
      );
    }
  }
  
  /// 取消优化
  void _cancelOptimization() {
    // 通知BLoC取消优化请求
    context.read<PromptBloc>().add(const CancelOptimizationRequested());
    setState(() {
      _isOptimizing = false;
    });
  }
  
  /// 接受优化结果
  void _acceptOptimization() {
    if (_optimizationResult != null) {
      setState(() {
        _contentController.text = _optimizationResult!.optimizedContent;
        _optimizationResult = null;
        _isEdited = true;
      });
    }
  }
  
  /// 拒绝优化结果
  void _rejectOptimization() {
    setState(() {
      _optimizationResult = null;
    });
  }
  
  /// 部分接受优化
  void _partiallyAcceptOptimization(List<int> acceptedSections) {
    if (_optimizationResult == null) return;
    
    final StringBuffer contentBuilder = StringBuffer();
    
    // 根据选择的区块重建内容
    for (int i = 0; i < _optimizationResult!.sections.length; i++) {
      final section = _optimizationResult!.sections[i];
      
      if (acceptedSections.contains(i)) {
        // 使用优化后的内容
        contentBuilder.write(section.content);
      } else if (section.isModified && section.original != null) {
        // 使用原始内容
        contentBuilder.write(section.original!);
      } else {
        // 使用当前内容（未修改的区块）
        contentBuilder.write(section.content);
      }
    }
    
    // 更新编辑器内容
    _contentController.text = contentBuilder.toString();
    
    // 关闭优化结果视图
    setState(() {
      _optimizationResult = null;
    });
  }
  
  /// 保存模板
  void _saveTemplate() {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();
    
    if (name.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模板名称和内容不能为空')),
      );
      return;
    }
    
    if (widget.isNew) {
      // 创建新模板
      if (widget.featureType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缺少功能类型')),
        );
        return;
      }
      
      context.read<PromptBloc>().add(
        CreatePromptTemplateRequested(
          name: name,
          content: content,
          featureType: widget.featureType!,
        ),
      );
    } else if (widget.template != null) {
      // 更新现有模板
      context.read<PromptBloc>().add(
        UpdatePromptTemplateRequested(
          templateId: widget.template!.id,
          name: name,
          content: content,
        ),
      );
    }
    
    // 通知保存成功
    if (widget.onSaveSuccess != null) {
      widget.onSaveSuccess!();
    }
  }
}

/// 字符串构建器，用于高效拼接字符串
class StringBuilder {
  final StringBuffer _buffer = StringBuffer();
  
  void append(String str) {
    _buffer.write(str);
  }
  
  @override
  String toString() {
    return _buffer.toString();
  }
} 