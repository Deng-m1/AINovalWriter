import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/screens/ai_config/widgets/ai_config_list_item.dart';
// Import the new form widget
import 'package:ainoval/screens/settings/widgets/ai_config_form.dart';
// Import AddEditAiConfigDialog to reuse its form structure later
// import 'package:ainoval/screens/ai_config/widgets/add_edit_ai_config_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart'; // <<< Import fluttertoast
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // For delete confirmation dialog

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.onClose,
    required this.userId,
  });
  final VoidCallback onClose;
  final String userId;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  int _selectedIndex = 0; // Track the selected category index
  UserAIModelConfigModel?
      _configToEdit; // Track config being edited, null for add mode
  bool _showAddEditForm = false; // Flag to show the add/edit form view

  // Define category titles and icons (adjust as needed)
  final List<Map<String, dynamic>> _categories = [
    {'title': '模型服务', 'icon': Icons.cloud_queue},
    // {'title': '默认模型', 'icon': Icons.star_border}, // Example: Can be added later
    // {'title': '网络搜索', 'icon': Icons.search},
    // {'title': 'MCP 服务器', 'icon': Icons.dns},
    {'title': '常规设置', 'icon': Icons.settings_outlined},
    {'title': '显示设置', 'icon': Icons.display_settings},
    // {'title': '快捷方式', 'icon': Icons.shortcut},
    // {'title': '快捷助手', 'icon': Icons.assistant_photo},
    // {'title': '数据设置', 'icon': Icons.data_usage},
    // {'title': '关于我们\', 'icon': Icons.info_outline},
  ];

  void _showAddForm() {
    // <<< Explicitly trigger provider loading every time we enter add mode >>>
    // Ensure context is available and mounted before reading bloc
    if (mounted) {
      context.read<AiConfigBloc>().add(LoadAvailableProviders());
    }
    setState(() {
      _configToEdit = null; // Clear any previous edit state
      _showAddEditForm = true;
    });
  }

  void _showEditForm(UserAIModelConfigModel config) {
    // Load providers/models if needed when opening edit form
    if (mounted) {
      final bloc = context.read<AiConfigBloc>();
      if (bloc.state.availableProviders.isEmpty) {
        bloc.add(LoadAvailableProviders());
      }
      if (bloc.state.selectedProviderForModels != config.provider ||
          bloc.state.modelsForProvider.isEmpty) {
        bloc.add(LoadModelsForProvider(provider: config.provider));
      }
    }
    setState(() {
      _configToEdit = config;
      _showAddEditForm = true;
    });
  }

  void _hideAddEditForm() {
    setState(() {
      // Optionally clear BLoC state related to model loading if needed
      // context.read<AiConfigBloc>().add(ClearProviderModels());
      _configToEdit = null;
      _showAddEditForm = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(12.0),
      color: Colors.transparent, // Make Material transparent
      child: Container(
        width: 800, // Adjust width as needed
        height: 600, // Adjust height as needed
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            // Left Navigation Rail
            Container(
              width: 200,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.1)
                    : theme.colorScheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  bottomLeft: Radius.circular(12.0),
                ),
              ),
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedIndex == index;
                  return ListTile(
                    leading: Icon(
                      category['icon'] as IconData?,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 20, // Smaller icon
                    ),
                    title: Text(
                      category['title'] as String,
                      style: TextStyle(
                        fontSize: 13, // Slightly smaller font
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                        _hideAddEditForm(); // Hide form when changing category
                      });
                    },
                    selected: isSelected,
                    selectedTileColor:
                        theme.colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),

            // Right Content Area
            Expanded(
              child: ClipRRect(
                // Clip content to rounded corners
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12.0),
                  bottomRight: Radius.circular(12.0),
                ),
                child: Container(
                  // Add a background for the content area if needed
                  color: theme.cardColor, // Or theme.colorScheme.surface
                  child: Stack(
                    children: [
                      // Listener for Feedback Toasts
                      BlocListener<AiConfigBloc, AiConfigState>(
                        listener: (context, state) {
                          if (!mounted) return;

                          // Show Toast for errors
                          if (state.actionStatus ==
                                  AiConfigActionStatus.error &&
                              state.actionErrorMessage != null) {
                            Fluttertoast.showToast(
                                msg: '操作失败: ${state.actionErrorMessage!}',
                                toastLength: Toast
                                    .LENGTH_LONG, // Longer duration for errors
                                gravity:
                                    ToastGravity.CENTER, // Center on screen
                                backgroundColor: Colors.red.shade700,
                                textColor: Colors.white,
                                fontSize: 16.0);
                          }
                          // Show Toast for success
                          else if (state.actionStatus ==
                              AiConfigActionStatus.success) {
                            Fluttertoast.showToast(
                                msg: '操作成功',
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.CENTER,
                                backgroundColor: Colors.green.shade700,
                                textColor: Colors.white,
                                fontSize: 16.0);
                          }
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24.0, 48.0, 24.0, 24.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              // Using Key on the child ensures AnimatedSwitcher differentiates them
                              return FadeTransition(
                                  opacity: animation, child: child);
                            },
                            // Directly determine the child and its key here
                            child: _showAddEditForm &&
                                    _selectedIndex ==
                                        0 // Only show form for '模型服务'
                                ? _buildAiConfigForm(
                                    key: ValueKey(_configToEdit?.id ??
                                        'add')) // Form View
                                : _buildCategoryListContent(
                                    key: ValueKey('list_$_selectedIndex'),
                                    index:
                                        _selectedIndex), // List View or other categories
                          ),
                        ),
                      ),
                      // Close Button - Positioned relative to the Stack
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: '关闭设置', // TODO: Localize
                          onPressed: widget.onClose,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Renamed for clarity and added index parameter
  Widget _buildCategoryListContent({required Key key, required int index}) {
    final categoryTitle = _categories[index]['title'] as String;
    final bloc = context.read<AiConfigBloc>();

    switch (categoryTitle) {
      case '模型服务':
        return _buildAiConfigList(key: key, bloc: bloc);
      default:
        return Center(
            key: key,
            child: Text('这里将显示 $categoryTitle 设置',
                style: Theme.of(context).textTheme.bodyLarge));
    }
  }

  // Extracted AI Config List building logic, added key parameter
  Widget _buildAiConfigList({required Key key, required AiConfigBloc bloc}) {
    return BlocBuilder<AiConfigBloc, AiConfigState>(
      // <<< Changed to BlocBuilder
      key: key, // Pass the key here
      builder: (context, state) {
        // Builder logic remains the same - Loading/Error/Empty/List states
        // ... (Loading state)
        if (state.status == AiConfigStatus.loading && state.configs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        // ... (Error state for initial load)
        if (state.status == AiConfigStatus.error && state.configs.isEmpty) {
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('加载配置时出错', style: TextStyle(color: Colors.red)),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(state.errorMessage!),
                ),
              ElevatedButton(
                onPressed: () => bloc.add(LoadAiConfigs(userId: widget.userId)),
                child: const Text('重试'),
              )
            ],
          ));
        }

        final configs = state.configs;
        final bool isActionLoading =
            state.actionStatus == AiConfigActionStatus.loading;

        // ... (Empty state)
        if (configs.isEmpty && state.status != AiConfigStatus.loading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('未找到任何配置'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加第一个配置'),
                  onPressed: _showAddForm,
                )
              ],
            ),
          );
        }
        // ... (Display List and Add Button)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('已配置的模型服务',
                    style: Theme.of(context).textTheme.titleMedium),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加'),
                  onPressed: state.status == AiConfigStatus.loading
                      ? null
                      : _showAddForm,
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: configs.length,
                itemBuilder: (context, index) {
                  final config = configs[index];
                  final itemIsLoading =
                      isActionLoading && state.loadingConfigId == config.id;
                  return AiConfigListItem(
                    key: ValueKey(config.id),
                    config: config,
                    isLoading: itemIsLoading,
                    onEdit: () => _showEditForm(config),
                    onDelete: () => _showDeleteConfirmation(context, config),
                    onValidate: () => bloc.add(ValidateAiConfig(
                        userId: widget.userId, configId: config.id)),
                    onSetDefault: () => bloc.add(SetDefaultAiConfig(
                        userId: widget.userId, configId: config.id)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Builds the actual form widget, added key parameter
  Widget _buildAiConfigForm({required Key key}) {
    // REMOVE the BlocListener that was here, as it might prematurely hide the form.
    // Success/failure should be handled internally by AiConfigForm or via callbacks if needed.
    return AiConfigForm(
      // The actual form content
      key: key, // Pass the key provided by the parent
      userId: widget.userId,
      configToEdit: _configToEdit, // Pass the current configToEdit state
      onCancel: _hideAddEditForm, // Use the hide function for cancel
    );
  }

  // Delete confirmation dialog remains the same
  void _showDeleteConfirmation(
      BuildContext context, UserAIModelConfigModel config) {
    const titleText = '删除配置';
    final contentText = '确定要删除配置 ${config.alias} 吗？此操作无法撤销。';
    const cancelText = '取消';
    const deleteText = '删除';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(titleText),
        content: Text(contentText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(cancelText),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              // Ensure context used for read is still valid (it should be from showDialog)
              if (mounted) {
                context.read<AiConfigBloc>().add(
                    DeleteAiConfig(userId: widget.userId, configId: config.id));
              }
              Navigator.pop(ctx);
            },
            child: const Text(deleteText),
          ),
        ],
      ),
    );
  }
}
