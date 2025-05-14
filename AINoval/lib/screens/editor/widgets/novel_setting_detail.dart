import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/setting/setting_bloc.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/screens/editor/widgets/novel_setting_relationship_dialog.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/services/api_service/repositories/novel_setting_repository.dart';

/// 小说设定条目详情和编辑组件
class NovelSettingDetail extends StatefulWidget {
  final String? itemId; // 若为null则表示创建新条目
  final String novelId;
  final String? groupId; // 所属设定组ID，可选
  final bool isEditing; // 是否处于编辑模式
  final Function(NovelSettingItem) onSave; // 保存回调
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
  final _contentController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 设定条目数据
  NovelSettingItem? _settingItem;
  
  // 选择的类型
  String? _selectedType;
  
  // 选择的设定组ID
  String? _selectedGroupId;
  
  // 类型选项
  final List<String> _typeOptions = [
    '角色', '地点', '物品', '世界观', '事件', '技能', '组织', '其他'
  ];
  
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
    _contentController.dispose();
    _descriptionController.dispose();
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
    _contentController.text = _settingItem!.content;
    if (_settingItem!.description != null) {
      _descriptionController.text = _settingItem!.description!;
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
      // 构建设定条目对象
      final settingItem = NovelSettingItem(
        id: widget.itemId,
        novelId: widget.novelId,
        name: _nameController.text,
        type: _selectedType,
        content: _contentController.text,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
        relationships: _settingItem?.relationships,
      );
      
      // 调用保存回调
      widget.onSave(settingItem);
      
      // 如果选择了设定组但与传入的不同，添加到该组
      if (_selectedGroupId != null && _selectedGroupId != widget.groupId) {
        // 延迟添加到设定组，确保条目已保存
        Future.delayed(const Duration(milliseconds: 300), () {
          if (settingItem.id != null) {
            context.read<SettingBloc>().add(AddItemToGroup(
              novelId: widget.novelId,
              groupId: _selectedGroupId!,
              itemId: settingItem.id!,
            ));
          }
        });
      }
      
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
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 设定标题和类型区域
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 类型图标
                  _buildLargeTypeIcon(_settingItem!.type ?? '其他'),
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
                            color: _getTypeColor(_settingItem!.type ?? '其他').withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _settingItem!.type ?? '其他',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getTypeColor(_settingItem!.type ?? '其他'),
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
              
              // 描述
              if (_settingItem!.description != null && _settingItem!.description!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '简介',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _settingItem!.description!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                
              const SizedBox(height: 24),
              
              // 内容
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
                      '详细内容',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _settingItem!.content,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                      ),
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
            
            // 描述
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '简要描述',
                hintText: '输入简要描述（可选）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // 内容
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: '详细内容',
                hintText: '输入详细的设定内容',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 12,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入设定内容';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建大型类型图标（用于详情页顶部）
  Widget _buildLargeTypeIcon(String type) {
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
  
  // 构建小型类型图标（用于表单和列表项）
  Widget _buildTypeIcon(String type) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: _getTypeColor(type).withOpacity(0.1),
      child: Icon(
        _getTypeIconData(type),
        size: 14,
        color: _getTypeColor(type),
      ),
    );
  }
  
  // 获取类型图标
  IconData _getTypeIconData(String type) {
    switch (type.toLowerCase()) {
      case '角色':
        return Icons.person;
      case '地点':
        return Icons.place;
      case '物品':
        return Icons.inventory_2;
      case '世界观':
        return Icons.public;
      case '事件':
        return Icons.event;
      case '技能':
        return Icons.auto_awesome;
      case '组织':
        return Icons.groups;
      default:
        return Icons.article;
    }
  }
  
  // 根据类型获取颜色
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case '角色':
        return Colors.blue;
      case '地点':
        return Colors.green;
      case '物品':
        return Colors.orange;
      case '世界观':
        return Colors.purple;
      case '事件':
        return Colors.red;
      case '技能':
        return Colors.teal;
      case '组织':
        return Colors.indigo;
      default:
        return Colors.grey.shade700;
    }
  }
} 