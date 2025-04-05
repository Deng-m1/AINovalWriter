import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart'; // For date formatting

class AiConfigListItem extends StatelessWidget {
  // Indicate if an action is pending for this item (optional, for finer control)

  const AiConfigListItem({
    super.key,
    required this.config,
    required this.onEdit,
    required this.onDelete,
    required this.onValidate,
    required this.onSetDefault,
    this.isLoading = false, // Default to false
  });
  final UserAIModelConfigModel config;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onValidate;
  final VoidCallback onSetDefault;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disabledColor = theme.disabledColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    config.alias,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (config.isDefault)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Chip(
                      label: const Text('默认', style: TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.green.shade100,
                      labelStyle:
                          TextStyle(color: Colors.green.shade900, fontSize: 10),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red))),
                  ],
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.more_vert),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${config.provider} / ${config.modelName}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.textTheme.bodySmall?.color),
            ),
            if (config.apiEndpoint != null && config.apiEndpoint!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Endpoint: ${config.apiEndpoint}',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  config.isValidated ? Icons.check_circle : Icons.error_outline,
                  color: config.isValidated
                      ? Colors.green
                      : (config.validationError != null
                          ? Colors.orange
                          : Colors.grey),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    config.isValidated
                        ? '已验证'
                        : (config.validationError ?? '未验证'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: config.isValidated
                          ? Colors.green
                          : (config.validationError != null
                              ? Colors.orange
                              : Colors.grey),
                      fontStyle: config.isValidated
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (!config.isValidated && config.validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 22),
                child: Text(
                  config.validationError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '更新于: ${DateFormat.yMd().add_jm().format(config.updatedAt.toLocal())}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const Divider(height: 16, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!config.isValidated)
                  TextButton.icon(
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('验证'),
                    onPressed: isLoading ? null : onValidate,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.secondary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (config.isValidated && !config.isDefault)
                  TextButton.icon(
                    icon: const Icon(Icons.star_border, size: 16),
                    label: const Text('设为默认'),
                    onPressed: isLoading ? null : onSetDefault,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
