import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/blocs/prompt/prompt_template_events.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/screens/settings/widgets/prompt_template_library.dart';
import 'package:ainoval/screens/settings/widgets/prompt_editor_panel.dart';
import 'package:ainoval/screens/settings/widgets/template_permission_indicator.dart';
import 'package:ainoval/config/app_config.dart';
import 'package:flutter/rendering.dart';

/// 提示词管理面板
class PromptManagementPanel extends StatefulWidget {
  const PromptManagementPanel({Key? key}) : super(key: key);

  @override
  State<PromptManagementPanel> createState() => _PromptManagementPanelState();
}

class _PromptManagementPanelState extends State<PromptManagementPanel> with SingleTickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  late TabController _tabController;
  bool _isEdited = false;
  
  // 当前编辑的模板
  PromptTemplate? _currentEditingTemplate;
  
  // 是否处于编辑模板模式
  bool _isEditingTemplate = false;
  
  // 是否是新建模板
  bool _isNewTemplate = false;
  
  // 新建模板的功能类型
  AIFeatureType? _newTemplateFeatureType;
  
  @override
  void initState() {
    super.initState();
    // 初始化标签控制器
    _tabController = TabController(length: 2, vsync: this);
    // 加载所有提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
    // 加载提示词模板
    context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
  }
  
  @override
  void dispose() {
    _promptController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PromptBloc, PromptState>(
      listener: (context, state) {
        // 当选择了提示词类型时，更新编辑器内容
        if (state.selectedPrompt != null && !_isEdited) {
          _promptController.text = state.selectedPrompt!.activePrompt;
        }
        
        // 显示错误信息
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return Container(
          constraints: const BoxConstraints(maxHeight: 670),
          child: ListView(
            shrinkWrap: true,
            children: [
              // 标题区域 - 添加磨砂玻璃效果
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                theme.colorScheme.primaryContainer.withOpacity(0.6),
                                theme.colorScheme.primaryContainer.withOpacity(0.4),
                              ]
                            : [
                                theme.colorScheme.primaryContainer.withOpacity(0.8),
                                theme.colorScheme.primaryContainer.withOpacity(0.6),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 24,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '提示词管理',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '管理AI生成功能的提示词模板，提升AI生成效果',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 如果正在编辑模板，显示返回按钮
              if (_isEditingTemplate)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('返回模板库'),
                    onPressed: _cancelTemplateEditing,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // 内容区域
              if (!_isEditingTemplate)
                Container(
                  height: 500, // 固定高度约束
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surface,
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
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // 标签栏 - 玻璃效果
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.7)
                                  : theme.colorScheme.surfaceContainerLowest.withOpacity(0.7),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(text: '预设提示词'),
                                Tab(text: '模板库'),
                              ],
                              labelColor: theme.colorScheme.primary,
                              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                              indicatorColor: theme.colorScheme.primary,
                              indicatorSize: TabBarIndicatorSize.label,
                              indicatorWeight: 3,
                              labelPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              dividerColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                      
                      // TabBarView内容
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // 预设提示词标签页
                            _buildPromptSettingsTab(context, state),
                            
                            // 模板库标签页 - 使用新组件
                            PromptTemplateLibrary(
                              onCopyToPrivate: _handleCopyToPrivate,
                              onView: _handleViewTemplate,
                              onEdit: _handleEditTemplate,
                              onDelete: _handleDeleteTemplate,
                              onToggleFavorite: _handleToggleFavorite,
                              onCreateNew: _createNewTemplate,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                // 模板编辑区域
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 550,
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PromptEditorPanel(
                      template: _currentEditingTemplate,
                      isNew: _isNewTemplate,
                      featureType: _newTemplateFeatureType,
                      onSaveSuccess: _handleTemplateSaveSuccess,
                      onCancel: _cancelTemplateEditing,
                      onCopyToPrivate: _handleCopyCurrentToPrivate,
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  /// 构建提示词设置标签页
  Widget _buildPromptSettingsTab(BuildContext context, PromptState state) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 650, // 调整高度与模板编辑区域保持一致
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 功能类型选择
            _buildFeatureTypeSelector(context, state),
            const SizedBox(height: 8),
            
            // 提示词编辑区域
            if (state.selectedFeatureType != null) ...[
              Expanded(child: _buildPromptEditor(context, state)),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text('请选择一个功能类型'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 构建功能类型选择区域
  Widget _buildFeatureTypeSelector(BuildContext context, PromptState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '功能类型',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4), // 减小间距
        
        // 功能类型选择卡片
        Row(
          children: [
            _buildFeatureTypeCard(
              context,
              AIFeatureType.sceneToSummary,
              '场景生成摘要',
              '根据场景内容自动生成摘要',
              Icons.summarize,
              state.selectedFeatureType == AIFeatureType.sceneToSummary,
            ),
            const SizedBox(width: 12), // 减小间距
            _buildFeatureTypeCard(
              context,
              AIFeatureType.summaryToScene,
              '摘要生成场景',
              '根据摘要生成完整场景内容',
              Icons.description,
              state.selectedFeatureType == AIFeatureType.summaryToScene,
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建功能类型选择卡片
  Widget _buildFeatureTypeCard(
    BuildContext context,
    AIFeatureType featureType,
    String title,
    String description,
    IconData icon,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isSelected ? 2 : 0, // 选中时有阴影
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            context.read<PromptBloc>().add(SelectFeatureRequested(featureType));
            setState(() => _isEdited = false);
          },
          child: Padding(
            padding: const EdgeInsets.all(12), // 减小内边距
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6), // 减小内边距
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primaryContainer 
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.onSurfaceVariant,
                        size: 16, // 减小图标尺寸
                      ),
                    ),
                    const SizedBox(width: 8), // 减小间距
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // 减小间距
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建提示词编辑区域
  Widget _buildPromptEditor(BuildContext context, PromptState state) {
    final selectedPrompt = state.selectedPrompt;
    final isCustomized = selectedPrompt?.isCustomized ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 顶部区域：标题和状态指示
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '提示词编辑',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            
            // 自定义状态指示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 减小内边距
              decoration: BoxDecoration(
                color: isCustomized 
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustomized ? Icons.edit : Icons.lock_outline,
                    size: 12, // 减小图标尺寸
                    color: isCustomized 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCustomized ? '已自定义' : '系统默认',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCustomized ? FontWeight.w500 : FontWeight.normal,
                      color: isCustomized 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8), // 减小间距
        
        // 中间区域：编辑器和模板选择并排显示
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：提示词编辑区域
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 可用变量占位符指示 - 改为更紧凑的单行设计
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '可用变量:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _buildVariablePlaceholders(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8), // 减小间距
                    
                    // 提示词文本编辑器
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontSize: 14, // 减小字体大小
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          hintText: '请输入提示词',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.all(12), // 减小内边距
                          isDense: true, // 使内容更紧凑
                        ),
                        onChanged: (_) {
                          setState(() => _isEdited = true);
                        },
                      ),
                    ),
                    // 移除helper text，使用更紧凑的设计
                    const SizedBox(height: 4),
                    Text(
                      '为AI生成提供指导性的提示词，控制生成风格和内容',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12), // 减小间距
              
              // 右侧：模板选择区域
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '快速模板',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6), // 减小间距
                    
                    // 模板列表 - 确保可滚动
                    Expanded(
                      child: _buildTemplateList(context, state),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12), // 减小间距
        
        // 底部区域：操作按钮 - 更紧凑
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 重置按钮
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重置'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                // 弹出确认对话框
                _showResetConfirmationDialog(context, state);
              },
            ),
            const SizedBox(width: 12), // 减小间距
            // 保存按钮
            FilledButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('保存'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                if (state.selectedFeatureType != null) {
                  context.read<PromptBloc>().add(
                    SavePromptRequested(
                      state.selectedFeatureType!,
                      _promptController.text,
                    ),
                  );
                  setState(() => _isEdited = false);
                  
                  // 显示保存成功提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('提示词已保存'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建变量占位符标签
  List<Widget> _buildVariablePlaceholders(BuildContext context) {
    // 根据当前选择的功能类型显示不同的占位符
    final selectedType = context.read<PromptBloc>().state.selectedFeatureType;
    
    List<String> variables = [];
    
    // 根据不同功能类型提供不同的占位符
    if (selectedType == AIFeatureType.sceneToSummary) {
      variables = ['input', 'context']; // 场景生成摘要变量
    } else if (selectedType == AIFeatureType.summaryToScene) {
      variables = ['input', 'context']; // 摘要生成场景变量
    }
    
    return variables.map((variable) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: () {
            // 在光标位置插入变量
            final TextEditingController controller = _promptController;
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.code,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '{$variable}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
  
  /// 构建模板列表
  Widget _buildTemplateList(BuildContext context, PromptState state) {
    final selectedType = state.selectedFeatureType;
    
    // 根据选择的功能类型选择合适的提示词模板列表
    final templates = selectedType == AIFeatureType.sceneToSummary
        ? state.summaryPrompts // 摘要模板
        : state.stylePrompts;   // 风格模板
    
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 36, // 减小图标尺寸
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 8), // 减小间距
            Text(
              '暂无可用模板',
              style: TextStyle(
                fontSize: 12, // 减小字体大小
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    // 使用ListView.builder确保模板列表可滚动
    return ListView.builder(
      itemCount: templates.length,
      padding: EdgeInsets.zero, // 去除内边距
      shrinkWrap: false, // 确保可以滚动
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6), // 减小边距
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.7),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              // 应用模板内容到编辑器
              _promptController.text = template.content;
              setState(() => _isEdited = true);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已应用模板: ${template.title}'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onLongPress: () {
              // 长按查看模板详情
              _showTemplateDetailDialog(context, template);
            },
            child: Padding(
              padding: const EdgeInsets.all(8), // 减小内边距
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 14, // 减小图标尺寸
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6), // 减小间距
                      Expanded(
                        child: Text(
                          template.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13, // 减小字体大小
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4), // 减小间距
                  Text(
                    template.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12, // 减小字体大小
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 显示重置确认对话框
  void _showResetConfirmationDialog(BuildContext context, PromptState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('确定要恢复为系统默认提示词吗？自定义内容将会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (state.selectedFeatureType != null) {
                context.read<PromptBloc>().add(
                  ResetPromptRequested(state.selectedFeatureType!),
                );
                setState(() => _isEdited = false);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示添加提示词模板对话框
  void _showAddPromptTemplateDialog(BuildContext context, PromptType type) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(type == PromptType.summary ? '添加摘要提示词模板' : '添加风格提示词模板'),
            content: SizedBox(
              width: 600, // 增加宽度
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '模板名称',
                        hintText: '输入一个简短的名称',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLength: 20,
                    ),
                    const SizedBox(height: 20),
                    
                    // 可用变量占位符
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '可用变量占位符',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildTemplateVariableChip(context, 'input', '输入内容', contentController),
                              _buildTemplateVariableChip(context, 'context', '上下文信息', contentController),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击上方变量插入到模板内容中，生成时会被替换为实际内容',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: contentController,
                      decoration: InputDecoration(
                        labelText: '模板内容',
                        hintText: type == PromptType.summary 
                            ? '输入摘要提示词内容' 
                            : '输入风格提示词内容',
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 12, // 增加行数
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                    // 添加提示词模板
                    this.context.read<PromptBloc>().add(
                      AddPromptTemplateRequested(
                        title: titleController.text,
                        content: contentController.text,
                        type: type,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// 显示编辑提示词模板对话框
  void _showEditPromptTemplateDialog(BuildContext context, PromptItem template) {
    final titleController = TextEditingController(text: template.title);
    final contentController = TextEditingController(text: template.content);
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('编辑提示词模板'),
            content: SizedBox(
              width: 600, // 增加宽度
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '模板名称',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLength: 20,
                    ),
                    const SizedBox(height: 20),
                    
                    // 可用变量占位符
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '可用变量占位符',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildTemplateVariableChip(context, 'input', '输入内容', contentController),
                              _buildTemplateVariableChip(context, 'context', '上下文信息', contentController),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击上方变量插入到模板内容中，生成时会被替换为实际内容',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        labelText: '模板内容',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      maxLines: 12, // 增加行数
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                    // 这里应该有更新模板的操作，但目前Bloc中缺少此功能
                    // 先删除旧模板，再添加新模板作为临时解决方案
                    this.context.read<PromptBloc>().add(DeletePromptTemplateRequested(template.id));
                    this.context.read<PromptBloc>().add(
                      AddPromptTemplateRequested(
                        title: titleController.text,
                        content: contentController.text,
                        type: template.type,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// 构建模板变量芯片（带有指定的文本控制器）
  Widget _buildTemplateVariableChip(BuildContext context, String variable, String description, TextEditingController controller) {
    return Tooltip(
      message: description,
      child: InkWell(
        onTap: () {
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
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.code,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '{$variable}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 显示删除模板确认对话框
  void _showDeleteTemplateConfirmationDialog(BuildContext context, PromptItem template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除提示词模板"${template.title}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<PromptBloc>().add(DeletePromptTemplateRequested(template.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  /// 显示模板详情对话框
  void _showTemplateDetailDialog(BuildContext context, PromptItem template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                template.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    template.content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.content_paste),
            label: const Text('应用'),
            onPressed: () {
              // 应用模板内容到当前编辑器
              if (context.read<PromptBloc>().state.selectedFeatureType != null) {
                _promptController.text = template.content;
                setState(() => _isEdited = true);
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已应用模板: ${template.title}'),
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

  /// 构建模板变量提示组件
  Widget _buildTemplateVariableTips(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '可用变量占位符',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildVariableChip(context, 'input', '输入内容'),
              _buildVariableChip(context, 'context', '上下文信息'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '点击上方变量插入到模板内容中，生成时会被替换为实际内容',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建变量芯片
  Widget _buildVariableChip(BuildContext context, String variable, String description) {
    return Tooltip(
      message: description,
      child: InkWell(
        onTap: () {
          // 尝试通过上下文获取当前获取焦点的文本编辑器
          final FocusNode? focusNode = FocusManager.instance.primaryFocus;
          if (focusNode != null && focusNode.context != null) {
            final widget = focusNode.context!.widget;
            if (widget is EditableText) {
              final TextEditingController controller = widget.controller;
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
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.code,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '{$variable}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理复制到私有模板
  void _handleCopyToPrivate(PromptTemplate template) {
    // 调用BLoC复制模板
    context.read<PromptBloc>().add(
      CopyPublicTemplateRequested(templateId: template.id),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到私有模板')),
    );
  }
  
  /// 处理查看模板
  void _handleViewTemplate(PromptTemplate template) {
    setState(() {
      _currentEditingTemplate = template;
      _isEditingTemplate = true;
      _isNewTemplate = false;
    });
  }
  
  /// 处理编辑模板
  void _handleEditTemplate(PromptTemplate template) {
    setState(() {
      _currentEditingTemplate = template;
      _isEditingTemplate = true;
      _isNewTemplate = false;
    });
  }
  
  /// 处理删除模板
  void _handleDeleteTemplate(PromptTemplate template) {
    // 弹出确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除模板"${template.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 调用BLoC删除模板
              this.context.read<PromptBloc>().add(
                DeleteTemplateRequested(templateId: template.id),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  /// 处理模板收藏状态切换
  void _handleToggleFavorite(PromptTemplate template) {
    context.read<PromptBloc>().add(
      ToggleTemplateFavoriteRequested(templateId: template.id),
    );
  }
  
  /// 取消模板编辑
  void _cancelTemplateEditing() {
    setState(() {
      _isEditingTemplate = false;
      _currentEditingTemplate = null;
      _isNewTemplate = false;
      _newTemplateFeatureType = null;
    });
  }
  
  /// 处理模板保存成功
  void _handleTemplateSaveSuccess() {
    setState(() {
      _isEditingTemplate = false;
      _currentEditingTemplate = null;
      _isNewTemplate = false;
      _newTemplateFeatureType = null;
    });
    
    // 刷新模板列表
    context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
  }
  
  /// 处理复制当前显示的模板到私有模板
  void _handleCopyCurrentToPrivate() {
    if (_currentEditingTemplate != null && _currentEditingTemplate!.isPublic) {
      context.read<PromptBloc>().add(
        CopyPublicTemplateRequested(templateId: _currentEditingTemplate!.id),
      );
      
      // 复制后取消编辑模式
      setState(() {
        _isEditingTemplate = false;
        _currentEditingTemplate = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到私有模板')),
      );
    }
  }
  
  /// 创建新模板
  void _createNewTemplate(AIFeatureType featureType) {
    setState(() {
      _isEditingTemplate = true;
      _isNewTemplate = true;
      _currentEditingTemplate = null;
      _newTemplateFeatureType = featureType;
    });
  }
} 