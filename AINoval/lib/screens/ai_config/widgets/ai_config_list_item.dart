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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface.withAlpha(255),
              isDark
                ? theme.colorScheme.surfaceContainerHighest.withAlpha(255)
                : theme.colorScheme.surfaceContainerLowest.withAlpha(255),
            ],
          ),
          border: Border.all(
            color: isDark
              ? Colors.white.withAlpha(13) // 0.05 opacity
              : Colors.black.withAlpha(13), // 0.05 opacity
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                ? Colors.black.withAlpha(51) // 0.2 opacity
                : Colors.black.withAlpha(13), // 0.05 opacity
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    config.alias,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (config.isDefault)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                          ? Colors.green.withAlpha(51) // 0.2 opacity
                          : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13), // 0.05 opacity
                            blurRadius: 2,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Text('默认',
                        style: TextStyle(
                          color: isDark ? Colors.green.shade300 : Colors.green.shade900,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                  ? theme.colorScheme.surfaceContainerHighest.withAlpha(77) // 0.3 opacity
                  : theme.colorScheme.surfaceContainerLowest.withAlpha(128), // 0.5 opacity
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${config.provider} / ${config.modelName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                    ? theme.colorScheme.onSurface.withAlpha(230) // 0.9 opacity
                    : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (config.apiEndpoint != null && config.apiEndpoint!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.link,
                      size: 14,
                      color: theme.colorScheme.onSurface.withAlpha(128)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        config.apiEndpoint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(179), // 0.7 opacity
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: config.isValidated
                  ? (isDark ? Colors.green.withAlpha(26) : Colors.green.withAlpha(13)) // 0.1/0.05 opacity
                  : (isDark ? Colors.grey.withAlpha(26) : Colors.grey.withAlpha(13)), // 0.1/0.05 opacity
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: config.isValidated
                      ? Colors.green.withAlpha(77) // 0.3 opacity
                      : Colors.grey.withAlpha(77), // 0.3 opacity
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    config.isValidated ? Icons.check_circle : Icons.error_outline,
                    color: config.isValidated
                        ? Colors.green
                        : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      config.isValidated
                          ? '已验证'
                          : '未验证',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: config.isValidated
                            ? Colors.green
                            : Colors.grey,
                        fontStyle: config.isValidated
                            ? FontStyle.normal
                            : FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.update,
                  size: 14,
                  color: theme.colorScheme.onSurface.withAlpha(128)),
                const SizedBox(width: 4),
                Text(
                  DateFormat.yMd().add_jm().format(config.updatedAt.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(128)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1, thickness: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!config.isValidated)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('验证'),
                    onPressed: isLoading ? null : onValidate,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (config.isValidated && !config.isDefault)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.star_border, size: 16),
                    label: const Text('设为默认'),
                    onPressed: isLoading ? null : onSetDefault,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ));
  }
}
