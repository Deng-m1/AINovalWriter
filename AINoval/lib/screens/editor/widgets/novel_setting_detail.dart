import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/setting/setting_bloc.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/models/setting_type.dart'; // 导入设定类型枚举
import 'package:ainoval/screens/editor/widgets/novel_setting_relationship_dialog.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/services/api_service/repositories/novel_setting_repository.dart';

/// 小说设定条目详情和编辑组件
class NovelSettingDetail extends StatefulWidget {
  final String? itemId; // 若为null则表示创建新条目
  final String novelId;
  final String? groupId; // 所属设定组ID，可选
  final bool isEditing; // 是否处于编辑模式
  final Function(NovelSettingItem, String?) onSave; // 保存回调，第二个参数为所选组ID
  final VoidCallback onCancel; // 取消回调
  
  const NovelSettingDetail({
    Key? key,
    this.itemId,
    required this.novelId,
    this.groupId,
    this.isEditing = false,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<NovelSettingDetail> createState() => _NovelSettingDetailState();
}

class _NovelSettingDetailState extends State<NovelSettingDetail> {
  final _formKey = GlobalKey<FormState>();
  
  // 表单控制器
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 新增：标签控制器
  final _tagsController = TextEditingController();
  
  // 新增：属性列表
  final List<MapEntry<String, String>> _attributes = [];
  
  // 设定条目数据
  NovelSettingItem? _settingItem;
  
  // 选择的类型
  String? _selectedType;
  
  // 选择的设定组ID
  String? _selectedGroupId;
  
  // 类型选项 - 使用枚举获取
  late final List<String> _typeOptions = SettingType.values
      .map((type) => type.displayName)
      .toList();
  
  // 加载状态
  bool _isLoading = true;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.itemId != null) {
      _loadSettingItem();
    } else {
      // 创建新条目
      setState(() {
        _isLoading = false;
        _selectedType = _typeOptions[0]; // 默认选第一个类型
      });
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }
  
  // 加载设定条目详情
  Future<void> _loadSettingItem() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 从SettingBloc中查找设定条目
      final settingBloc = context.read<SettingBloc>();
      final state = settingBloc.state;
      
      // 如果当前状态中有该条目，直接使用
      if (state.items.isNotEmpty) {
        final itemIndex = state.items.indexWhere((item) => item.id == widget.itemId);
        if (itemIndex >= 0) {
          _settingItem = state.items[itemIndex];
          _initializeForm();
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      // 如果Bloc中找不到数据，则请求详细数据
      try {
        final settingRepository = context.read<NovelSettingRepository>();
        final item = await settingRepository.getSettingItemDetail(
          novelId: widget.novelId,
          itemId: widget.itemId!,
        );
        
        _settingItem = item;
        
        // 添加到bloc状态中
        if (!state.items.any((existingItem) => existingItem.id == item.id)) {
          settingBloc.add(UpdateSettingItem(
            novelId: widget.novelId,
            itemId: item.id!,
            item: item,
          ));
        }
      } catch (e) {
        AppLogger.e('NovelSettingDetail', '从API加载设定条目详情失败', e);
        // 如果API请求也失败，使用默认值
        _settingItem = NovelSettingItem(
          id: widget.itemId,
          novelId: widget.novelId,
          name: "加载失败",
          type: "其他",
          content: "无法加载该设定条目数据",
        );
      }
      
      // 初始化表单
      _initializeForm();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e('NovelSettingDetail', '加载设定条目详情失败', e);
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 初始化表单
  void _initializeForm() {
    if (_settingItem == null) return;
    
    _nameController.text = _settingItem!.name;
    _descriptionController.text = (_settingItem!.description ?? _settingItem!.content)!;
    
    // 初始化标签
    if (_settingItem!.tags != null && _settingItem!.tags!.isNotEmpty) {
      _tagsController.text = _settingItem!.tags!.join(', ');
    }
    
    // 初始化属性
    _attributes.clear();
    if (_settingItem!.attributes != null) {
      _attributes.addAll(_settingItem!.attributes!.entries.toList());
    }
    
    _selectedType = _settingItem!.type;
    _selectedGroupId = widget.groupId; // 如果有传入groupId，将其设为默认选择
  }
  
  // 保存设定条目
  Future<void> _saveSettingItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // 获取选择的类型枚举
      final typeEnum = _getTypeEnumFromDisplayName(_selectedType ?? '其他');
      
      // 处理标签
      List<String>? tags;
      if (_tagsController.text.isNotEmpty) {
        tags = _tagsController.text.split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
      
      // 转换属性为Map
      Map<String, String>? attributes;
      if (_attributes.isNotEmpty) {
        attributes = Map.fromEntries(_attributes);
      }
      
      // 构建设定条目对象
      final settingItem = NovelSettingItem(
        id: widget.itemId,
        novelId: widget.novelId,
        type: typeEnum.value, // 保存value值而不是displayName
        name: _nameController.text,
        content: "",
        description: _descriptionController.text,
        attributes: attributes,
        tags: tags,
        relationships: _settingItem?.relationships,
        generatedBy: _settingItem?.generatedBy,
        imageUrl: _settingItem?.imageUrl,
        sceneIds: _settingItem?.sceneIds,
        priority: _settingItem?.priority,
        status: _settingItem?.status,
        isAiSuggestion: _settingItem?.isAiSuggestion ?? false,
      );
      
      // 记录所选的组ID
      final String? selectedGroupId = _selectedGroupId ?? widget.groupId;
      
      AppLogger.i('NovelSettingDetail', 
        '保存设定条目: ${settingItem.name}, 类型: ${typeEnum.value}, ' 
        '选择的组ID: ${selectedGroupId ?? "无"}'
      );
      
      // 调用保存回调，将设定条目和选择的组ID传递给父组件处理
      widget.onSave(settingItem, selectedGroupId);
      
      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      AppLogger.e('NovelSettingDetail', '保存设定条目失败', e);
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  // 添加关系
  void _addRelationship() {
    if (_settingItem == null || _settingItem!.id == null) return;
    
    final availableItems = context.read<SettingBloc>().state.items
        .where((item) => item.id != _settingItem!.id)
        .toList();
    
    if (availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可用的设定条目来建立关系'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final settingBloc = context.read<SettingBloc>(); // Capture the BLoC

    showDialog(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: settingBloc, // Provide the existing BLoC instance
          child: NovelSettingRelationshipDialog(
            novelId: widget.novelId,
            sourceItemId: _settingItem!.id!,
            sourceName: _settingItem!.name,
            availableTargets: availableItems,
            onSave: (relationType, targetItemId, description) {
              settingBloc.add(AddSettingRelationship( // Use captured BLoC instance
                novelId: widget.novelId,
                itemId: _settingItem!.id!,
                targetItemId: targetItemId,
                relationshipType: relationType,
                description: description,
              ));
            },
          ),
        );
      },
    );
  }
  
  // 删除关系
  void _deleteRelationship(String targetItemId, String relationshipType) {
    if (_settingItem == null || _settingItem!.id == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个关系吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SettingBloc>().add(RemoveSettingRelationship(
                novelId: widget.novelId,
                itemId: _settingItem!.id!,
                targetItemId: targetItemId,
                relationshipType: relationshipType,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final isCreating = widget.itemId == null;
    final isViewing = !widget.isEditing && !isCreating;
    
    return Material(
      color: Colors.white,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部操作栏
            _buildAppBar(theme, isCreating, isViewing),
            
            // 内容区域
            Expanded(
              child: isViewing 
                  ? _buildViewMode(theme) 
                  : _buildEditForm(theme),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建顶部操作栏
  Widget _buildAppBar(ThemeData theme, bool isCreating, bool isViewing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
            onPressed: () {
              widget.onCancel();
            },
          ),
          const SizedBox(width: 8),
          
          // 标题
          Expanded(
            child: Text(
              isCreating 
                  ? '新建设定条目' 
                  : isViewing 
                      ? _settingItem?.name ?? ''
                      : '编辑设定条目',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          
          // 操作按钮
          if (isViewing)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      // 切换到编辑模式
                      // 注意：这里应该调用外部传入的编辑模式切换函数
                      // 临时修复：刷新当前页面
                    });
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('编辑'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () {
                    // 显示更多操作菜单
                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(1000, 0, 0, 0),
                      items: [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              const Text('删除', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ).then((value) {
                      if (value == 'delete' && _settingItem != null) {
                        // 删除设定条目
                        context.read<SettingBloc>().add(DeleteSettingItem(
                          novelId: widget.novelId,
                          itemId: _settingItem!.id!,
                        ));
                        widget.onCancel(); // 返回列表
                      }
                    });
                  },
                ),
              ],
            ),
          
          if (!isViewing)
            Row(
              children: [
                OutlinedButton(
                  onPressed: _isSaving ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettingItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: _isSaving 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  // 构建查看模式
  Widget _buildViewMode(ThemeData theme) {
    if (_settingItem == null) {
      return const Center(
        child: Text('设定条目不存在'),
      );
    }
    
    return BlocBuilder<SettingBloc, SettingState>(
      builder: (context, state) {
        // 从bloc获取最新的条目数据，确保显示最新状态
        final currentItem = state.items.firstWhere(
          (item) => item.id == _settingItem!.id,
          orElse: () => _settingItem!,
        );
        
        // 输出调试信息
        AppLogger.i('NovelSettingDetail', 
          '构建设定条目详情: id=${currentItem.id}, name=${currentItem.name}, '
          '关系数量=${currentItem.relationships?.length ?? 0}, '
          '总条目数量=${state.items.length}');
        
        if (currentItem.relationships != null) {
          for (var rel in currentItem.relationships!) {
            final targetItem = state.items.firstWhere(
              (item) => item.id == rel.targetItemId,
              orElse: () => NovelSettingItem(id: rel.targetItemId, name: "未知条目", content: ""),
            );
            AppLogger.i('NovelSettingDetail', '关系: type=${rel.type}, targetId=${rel.targetItemId}, targetName=${targetItem.name}');
          }
        }
        
        // 更新本地缓存的设定条目数据
        if (currentItem.id != null && currentItem.id == _settingItem!.id) {
          _settingItem = currentItem;
        }
        
        // 获取条目类型的枚举
        final settingTypeEnum = SettingType.fromValue(_settingItem!.type ?? 'OTHER');
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 设定标题和类型区域
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 类型图标 - 直接使用枚举
                  _buildLargeTypeIcon(settingTypeEnum),
                  const SizedBox(width: 16),
                  
                  // 条目详情信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 类型标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTypeColor(settingTypeEnum).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            settingTypeEnum.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getTypeColor(settingTypeEnum),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // 名称
                        Text(
                          _settingItem!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 生成方式标签（如果有）
              if (_settingItem!.generatedBy != null && _settingItem!.generatedBy!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Text(
                      '由 ${_settingItem!.generatedBy} 生成',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ),
              
              // 描述部分（统一后的）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '描述',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _settingItem!.description ?? _settingItem!.content!,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 显示属性（如果有）
              if (_settingItem!.attributes != null && _settingItem!.attributes!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '属性',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _settingItem!.attributes!.entries.map((entry) {
                          return Chip(
                            label: Text(
                              '${entry.key}: ${entry.value}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              
              // 显示标签（如果有）
              if (_settingItem!.tags != null && _settingItem!.tags!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '标签',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _settingItem!.tags!.map((tag) {
                          return Chip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // 关系部分
              if (_settingItem!.relationships != null && _settingItem!.relationships!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '关系',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _addRelationship,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('添加关系'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 显示关系列表
                    ..._settingItem!.relationships!.map((relationship) {
                      // 查找目标条目名称
                      final targetItem = context.read<SettingBloc>().state.items
                          .firstWhere(
                            (item) => item.id == relationship.targetItemId,
                            orElse: () => NovelSettingItem(
                              id: relationship.targetItemId,
                              name: "未知条目",
                              content: "",
                            ),
                          );
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      relationship.type,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      _deleteRelationship(
                                        relationship.targetItemId,
                                        relationship.type,
                                      );
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 目标条目
                              Row(
                                children: [
                                  _buildTypeIcon(targetItem.type ?? '其他'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      targetItem.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (relationship.description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    relationship.description!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '关系',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addRelationship,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('添加关系'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
  
  // 构建编辑表单
  Widget _buildEditForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型选择
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: '类型',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: null,
              ),
              items: _typeOptions.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      _buildTypeIcon(type),
                      const SizedBox(width: 8),
                      Text(type),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // 设定组选择
            BlocBuilder<SettingBloc, SettingState>(
              builder: (context, state) {
                final groups = state.groups;
                
                return DropdownButtonFormField<String?>(
                  value: _selectedGroupId,
                  decoration: InputDecoration(
                    labelText: '所属设定组',
                    hintText: '选择设定组（可选）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: null,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('不属于任何设定组'),
                    ),
                    ...groups.map((group) {
                      return DropdownMenuItem<String?>(
                        value: group.id,
                        child: Row(
                          children: [
                            const Icon(Icons.folder, size: 16),
                            const SizedBox(width: 8),
                            Text(group.name),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupId = value;
                    });
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // 名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '名称',
                hintText: '输入设定条目名称',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入设定条目名称';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 描述（合并后的）
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '描述',
                hintText: '输入设定描述',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入设定描述';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 标签输入
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: '标签',
                hintText: '输入标签，用逗号分隔（例如：魔法, 神秘, 古代）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 属性编辑
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '属性',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('添加属性'),
                      onPressed: () {
                        _showAddAttributeDialog(context);
                      },
                    ),
                  ],
                ),
                
                if (_attributes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '暂无属性，点击"添加属性"按钮添加',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _attributes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final attribute = _attributes[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  attribute.key,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Text(': '),
                              Expanded(
                                flex: 3,
                                child: Text(attribute.value),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _attributes.removeAt(index);
                              });
                            },
                            tooltip: '删除',
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 添加属性对话框
  void _showAddAttributeDialog(BuildContext context) {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加属性'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: '属性名',
                  hintText: '例如：年龄、身高、能力值',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入属性名';
                  }
                  if (_attributes.any((attr) => attr.key == value)) {
                    return '属性名已存在';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: '属性值',
                  hintText: '例如：18、175cm、高级',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入属性值';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _attributes.add(MapEntry(keyController.text, valueController.text));
                });
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
  
  // 构建大型类型图标（用于详情页顶部） - 直接接收枚举
  Widget _buildLargeTypeIcon(SettingType type) {
    final iconData = _getTypeIconData(type);
    final iconColor = _getTypeColor(type);
    
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        iconData,
        size: 32,
        color: iconColor,
      ),
    );
  }
  
  // 构建小型类型图标（用于表单和列表项） - 接收中文名或枚举
  Widget _buildTypeIcon(dynamic type) {
    final SettingType typeEnum = type is SettingType ? type : _getTypeEnumFromDisplayName(type);
    return CircleAvatar(
      radius: 14,
      backgroundColor: _getTypeColor(typeEnum).withOpacity(0.1),
      child: Icon(
        _getTypeIconData(typeEnum),
        size: 14,
        color: _getTypeColor(typeEnum),
      ),
    );
  }
  
  // 获取类型枚举
  SettingType _getTypeEnumFromDisplayName(String displayName) {
    return SettingType.values.firstWhere(
      (type) => type.displayName == displayName,
      orElse: () => SettingType.other,
    );
  }
  
  // 获取类型图标
  IconData _getTypeIconData(SettingType type) {
    switch (type) {
      case SettingType.character:
        return Icons.person;
      case SettingType.location:
        return Icons.place;
      case SettingType.item:
        return Icons.inventory_2;
      case SettingType.lore:
        return Icons.public;
      case SettingType.event:
        return Icons.event;
      case SettingType.concept:
        return Icons.auto_awesome;
      case SettingType.faction:
        return Icons.groups;
      case SettingType.creature:
        return Icons.pets;
      case SettingType.magicSystem:
        return Icons.auto_fix_high;
      case SettingType.technology:
        return Icons.science;
      default:
        return Icons.article;
    }
  }
  
  // 根据类型获取颜色
  Color _getTypeColor(SettingType type) {
    switch (type) {
      case SettingType.character:
        return Colors.blue;
      case SettingType.location:
        return Colors.green;
      case SettingType.item:
        return Colors.orange;
      case SettingType.lore:
        return Colors.purple;
      case SettingType.event:
        return Colors.red;
      case SettingType.concept:
        return Colors.teal;
      case SettingType.faction:
        return Colors.indigo;
      case SettingType.creature:
        return Colors.brown;
      case SettingType.magicSystem:
        return Colors.cyan;
      case SettingType.technology:
        return Colors.blueGrey;
      default:
        return Colors.grey.shade700;
    }
  }
} 