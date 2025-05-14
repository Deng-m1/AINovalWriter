import 'package:flutter/material.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/utils/logger.dart';

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
      // TODO: 调用仓储层方法加载设定条目详情
      // _settingItem = await settingRepository.getSettingItemDetail(
      //   novelId: widget.novelId,
      //   itemId: widget.itemId!,
      // );
      
      // MOCK DATA FOR UI DEVELOPMENT
      _settingItem = NovelSettingItem(
        id: widget.itemId,
        novelId: widget.novelId,
        name: "主角",
        type: "角色",
        content: "主角是一个19岁的大学生，性格开朗，家境普通。他有着敏锐的观察力和超强的记忆力，这让他在推理方面有着天赋。在一次偶然的机会下，他卷入了一个连环凶杀案，并开始了他的侦探之旅。",
        description: "小说的主要角色",
      );
      
      // 填充表单
      _nameController.text = _settingItem!.name;
      _contentController.text = _settingItem!.content;
      if (_settingItem!.description != null) {
        _descriptionController.text = _settingItem!.description!;
      }
      _selectedType = _settingItem!.type;
      
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
      );
      
      // 调用保存回调
      widget.onSave(settingItem);
      
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
    
    return Material( // 添加Material组件作为整个设定详情的父组件
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
                    // TODO: 实现编辑功能
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
                    // TODO: 实现更多操作菜单
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型标签
          if (_settingItem!.type != null)
            Chip(
              label: Text(_settingItem!.type!),
              backgroundColor: _getTypeColor(_settingItem!.type!).withOpacity(0.1),
              labelStyle: TextStyle(
                color: _getTypeColor(_settingItem!.type!),
                fontSize: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          
          const SizedBox(height: 12),
          
          // 描述
          if (_settingItem!.description != null)
            Text(
              _settingItem!.description!,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
            
          const SizedBox(height: 16),
          
          // 内容
          Text(
            _settingItem!.content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 关系部分
          if (_settingItem!.relationships != null && _settingItem!.relationships!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '关系',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 显示关系列表
                ..._settingItem!.relationships!.map((relationship) {
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
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                relationship.type,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '目标ID: ${relationship.targetItemId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          if (relationship.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
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
            ),
        ],
      ),
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
            // 名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '输入设定条目名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入设定条目名称';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 类型
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '类型',
                border: OutlineInputBorder(),
              ),
              items: _typeOptions.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // 描述
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '简要描述',
                hintText: '输入简要描述（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // 内容
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '详细内容',
                hintText: '输入详细的设定内容',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入设定内容';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // 关系管理部分
            if (widget.itemId != null) // 只在编辑已有条目时显示关系管理
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '关系管理',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          // TODO: 实现添加关系功能
                        },
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
                  
                  // 关系列表
                  if (_settingItem?.relationships != null && _settingItem!.relationships!.isNotEmpty)
                    ..._settingItem!.relationships!.map((relationship) {
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
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      relationship.type,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (relationship.description != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
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
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: Colors.red,
                                splashRadius: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                                onPressed: () {
                                  // TODO: 实现删除关系功能
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList()
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '暂无关系',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
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