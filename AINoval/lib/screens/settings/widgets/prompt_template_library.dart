import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/blocs/prompt/prompt_template_events.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/config/app_config.dart';

/// 提示词模板库组件
class PromptTemplateLibrary extends StatefulWidget {
  /// 当点击复制到私有模板时的回调
  final Function(PromptTemplate)? onCopyToPrivate;
  
  /// 当点击查看模板时的回调
  final Function(PromptTemplate)? onView;
  
  /// 当点击编辑模板时的回调
  final Function(PromptTemplate)? onEdit;
  
  /// 当点击删除模板时的回调
  final Function(PromptTemplate)? onDelete;
  
  /// 当切换收藏状态时的回调
  final Function(PromptTemplate)? onToggleFavorite;
  
  /// 当创建新模板时的回调
  final Function(AIFeatureType)? onCreateNew;
  
  const PromptTemplateLibrary({
    Key? key,
    this.onCopyToPrivate,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onToggleFavorite,
    this.onCreateNew,
  }) : super(key: key);

  @override
  State<PromptTemplateLibrary> createState() => _PromptTemplateLibraryState();
}

class _PromptTemplateLibraryState extends State<PromptTemplateLibrary> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AIFeatureType _selectedFeatureType = AIFeatureType.sceneToSummary;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 加载提示词模板
    context.read<PromptBloc>().add(const LoadPromptTemplatesRequested());
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PromptBloc, PromptState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和搜索栏
            _buildHeader(context),
            
            // 功能类型选择器
            _buildFeatureTypeSelector(context),
            
            const SizedBox(height: 12),
            
            // 标签栏
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '公共模板'),
                Tab(text: '我的模板'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelPadding: const EdgeInsets.symmetric(vertical: 8.0),
            ),
            
            // 标签内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 公共模板列表
                  _buildTemplateList(
                    context, 
                    state, 
                    isPublic: true,
                  ),
                  
                  // 私有模板列表
                  _buildTemplateList(
                    context, 
                    state, 
                    isPublic: false,
                  ),
                ],
              ),
            ),
            
            // 添加按钮区域
            if (!state.isLoading) _buildBottomActions(context),
          ],
        );
      },
    );
  }
  
  /// 构建标题和搜索栏
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '提示词模板库',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        // 搜索栏
        SizedBox(
          width: 200,
          height: 36,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索模板',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
      ],
    );
  }
  
  /// 构建功能类型选择器
  Widget _buildFeatureTypeSelector(BuildContext context) {
    return Row(
      children: [
        _buildFeatureTypeChip(
          context, 
          AIFeatureType.sceneToSummary, 
          '场景摘要提示词', 
          Icons.summarize,
        ),
        const SizedBox(width: 8),
        _buildFeatureTypeChip(
          context, 
          AIFeatureType.summaryToScene, 
          '场景生成提示词', 
          Icons.description,
        ),
      ],
    );
  }
  
  /// 构建功能类型选择芯片
  Widget _buildFeatureTypeChip(
    BuildContext context, 
    AIFeatureType featureType, 
    String label, 
    IconData icon,
  ) {
    final isSelected = _selectedFeatureType == featureType;
    
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected 
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected 
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFeatureType = featureType);
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
  
  /// 构建模板列表
  Widget _buildTemplateList(
    BuildContext context, 
    PromptState state, 
    {required bool isPublic}
  ) {
    // 获取当前用户ID
    final currentUserId = AppConfig.userId;
    
    // 根据公共/私有和功能类型筛选模板
    final templates = state.promptTemplates.where((template) => 
      template.isPublic == isPublic && 
      template.featureType == _selectedFeatureType &&
      (
        _searchQuery.isEmpty || 
        template.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        template.content.toLowerCase().contains(_searchQuery.toLowerCase())
      )
    ).toList();
    
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isPublic ? '暂无公共模板' : '暂无私有模板',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: templates.length,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateCard(context, template, isPublic, currentUserId);
      },
    );
  }
  
  /// 构建模板卡片
  Widget _buildTemplateCard(
    BuildContext context, 
    PromptTemplate template, 
    bool isPublic,
    String? currentUserId,
  ) {
    final theme = Theme.of(context);
    final bool isEditable = !isPublic && template.authorId == currentUserId;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPublic 
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPublic ? Icons.public : Icons.lock_outlined,
                  size: 16,
                  color: isPublic 
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPublic 
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                    ),
                  ),
                ),
                if (template.isVerified)
                  Tooltip(
                    message: '官方认证模板',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.verified,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                if (!isPublic)
                  IconButton(
                    icon: Icon(
                      template.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: template.isFavorite ? Colors.red : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: template.isFavorite ? '取消收藏' : '收藏',
                    onPressed: () {
                      if (widget.onToggleFavorite != null) {
                        widget.onToggleFavorite!(template);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          
          // 内容预览
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              template.content,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 底部操作栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPublic)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('复制到我的模板'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      if (widget.onCopyToPrivate != null) {
                        widget.onCopyToPrivate!(template);
                      }
                    },
                  )
                else if (isEditable) ...[
                  // 编辑按钮
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: '编辑',
                    onPressed: () {
                      if (widget.onEdit != null) {
                        widget.onEdit!(template);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16),
                    tooltip: '删除',
                    onPressed: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!(template);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                // 查看按钮
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  tooltip: '查看',
                  onPressed: () {
                    if (widget.onView != null) {
                      widget.onView!(template);
                    }
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建底部操作区域
  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('创建模板'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              // 调试信息
              print('点击创建模板按钮，选中类型: $_selectedFeatureType, 回调存在: ${widget.onCreateNew != null}');
              
              // 跳转到当前用户的私有模板标签页
              _tabController.animateTo(1);
              
              // 如果提供了创建新模板的回调，则调用它
              if (widget.onCreateNew != null) {
                print('准备调用onCreateNew回调，featureType: $_selectedFeatureType');
                widget.onCreateNew!(_selectedFeatureType);
                return;
              }
              
              // 如果没有回调，则显示提示对话框
              _showCreateTemplateDialog(context);
            },
          ),
        ],
      ),
    );
  }
  
  /// 显示创建模板对话框
  void _showCreateTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新模板'),
        content: const Text('请在模板编辑器中创建新模板'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
} 