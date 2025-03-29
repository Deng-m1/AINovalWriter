import 'package:flutter/material.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ModelSelectorDropdown extends StatefulWidget {
  final UserAIModelConfigModel? selectedModel;
  final Function(UserAIModelConfigModel?) onModelSelected;
  final bool compact;

  const ModelSelectorDropdown({
    Key? key,
    required this.onModelSelected,
    this.selectedModel,
    this.compact = true,
  }) : super(key: key);

  @override
  State<ModelSelectorDropdown> createState() => _ModelSelectorDropdownState();
}

class _ModelSelectorDropdownState extends State<ModelSelectorDropdown> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isMenuOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isMenuOpen = false;
  }

  void _toggleMenu(BuildContext context, List<UserAIModelConfigModel> configs, UserAIModelConfigModel? currentSelection) {
    if (_isMenuOpen) {
      _removeOverlay();
    } else {
      _createOverlay(context, configs, currentSelection);
      _isMenuOpen = true;
    }
  }

  void _createOverlay(BuildContext context, List<UserAIModelConfigModel> configs, UserAIModelConfigModel? currentSelection) {
    // 计算菜单的固定高度
    final int itemCount = configs.isEmpty ? 1 : configs.length;
    final double menuHeight = 40.0 * itemCount.clamp(1, 6) + 16.0; // 高度限制在6项内

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 250,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, -menuHeight - 8), // 向上偏移
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            child: Container(
              height: menuHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildMenuItems(configs, currentSelection),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMenuItems(List<UserAIModelConfigModel> configs, UserAIModelConfigModel? currentSelection) {
    if (configs.isEmpty) {
      return const ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
        title: Text('无可用模型', style: TextStyle(fontSize: 13)),
        enabled: false,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
        final isSelected = currentSelection?.id == config.id;
        // 生成显示名称: "[Provider]/[Alias]" 或 "[Provider]/[ModelName]"
        final displayName = "${config.provider}/${config.alias.isNotEmpty ? config.alias : config.modelName}";

        return InkWell(
          onTap: () {
            widget.onModelSelected(config);
            _removeOverlay();
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: isSelected ? Colors.grey.shade100 : null,
            child: Row(
              children: [
                if (config.isDefault)
                  const Icon(Icons.star, size: 14, color: Colors.amber)
                else
                  // 添加一个占位符以保持对齐
                  const SizedBox(width: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    displayName, // 使用生成的显示名称
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.indigo.shade700 : null,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check, size: 14, color: Colors.indigo.shade700),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiConfigBloc, AiConfigState>(
      builder: (context, state) {
        final validatedConfigs = state.validatedConfigs;

        // 确定当前选择的模型
        UserAIModelConfigModel? currentSelection;
        // 1. 优先使用外部传入的 selectedModel，并确保它在验证列表中
        if (widget.selectedModel != null && validatedConfigs.any((c) => c.id == widget.selectedModel!.id)) {
            currentSelection = widget.selectedModel;
        // 2. 其次使用状态中的默认模型，并确保它在验证列表中
        } else if (state.defaultConfig != null && validatedConfigs.any((c) => c.id == state.defaultConfig!.id)) {
            currentSelection = state.defaultConfig;
        // 3. 再次使用验证列表中的第一个模型
        } else if (validatedConfigs.isNotEmpty) {
            currentSelection = validatedConfigs.first;
        // 4. 如果都没有，则为 null
        } else {
            currentSelection = null;
        }

        // --- 加载状态处理 ---
        // 如果正在加载且没有有效的配置显示，显示加载指示器
        if (state.status == AiConfigStatus.loading && validatedConfigs.isEmpty) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        // 如果加载完成但仍然没有验证的模型
        else if (state.status != AiConfigStatus.loading && validatedConfigs.isEmpty) {
           return Text(
             '无可用模型',
             style: TextStyle(
               fontSize: 13,
               fontWeight: FontWeight.w500,
               color: Colors.grey.shade600, // 使用灰色表示不可用
             ),
           );
        }

        // 构建选择器
        return CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            // 只有在有模型可供选择时才允许打开菜单
            onTap: validatedConfigs.isNotEmpty
                ? () => _toggleMenu(context, validatedConfigs, currentSelection)
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getDisplayText(currentSelection), // 使用更新后的函数获取文本
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                    overflow: TextOverflow.ellipsis, // 防止文本过长
                  ),
                  const SizedBox(width: 2),
                  // 只有在有多个模型可选时才显示下拉箭头
                  if (validatedConfigs.length > 1)
                    Icon(
                      _isMenuOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, // 根据菜单状态改变图标
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 更新显示文本的获取逻辑
  String _getDisplayText(UserAIModelConfigModel? model) {
    if (model == null) {
      // 如果没有选中模型（通常意味着没有可用模型）
      return '选择模型'; // 或者 '无可用模型'
    }
    // 优先使用别名，否则使用模型名称
    final namePart = model.alias.isNotEmpty ? model.alias : model.modelName;
    return "${model.provider}/$namePart";
  }
} 