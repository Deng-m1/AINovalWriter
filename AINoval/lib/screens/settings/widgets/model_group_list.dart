import 'package:ainoval/models/ai_model_group.dart';
import 'package:flutter/material.dart';

/// 模型分组列表组件
/// 显示按前缀分组的模型列表，类似CherryStudio的UI
class ModelGroupList extends StatelessWidget {
  const ModelGroupList({
    super.key,
    required this.modelGroup,
    required this.onModelSelected,
    this.selectedModel,
  });

  final AIModelGroup modelGroup;
  final ValueChanged<String> onModelSelected;
  final String? selectedModel;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modelGroup.groups.length,
      itemBuilder: (context, index) {
        final group = modelGroup.groups[index];
        return _buildModelPrefixGroup(context, group);
      },
    );
  }

  Widget _buildModelPrefixGroup(BuildContext context, ModelPrefixGroup group) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ExpansionTile(
      title: Text(
        group.prefix,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
      initiallyExpanded: true, // 默认展开
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      children: group.models.map((model) {
        final isSelected = model == selectedModel;
        return _buildModelItem(context, model, isSelected);
      }).toList(),
    );
  }

  Widget _buildModelItem(BuildContext context, String model, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 提取模型名称，去除前缀
    String displayName = model;
    if (model.contains('/')) {
      displayName = model.split('/').last;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : isDark
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : theme.colorScheme.surfaceContainerLowest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            // 模型图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getModelColor(model),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getModelInitial(model),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 模型名称
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            // 免费标签
            if (model.toLowerCase().contains('free'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '免费',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => onModelSelected(model),
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // 根据模型名称获取颜色
  Color _getModelColor(String model) {
    final modelLower = model.toLowerCase();
    if (modelLower.contains('gpt')) {
      return Colors.green;
    } else if (modelLower.contains('claude')) {
      return Colors.purple;
    } else if (modelLower.contains('gemini')) {
      return Colors.blue;
    } else if (modelLower.contains('llama')) {
      return Colors.orange;
    } else if (modelLower.contains('mistral')) {
      return Colors.red;
    } else if (modelLower.contains('phi')) {
      return Colors.cyan;
    } else if (modelLower.contains('deepseek')) {
      return Colors.indigo;
    } else if (modelLower.contains('google')) {
      return Colors.blue;
    } else if (modelLower.contains('x-ai')) {
      return Colors.black;
    } else {
      // 默认颜色
      return Colors.grey;
    }
  }

  // 获取模型的首字母作为图标
  String _getModelInitial(String model) {
    if (model.contains('/')) {
      // 如果有提供商前缀，使用提供商的首字母
      return model.split('/').first[0].toUpperCase();
    } else if (model.contains('-')) {
      // 如果有连字符，使用第一部分的首字母
      return model.split('-').first[0].toUpperCase();
    } else {
      // 否则使用模型名称的首字母
      return model.isNotEmpty ? model[0].toUpperCase() : '?';
    }
  }
}
