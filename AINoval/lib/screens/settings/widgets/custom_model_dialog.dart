import 'package:flutter/material.dart';

/// 自定义模型输入对话框
/// 允许用户手动输入不在预定义列表中的模型信息
class CustomModelDialog extends StatefulWidget {
  /// 提供商名称
  final String providerName;
  
  /// 确认添加回调
  final Function(String modelName, String modelAlias, String? apiEndpoint) onConfirm;
  
  const CustomModelDialog({
    Key? key,
    required this.providerName,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<CustomModelDialog> createState() => _CustomModelDialogState();
}

class _CustomModelDialogState extends State<CustomModelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _modelNameController = TextEditingController();
  final _modelAliasController = TextEditingController();
  final _apiEndpointController = TextEditingController();

  @override
  void dispose() {
    _modelNameController.dispose();
    _modelAliasController.dispose();
    _apiEndpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('添加自定义${widget.providerName}模型'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请输入您想添加的${widget.providerName}模型信息',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              
              // 模型名称输入框
              TextFormField(
                controller: _modelNameController,
                decoration: InputDecoration(
                  labelText: '模型名称 *',
                  hintText: '例如: gpt-4-vision-preview',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入模型名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // 模型别名输入框
              TextFormField(
                controller: _modelAliasController,
                decoration: InputDecoration(
                  labelText: '模型别名 *',
                  hintText: '例如: GPT-4 Vision',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入模型别名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // API Endpoint输入框
              TextFormField(
                controller: _apiEndpointController,
                decoration: InputDecoration(
                  labelText: 'API Endpoint (可选)',
                  hintText: '例如: https://api.openai.com/v1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                // API Endpoint是可选的，不需要验证
              ),
              
              const SizedBox(height: 8),
              Text(
                '* 表示必填字段',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.error,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onConfirm(
                _modelNameController.text.trim(),
                _modelAliasController.text.trim(),
                _apiEndpointController.text.trim().isEmpty ? null : _apiEndpointController.text.trim(),
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('确认添加'),
        ),
      ],
    );
  }
} 