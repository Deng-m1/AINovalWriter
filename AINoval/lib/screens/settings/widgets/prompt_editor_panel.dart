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

class _PromptEditorPanelState extends State<PromptEditorPanel> with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  bool _isEdited = false;
  bool _isOptimizing = false;
  double _optimizationProgress = 0.0;
  OptimizationResult? _optimizationResult;
  OptimizationStyle _selectedStyle = OptimizationStyle.professional;
  double _preserveRatio = 0.5;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _contentController = TextEditingController(text: widget.template?.content ?? '');
    
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 300),
      value: 0.0,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _animationController.forward();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationController.isAnimating && _animationController.value < 1.0) {
      _animationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(PromptEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template != widget.template || 
        oldWidget.isNew != widget.isNew || 
        oldWidget.featureType != widget.featureType) {
      _animationController.reset();
      _animationController.forward();
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isPublic = widget.template?.isPublic ?? false;
    final isEditable = !isPublic;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 简洁标题栏
                _buildHeader(isPublic, theme),
                
                const SizedBox(height: 16),
                
                // 模板权限指示器 - 简化为行内元素
                if (isPublic)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildPermissionIndicator(isPublic),
                  ),
                
                // 编辑区域 - 更紧凑的布局
                Expanded(
                  child: _buildCompactEditorArea(isEditable, theme, isDark),
                ),
                
                // 处理指示器
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: AnimatedOpacity(
                    opacity: _isOptimizing ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isOptimizing 
                      ? ProcessingIndicator(
                          progress: _optimizationProgress,
                          onCancel: _cancelOptimization,
                        )
                      : const SizedBox.shrink(),
                  ),
                ),
                
                // 优化结果视图
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: AnimatedOpacity(
                    opacity: _optimizationResult != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _optimizationResult != null
                      ? OptimizationResultView(
                          original: _contentController.text,
                          optimized: _optimizationResult!.optimizedContent,
                          sections: _optimizationResult!.sections,
                          statistics: _optimizationResult!.statistics,
                          onAccept: _acceptOptimization,
                          onReject: _rejectOptimization,
                          onPartialAccept: _partiallyAcceptOptimization,
                        )
                      : const SizedBox.shrink(),
                  ),
                ),
                
                // 底部操作按钮 - 更简洁的设计
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: _buildBottomActions(isEditable, theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 简洁的标题栏
  Widget _buildHeader(bool isPublic, ThemeData theme) {
    final title = widget.isNew 
        ? '创建提示词模板' 
        : '编辑提示词模板';
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(
            widget.isNew ? Icons.add_circle_outline : Icons.edit_note,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 简化的权限指示器
  Widget _buildPermissionIndicator(bool isPublic) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock_outline,
            size: 16,
            color: isPublic
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            isPublic ? '公共模板 · 只读' : '私有模板 · 可编辑',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isPublic
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
            ),
          ),
          const Spacer(),
          if (isPublic)
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('复制到私有模板'),
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: Size.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: widget.onCopyToPrivate,
            ),
        ],
      ),
    );
  }
  
  /// 更紧凑的编辑区域
  Widget _buildCompactEditorArea(bool isEditable, ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模板名称输入
            _buildNameInput(isEditable, theme),
            
            const SizedBox(height: 20),
            
            // 变量占位符 - 更紧凑的设计
            _buildCompactVariablePlaceholders(),
            
            const SizedBox(height: 16),
            
            // 内容编辑器
            Expanded(
              child: _buildContentEditor(isEditable, theme, isDark),
            ),

            // AI辅助工具栏（只有私有模板或新建模板才显示）
            if (isEditable)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: AIAssistToolbar(
                  isProcessing: _isOptimizing,
                  selectedStyle: _selectedStyle,
                  onStyleChanged: _handleStyleChanged,
                  preserveRatio: _preserveRatio,
                  onRatioChanged: _handleRatioChanged,
                  onOptimizeRequested: _handleOptimizeRequest,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// 模板名称输入
  Widget _buildNameInput(bool isEditable, ThemeData theme) {
    return TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '模板名称',
              labelStyle: TextStyle(
                color: isEditable 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
          fontSize: 14,
              ),
        hintText: '请输入模板名称',
              border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
              enabled: isEditable,
              prefixIcon: Icon(
                Icons.title,
                color: isEditable 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          size: 18,
              ),
            ),
            style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
      onChanged: (_) => setState(() => _isEdited = true),
    );
  }
  
  /// 更紧凑的变量占位符
  Widget _buildCompactVariablePlaceholders() {
    final theme = Theme.of(context);
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
    } else {
      variables = [
        {'name': 'input', 'desc': '输入内容', 'icon': Icons.input},
        {'name': 'context', 'desc': '上下文信息', 'icon': Icons.book},
      ];
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                '变量占位符',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: variables.map((variable) => _buildCompactVariableChip(
              variable['name'], 
              variable['desc'],
              variable['icon'],
            )).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 紧凑的变量芯片
  Widget _buildCompactVariableChip(String variable, String description, IconData icon) {
    final theme = Theme.of(context);
    
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
            controller.text = controller.text + '{$variable}';
          }
          
          setState(() => _isEdited = true);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '{$variable}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 内容编辑器
  Widget _buildContentEditor(bool isEditable, ThemeData theme, bool isDark) {
    return TextField(
      controller: _contentController,
      decoration: InputDecoration(
        labelText: '模板内容',
        alignLabelWithHint: true,
        labelStyle: TextStyle(
          color: isEditable 
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        hintText: widget.isNew 
            ? '在此处添加您的提示词模板内容...\n\n提示: 好的模板应该包含明确的指令、适当的变量和足够的上下文信息。'
            : '编辑模板内容...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.all(12),
        enabled: isEditable,
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      onChanged: (_) => setState(() => _isEdited = true),
      style: TextStyle(
        height: 1.5,
        fontSize: 14,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
  
  /// 构建底部操作按钮
  Widget _buildBottomActions(bool isEditable, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 取消按钮
          OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // 保存按钮（只有私有模板或新建模板才可用）
          if (isEditable)
            FilledButton(
              onPressed: _isEdited ? _saveTemplate : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: theme.colorScheme.primary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.save, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '保存模板',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('模板内容不能为空'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(8),
        ),
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
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('优化失败: $errorMessage'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(8),
        ),
      );
    }
  }
  
  /// 取消优化
  void _cancelOptimization() {
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('优化内容已应用'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(8),
          duration: const Duration(seconds: 2),
        ),
      );
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
      _isEdited = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Text('部分优化内容已应用'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// 保存模板
  void _saveTemplate() {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();
    
    if (name.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('模板名称和内容不能为空'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(8),
        ),
      );
      return;
    }
    
    if (widget.isNew) {
      // 创建新模板
      if (widget.featureType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Text('缺少功能类型'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(8),
          ),
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