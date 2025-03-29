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

  void _toggleMenu(BuildContext context, List<UserAIModelConfigModel> configs,
      UserAIModelConfigModel? currentSelection) {
    if (_isMenuOpen) {
      _removeOverlay();
    } else {
      _createOverlay(context, configs, currentSelection);
      _isMenuOpen = true;
    }
  }

  void _createOverlay(
      BuildContext context,
      List<UserAIModelConfigModel> configs,
      UserAIModelConfigModel? currentSelection) {
    final itemCount = configs.isEmpty ? 1 : configs.length;
    final double itemHeight = 40.0;
    final double verticalPadding = 8.0;
    final double menuHeight =
        itemHeight * itemCount.clamp(1, 6) + (verticalPadding * 2);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 260,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, -menuHeight - 4),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainer,
            shadowColor: Colors.black.withOpacity(0.1),
            child: Container(
              height: menuHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.5)),
              ),
              child: _buildMenuItems(configs, currentSelection),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMenuItems(List<UserAIModelConfigModel> configs,
      UserAIModelConfigModel? currentSelection) {
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
        final displayName =
            "${config.provider}/${config.alias.isNotEmpty ? config.alias : config.modelName}";

        return InkWell(
          onTap: () {
            widget.onModelSelected(config);
            _removeOverlay();
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3)
                : null,
            child: Row(
              children: [
                if (config.isDefault)
                  Icon(Icons.star_rounded,
                      size: 16, color: Colors.amber.shade600)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded,
                      size: 18, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<AiConfigBloc, AiConfigState>(
      builder: (context, state) {
        final validatedConfigs = state.validatedConfigs;

        UserAIModelConfigModel? currentSelection;
        if (widget.selectedModel != null &&
            validatedConfigs.any((c) => c.id == widget.selectedModel!.id)) {
          currentSelection = widget.selectedModel;
        } else if (state.defaultConfig != null &&
            validatedConfigs.any((c) => c.id == state.defaultConfig!.id)) {
          currentSelection = state.defaultConfig;
        } else if (validatedConfigs.isNotEmpty) {
          currentSelection = validatedConfigs.first;
        } else {
          currentSelection = null;
        }

        if (state.status == AiConfigStatus.loading &&
            validatedConfigs.isEmpty) {
          return const SizedBox(
            height: 24,
            width: 24,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        } else if (state.status != AiConfigStatus.loading &&
            validatedConfigs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
            child: Text(
              '无可用模型',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          );
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            onTap: validatedConfigs.isNotEmpty
                ? () => _toggleMenu(context, validatedConfigs, currentSelection)
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    width: 0.8,
                  )),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _getDisplayText(currentSelection),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (validatedConfigs.length > 1)
                    Icon(
                      _isMenuOpen
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: colorScheme.primary.withOpacity(0.8),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getDisplayText(UserAIModelConfigModel? model) {
    if (model == null) {
      return '选择模型';
    }
    final namePart = model.alias.isNotEmpty ? model.alias : model.modelName;
    return "${model.provider}/$namePart";
  }
}
