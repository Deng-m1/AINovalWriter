import 'package:flutter/material.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/models/setting_type.dart'; // 导入设定类型枚举
import 'package:ainoval/utils/logger.dart';

/// 小说设定条目关系对话框
/// 
/// 用于创建条目之间的关系
class NovelSettingRelationshipDialog extends StatefulWidget {
  final String novelId;
  final String sourceItemId; // 源条目ID
  final String sourceName; // 源条目名称，用于显示
  final List<NovelSettingItem> availableTargets; // 可选的目标条目
  final Function(String relationType, String targetItemId, String? description) onSave; // 保存回调(关系类型, 目标条目ID, 描述)
  
  const NovelSettingRelationshipDialog({
    Key? key,
    required this.novelId,
    required this.sourceItemId,
    required this.sourceName,
    required this.availableTargets,
    required this.onSave,
  }) : super(key: key);

  @override
  State<NovelSettingRelationshipDialog> createState() => _NovelSettingRelationshipDialogState();
}

class _NovelSettingRelationshipDialogState extends State<NovelSettingRelationshipDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // 表单控制器
  final _descriptionController = TextEditingController();
  
  // 选中的目标条目
  String? _selectedTargetId;
  
  // 关系类型
  String? _relationType;
  
  // 常见关系类型
  final List<String> _relationTypes = [
    '朋友', '敌人', '亲戚', '同伴', '主从', '师徒', '恋人', 
    '位于', '拥有', '使用', '创造', '参与', '影响', 
    '属于', '领导', '成员', '其他'
  ];
  
  // 保存状态
  bool _isSaving = false;
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  
  // 保存关系
  void _saveRelationship() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      
      // 调用保存回调
      widget.onSave(
        _relationType!,
        _selectedTargetId!,
        _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      );
      
      Navigator.of(context).pop();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 5,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '添加设定关系',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // 源条目信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '源设定条目:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.sourceName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 关系类型
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '关系类型',
                  border: OutlineInputBorder(),
                ),
                value: _relationType,
                items: _relationTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _relationType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请选择关系类型';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 目标条目
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '目标设定条目',
                  border: OutlineInputBorder(),
                ),
                value: _selectedTargetId,
                items: widget.availableTargets.map((target) {
                  // 使用SettingType枚举显示类型
                  final typeEnum = SettingType.fromValue(target.type ?? 'OTHER');
                  return DropdownMenuItem<String>(
                    value: target.id,
                    child: Row(
                      children: [
                        _buildTypeIcon(typeEnum),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            target.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTargetId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请选择目标设定条目';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 描述
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '关系描述 (可选)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveRelationship,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
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
        ),
      ),
    );
  }
  
  // 构建类型图标
  Widget _buildTypeIcon(SettingType type) {
    final Color iconColor = _getTypeColor(type);
    return CircleAvatar(
      radius: 12,
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(
        _getTypeIconData(type),
        size: 12,
        color: iconColor,
      ),
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