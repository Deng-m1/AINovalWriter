import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/prompt_models.dart';

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
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '提示词管理',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '管理AI生成功能的提示词模板，提升AI生成效果',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              
              // 标签栏
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '预设提示词'),
                  Tab(text: '模板库'),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
              
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 预设提示词标签页
                    _buildPromptSettingsTab(context, state),
                    
                    // 模板库标签页
                    _buildTemplateLibraryTab(context, state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// 构建提示词设置标签页
  Widget _buildPromptSettingsTab(BuildContext context, PromptState state) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 功能类型选择
          _buildFeatureTypeSelector(context, state),
          const SizedBox(height: 16),
          
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
    );
  }
  
  /// 构建模板库标签页
  Widget _buildTemplateLibraryTab(BuildContext context, PromptState state) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类选项卡
          Row(
            children: [
              _buildCategoryButton(
                context, 
                '摘要模板', 
                true, 
                () {/* 暂时不需要处理点击事件 */},
              ),
              const SizedBox(width: 8),
              _buildCategoryButton(
                context, 
                '风格模板', 
                false, 
                () {/* 暂时不需要处理点击事件 */},
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 模板列表
          Expanded(
            child: _buildPromptTemplateList(context, state),
          ),
          
          // 添加按钮
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加模板'),
                  onPressed: () => _showAddPromptTemplateDialog(context, PromptType.summary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建分类按钮
  Widget _buildCategoryButton(
    BuildContext context,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
        const SizedBox(height: 8),
        
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
            const SizedBox(width: 16),
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
          borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primaryContainer 
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isSelected 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
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
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '提示词编辑',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            
            // 自定义状态指示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCustomized 
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustomized ? Icons.edit : Icons.lock_outline,
                    size: 14,
                    color: isCustomized 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCustomized ? '已自定义' : '系统默认',
                    style: TextStyle(
                      fontSize: 13,
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
        const SizedBox(height: 12),
        
        // 提示词文本编辑器
        Expanded(
          child: TextField(
            controller: _promptController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2.0,
                ),
              ),
              hintText: '请输入提示词',
              helperText: '为AI生成提供指导性的提示词，控制生成的风格和内容。可以插入模板或自定义。',
              helperStyle: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
              helperMaxLines: 2,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) {
              setState(() => _isEdited = true);
            },
          ),
        ),
        const SizedBox(height: 16),
        
        // 模板选择区域
        _buildTemplateSelector(context, state),
        const SizedBox(height: 20),
        
        // 操作按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 重置按钮
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重置'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // 弹出确认对话框
                _showResetConfirmationDialog(context, state);
              },
            ),
            const SizedBox(width: 16),
            // 保存按钮
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('保存'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
  
  /// 构建模板选择器
  Widget _buildTemplateSelector(BuildContext context, PromptState state) {
    final selectedType = state.selectedFeatureType;
    
    // 根据选择的功能类型选择合适的提示词模板列表
    final templates = selectedType == AIFeatureType.sceneToSummary
        ? state.summaryPrompts // 摘要模板
        : state.stylePrompts;   // 风格模板
    
    if (templates.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '快速模板',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40, // 增加高度
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final template = templates[index];
              return ActionChip(
                label: Text(template.title),
                avatar: const Icon(Icons.insert_drive_file_outlined, size: 16),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: () {
                  // 插入模板内容到编辑器
                  _promptController.text = template.content;
                  setState(() => _isEdited = true);
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  /// 构建提示词模板列表
  Widget _buildPromptTemplateList(BuildContext context, PromptState state) {
    final summaryPrompts = state.summaryPrompts;
    
    if (summaryPrompts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notes_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无提示词模板',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加模板',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      itemCount: summaryPrompts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final template = summaryPrompts[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
              child: const Icon(Icons.description_outlined),
            ),
            title: Text(
              template.title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                template.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '编辑',
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    // 编辑模板
                    _showEditPromptTemplateDialog(context, template);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除',
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    // 删除模板
                    _showDeleteTemplateConfirmationDialog(context, template);
                  },
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () {
              // 查看模板详情
              _showTemplateDetailDialog(context, template);
            },
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
      builder: (context) => AlertDialog(
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
                context.read<PromptBloc>().add(
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
      ),
    );
  }
  
  /// 显示编辑提示词模板对话框
  void _showEditPromptTemplateDialog(BuildContext context, PromptItem template) {
    final titleController = TextEditingController(text: template.title);
    final contentController = TextEditingController(text: template.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                context.read<PromptBloc>().add(DeletePromptTemplateRequested(template.id));
                context.read<PromptBloc>().add(
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
} 