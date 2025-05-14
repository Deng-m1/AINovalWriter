import 'package:flutter/material.dart';
import 'package:ainoval/models/setting_group.dart';
import 'package:ainoval/utils/logger.dart';

/// 小说设定组对话框
/// 
/// 用于创建或编辑设定组
class NovelSettingGroupDialog extends StatefulWidget {
  final String novelId;
  final SettingGroup? group; // 若为null则表示创建新组
  final Function(SettingGroup) onSave; // 保存回调
  
  const NovelSettingGroupDialog({
    Key? key,
    required this.novelId,
    this.group,
    required this.onSave,
  }) : super(key: key);

  @override
  State<NovelSettingGroupDialog> createState() => _NovelSettingGroupDialogState();
}

class _NovelSettingGroupDialogState extends State<NovelSettingGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // 表单控制器
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 激活状态
  bool _isActiveContext = false;
  
  // 保存状态
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    
    // 若为编辑模式，填充表单
    if (widget.group != null) {
      _nameController.text = widget.group!.name;
      if (widget.group!.description != null) {
        _descriptionController.text = widget.group!.description!;
      }
      if (widget.group!.isActiveContext != null) {
        _isActiveContext = widget.group!.isActiveContext!;
      }
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  // 保存设定组
  Future<void> _saveSettingGroup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // 构建设定组对象
      final settingGroup = SettingGroup(
        id: widget.group?.id,
        novelId: widget.novelId,
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
        isActiveContext: _isActiveContext,
        itemIds: widget.group?.itemIds,
      );
      
      // 调用保存回调
      widget.onSave(settingGroup);
      
      setState(() {
        _isSaving = false;
      });
      
      // 关闭对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.e('NovelSettingGroupDialog', '保存设定组失败', e);
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCreating = widget.group == null;
    
    return AlertDialog(
      title: Text(isCreating ? '创建设定组' : '编辑设定组'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '输入设定组名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入设定组名称';
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
                hintText: '输入设定组描述（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // 激活状态
            Row(
              children: [
                Checkbox(
                  value: _isActiveContext,
                  onChanged: (value) {
                    setState(() {
                      _isActiveContext = value ?? false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '设为活跃上下文',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '活跃上下文中的设定将用于AI生成和提示',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          onPressed: _isSaving ? null : _saveSettingGroup,
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
              : Text(isCreating ? '创建' : '保存'),
        ),
      ],
    );
  }
} 