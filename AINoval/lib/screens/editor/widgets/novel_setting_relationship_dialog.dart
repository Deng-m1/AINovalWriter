import 'package:flutter/material.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/utils/logger.dart';

/// 小说设定条目关系对话框
/// 
/// 用于创建条目之间的关系
class NovelSettingRelationshipDialog extends StatefulWidget {
  final String novelId;
  final String sourceItemId; // 源条目ID
  final String sourceName; // 源条目名称，用于显示
  final List<NovelSettingItem> availableTargets; // 可选的目标条目
  final Function(String, String, String?) onSave; // 保存回调(关系类型, 目标条目ID, 描述)
  
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
  String? _selectedRelationType;
  
  // 常见关系类型
  final List<String> _relationTypes = [
    '父子关系', '包含关系', '拥有者', '对立面', '相似', '起源', '影响', '依赖', '朋友', '敌人', '同盟', '隶属', '其他'
  ];
  
  // 保存状态
  bool _isSaving = false;
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  
  // 保存关系
  Future<void> _saveRelationship() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // 调用保存回调
      widget.onSave(
        _selectedRelationType!,
        _selectedTargetId!,
        _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      );
      
      setState(() {
        _isSaving = false;
      });
      
      // 关闭对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.e('NovelSettingRelationshipDialog', '保存关系失败', e);
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('添加关系'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 源条目显示
            Text(
              '从: ${widget.sourceName}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 关系类型选择
            DropdownButtonFormField<String>(
              value: _selectedRelationType,
              decoration: const InputDecoration(
                labelText: '关系类型',
                hintText: '选择关系类型',
                border: OutlineInputBorder(),
              ),
              items: _relationTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRelationType = value;
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
            
            // 目标条目选择
            DropdownButtonFormField<String>(
              value: _selectedTargetId,
              decoration: const InputDecoration(
                labelText: '目标条目',
                hintText: '选择目标条目',
                border: OutlineInputBorder(),
              ),
              items: widget.availableTargets
                  .where((item) => item.id != widget.sourceItemId) // 排除源条目自身
                  .map((item) {
                return DropdownMenuItem<String>(
                  value: item.id,
                  child: Text('${item.name} (${item.type ?? "未分类"})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTargetId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请选择目标条目';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 描述
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '关系描述（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
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
              : const Text('添加'),
        ),
      ],
    );
  }
} 