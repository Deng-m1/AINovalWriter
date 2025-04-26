import 'package:ainoval/models/ai_model_group.dart';
import 'package:ainoval/models/model_info.dart';
import 'package:flutter/material.dart';

/// 模型分组列表组件
/// 显示按前缀分组的模型列表，类似CherryStudio的UI
class ModelGroupList extends StatelessWidget {
  const ModelGroupList({
    super.key,
    required this.modelGroup,
    required this.onModelSelected,
    this.selectedModel,
    this.verifiedModels = const [], // 添加已验证模型参数
  });

  final AIModelGroup modelGroup;
  final ValueChanged<String> onModelSelected;
  final String? selectedModel;
  final List<String> verifiedModels; // 已验证模型列表

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

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent, // 移除分割线
      ),
      child: ExpansionTile(
        title: Text(
          group.prefix,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: theme.colorScheme.onSurface.withOpacity(0.7),
        initiallyExpanded: true, // 默认展开
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 4, top: 0),
        children: group.modelsInfo.map((modelInfo) {
          final isSelected = modelInfo.id == selectedModel;
          final isVerified = verifiedModels.contains(modelInfo.id);
          return _buildModelItem(context, modelInfo, isSelected, isVerified);
        }).toList(),
      ),
    );
  }

  Widget _buildModelItem(BuildContext context, ModelInfo modelInfo, bool isSelected, bool isVerified) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use modelInfo.name for display, fallback to modelInfo.id
    String displayName = modelInfo.name.isNotEmpty ? modelInfo.name : modelInfo.id;
    // Optional: Further cleanup display name if needed (e.g., remove provider prefix if present in name)
    // if (displayName.startsWith(modelInfo.provider + '/')) { 
    //   displayName = displayName.substring(modelInfo.provider.length + 1);
    // }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : isDark
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.2)
                : theme.colorScheme.surfaceContainerLowest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.1),
          width: isSelected ? 1.0 : 0.5,
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            // 模型图标 - Use modelInfo.id for color/initials
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getModelColor(modelInfo.id),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getModelInitial(modelInfo.id),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 模型名称 - Use displayName
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 已验证标记
            if (isVerified)
              Tooltip(
                message: '已验证模型',
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green,
                ),
              ),
            const SizedBox(width: 4),
            // 免费标签 - Use modelInfo.id
            if (modelInfo.id.toLowerCase().contains('free'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '免费',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => onModelSelected(modelInfo.id),
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // 根据模型 ID 获取颜色
  Color _getModelColor(String modelId) {
    final modelLower = modelId.toLowerCase();
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
  String _getModelInitial(String modelId) {
    if (modelId.contains('/')) {
      // 如果有提供商前缀，使用提供商的首字母
      return modelId.split('/').first[0].toUpperCase();
    } else if (modelId.contains('-')) {
      // 如果有连字符，使用第一部分的首字母
      return modelId.split('-').first[0].toUpperCase();
    } else {
      // 否则使用模型名称的首字母
      return modelId.isNotEmpty ? modelId[0].toUpperCase() : '?';
    }
  }
}
