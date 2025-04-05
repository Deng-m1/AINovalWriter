import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Callback type when a config is selected
typedef AiConfigSelectedCallback = void Function(
    UserAIModelConfigModel? selectedConfig);

class AiModelSelector extends StatelessWidget {
  // Allow pre-selecting a config

  const AiModelSelector({
    super.key,
    required this.onConfigSelected,
    this.initialSelection,
  });
  final AiConfigSelectedCallback onConfigSelected;
  final UserAIModelConfigModel? initialSelection;

  // Helper to find the config by ID in the list
  UserAIModelConfigModel? _findConfigById(
      List<UserAIModelConfigModel> configs, String? id) {
    if (id == null) return null;
    return configs.firstWhereOrNull((c) => c.id == id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Assume AiConfigBloc is provided higher up the tree
    return BlocBuilder<AiConfigBloc, AiConfigState>(
      builder: (context, state) {
        final validatedConfigs = state.validatedConfigs;
        // Determine the current selection based on initialSelection or state's default
        UserAIModelConfigModel? currentSelection =
            _findConfigById(validatedConfigs, initialSelection?.id) ??
                state.defaultConfig;

        // Ensure the current selection is actually in the validated list
        if (currentSelection != null &&
            !validatedConfigs.any((c) => c.id == currentSelection!.id)) {
          currentSelection = validatedConfigs.firstWhereOrNull((_) => true);
        }

        if (state.status == AiConfigStatus.loading &&
            validatedConfigs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (validatedConfigs.isEmpty) {
          return const Tooltip(
            message: '前往设置添加或验证模型',
            child: Chip(
              avatar: Icon(Icons.error_outline, color: Colors.orange),
              label: Text('无可用模型'),
            ),
          );
        }

        return DropdownButton<UserAIModelConfigModel>(
          value: currentSelection,
          hint: const Text('选择AI模型'),
          underline: Container(),
          onChanged: (UserAIModelConfigModel? newValue) {
            onConfigSelected(newValue);
          },
          selectedItemBuilder: (BuildContext context) {
            return validatedConfigs.map<Widget>((UserAIModelConfigModel item) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Chip(
                  avatar: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: Text(item.alias,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }).toList();
          },
          items: validatedConfigs.map<DropdownMenuItem<UserAIModelConfigModel>>(
              (UserAIModelConfigModel config) {
            return DropdownMenuItem<UserAIModelConfigModel>(
              value: config,
              child: Row(
                children: [
                  Text(config.alias),
                  if (config.isDefault)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.star, size: 14, color: Colors.amber),
                    ),
                  const Spacer(),
                  Text(
                    '(${config.provider})',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// TODO: Add localization strings to .arb files:
// - manageConfigsTooltip: '前往设置添加或验证模型'
// - noValidatedConfigsFound: '无可用模型'
// - selectAiModelHint: '选择AI模型'
