import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/screens/settings/widgets/ai_config_form.dart';
import 'package:ainoval/screens/settings/widgets/model_service_list_page.dart';
import 'package:ainoval/screens/settings/widgets/prompt_management_panel.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.onClose,
    required this.userId,
    this.editorSettings,
    this.onEditorSettingsChanged,
  });
  final VoidCallback onClose;
  final String userId;
  final EditorSettings? editorSettings;
  final Function(EditorSettings)? onEditorSettingsChanged;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  int _selectedIndex = 0; // Track the selected category index
  UserAIModelConfigModel?
      _configToEdit; // Track config being edited, null for add mode
  bool _showAddEditForm = false; // Flag to show the add/edit form view
  late EditorSettings _editorSettings;

  // Define category titles and icons (adjust as needed)
  final List<Map<String, dynamic>> _categories = [
    {'title': '模型服务', 'icon': Icons.cloud_queue},
    // {'title': '默认模型', 'icon': Icons.star_border}, // Example: Can be added later
    // {'title': '网络搜索', 'icon': Icons.search},
    // {'title': 'MCP 服务器', 'icon': Icons.dns},
    {'title': '常规设置', 'icon': Icons.settings_outlined},
    {'title': '显示设置', 'icon': Icons.display_settings},
    {'title': '编辑器设置', 'icon': Icons.edit_note},
    {'title': '提示词管理', 'icon': Icons.chat},
    // {'title': '快捷方式', 'icon': Icons.shortcut},
    // {'title': '快捷助手', 'icon': Icons.assistant_photo},
    // {'title': '数据设置', 'icon': Icons.data_usage},
    // {'title': '关于我们\', 'icon': Icons.info_outline},
  ];

  @override
  void initState() {
    super.initState();
    _editorSettings = widget.editorSettings ?? const EditorSettings();
  }

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

  void _hideAddEditForm() {
    setState(() {
      // Optionally clear BLoC state related to model loading if needed
      // context.read<AiConfigBloc>().add(ClearProviderModels());
      _configToEdit = null;
      _showAddEditForm = false;
    });
  }

  // 新增方法：显示编辑表单
  void _showEditForm(UserAIModelConfigModel config) {
    // 检查Bloc是否已有该Provider的模型，若无则加载
    if (mounted) {
      final bloc = context.read<AiConfigBloc>();
      if (bloc.state.selectedProviderForModels != config.provider ||
          bloc.state.modelsForProvider.isEmpty) {
        bloc.add(LoadModelsForProvider(provider: config.provider));
      }
      // 也可以考虑加载该提供商的默认配置（如果需要的话）
      // bloc.add(GetProviderDefaultConfig(provider: config.provider));
    }

    setState(() {
      _configToEdit = config; // 设置要编辑的配置
      _showAddEditForm = true; // 显示表单
      _selectedIndex = 0; // 确保在 '模型服务' 类别下
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(16.0),
      color: Colors.transparent, // Make Material transparent
      child: Container(
        width: 1440, // 增加宽度从800到960
        height: 1080, // 增加高度从600到700
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surface.withAlpha(217) // 0.85 opacity
              : theme.colorScheme.surface.withAlpha(242), // 0.95 opacity
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha(77) // 0.3 opacity
                  : Colors.black.withAlpha(26), // 0.1 opacity
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(26) // 0.1 opacity
                : Colors.white.withAlpha(153), // 0.6 opacity
            width: 0.5,
          ),
        ),
        // 添加背景模糊效果
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left Navigation Rail
            Container(
              width: 200,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withAlpha(51) // 0.2 opacity
                    : theme.colorScheme.surfaceContainerLowest.withAlpha(179), // 0.7 opacity
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(13) // 0.05 opacity
                      : Colors.white.withAlpha(77), // 0.3 opacity
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withAlpha(51) // 0.2 opacity
                        : Colors.black.withAlpha(13), // 0.05 opacity
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? theme.colorScheme.primary.withAlpha(38) // 0.15 opacity
                                : theme.colorScheme.primary.withAlpha(26)) // 0.1 opacity
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withAlpha(26), // 0.1 opacity
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ] : [],
                      ),
                      child: ListTile(
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 4.0),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Right Content Area
            Expanded(
              child: ClipRRect(
                // Clip content to rounded corners
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16.0),
                  bottomRight: Radius.circular(16.0),
                ),
                child: Container(
                  // Add a background for the content area if needed
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.cardColor.withAlpha(179) // 0.7 opacity
                        : theme.cardColor.withAlpha(217), // 0.85 opacity
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withAlpha(51) // 0.2 opacity
                            : Colors.black.withAlpha(13), // 0.05 opacity
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
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
                              const EdgeInsets.fromLTRB(32.0, 48.0, 32.0, 32.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOutQuint,
                            switchOutCurve: Curves.easeInQuint,
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              // Using Key on the child ensures AnimatedSwitcher differentiates them
                              return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.05, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  )
                              );
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withAlpha(51) // 0.2 opacity
                                : Colors.white.withAlpha(128), // 0.5 opacity
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26), // 0.1 opacity
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: '关闭设置',
                            onPressed: widget.onClose,
                          ),
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

    switch (categoryTitle) {
      case '模型服务':
        return ModelServiceListPage(
          key: key,
          userId: widget.userId,
          onAddNew: _showAddForm,
          onEditConfig: _showEditForm, // 传递编辑回调
        );
      case '提示词管理':
        return const PromptManagementPanel();
      case '编辑器设置':
        return _buildEditorSettingsPanel(key: key);
      default:
        return Center(
            key: key,
            child: Text('这里将显示 $categoryTitle 设置',
                style: Theme.of(context).textTheme.bodyLarge));
    }
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

  // 新增编辑器设置面板构建方法
  Widget _buildEditorSettingsPanel({required Key key}) {
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
    );
    const cardElevation = 2.0;

    return ListView(
      key: key,
      padding: const EdgeInsets.all(16),
      children: [
        // 字体大小设置
        Card(
          shape: cardShape,
          elevation: cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '字体大小',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('小'),
                    Expanded(
                      child: Slider(
                        value: _editorSettings.fontSize,
                        min: 12,
                        max: 24,
                        divisions: 12,
                        label: _editorSettings.fontSize.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            _editorSettings = _editorSettings.copyWith(fontSize: value);
                          });
                          widget.onEditorSettingsChanged?.call(_editorSettings);
                        },
                      ),
                    ),
                    const Text('大'),
                  ],
                ),
                Center(
                  child: Text(
                    '示例文本',
                    style: TextStyle(
                      fontSize: _editorSettings.fontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 行间距设置
        Card(
          shape: cardShape,
          elevation: cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '行间距',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('紧凑'),
                    Expanded(
                      child: Slider(
                        value: _editorSettings.lineSpacing,
                        min: 1.0,
                        max: 2.0,
                        divisions: 10,
                        label: _editorSettings.lineSpacing.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            _editorSettings = _editorSettings.copyWith(lineSpacing: value);
                          });
                          widget.onEditorSettingsChanged?.call(_editorSettings);
                        },
                      ),
                    ),
                    const Text('宽松'),
                  ],
                ),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '示例文本行1',
                        style: TextStyle(
                          height: _editorSettings.lineSpacing,
                        ),
                      ),
                      Text(
                        '示例文本行2',
                        style: TextStyle(
                          height: _editorSettings.lineSpacing,
                        ),
                      ),
                      Text(
                        '示例文本行3',
                        style: TextStyle(
                          height: _editorSettings.lineSpacing,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 字体选择
        Card(
          shape: cardShape,
          elevation: cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '字体',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _editorSettings.fontFamily,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Roboto',
                      child: Text('Roboto'),
                    ),
                    DropdownMenuItem(
                      value: 'serif',
                      child: Text('宋体'),
                    ),
                    DropdownMenuItem(
                      value: 'monospace',
                      child: Text('等宽字体'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _editorSettings = _editorSettings.copyWith(fontFamily: value);
                      });
                      widget.onEditorSettingsChanged?.call(_editorSettings);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '示例文本',
                    style: TextStyle(
                      fontFamily: _editorSettings.fontFamily,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 自动保存设置
        Card(
          shape: cardShape,
          elevation: cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自动保存',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('启用自动保存'),
                  value: _editorSettings.autoSaveEnabled,
                  onChanged: (value) {
                    setState(() {
                      _editorSettings = _editorSettings.copyWith(autoSaveEnabled: value);
                    });
                    widget.onEditorSettingsChanged?.call(_editorSettings);
                  },
                ),
                if (_editorSettings.autoSaveEnabled) ...[
                  const SizedBox(height: 8),
                  const Text('自动保存间隔'),
                  const SizedBox(height: 8),
                  Slider(
                    value: _editorSettings.autoSaveIntervalMinutes.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    label: '${_editorSettings.autoSaveIntervalMinutes}分钟',
                    onChanged: (value) {
                      // 保证值是整数
                      final roundedValue = value.round().toDouble();
                      setState(() {
                        _editorSettings = _editorSettings.copyWith(
                          autoSaveIntervalMinutes: roundedValue.toInt(),
                        );
                      });
                      widget.onEditorSettingsChanged?.call(_editorSettings);
                    },
                  ),
                  Center(
                    child: Text(
                      '每${_editorSettings.autoSaveIntervalMinutes}分钟自动保存一次',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 拼写检查
        Card(
          shape: cardShape,
          elevation: cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '拼写检查',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('启用拼写检查'),
                  value: _editorSettings.spellCheckEnabled,
                  onChanged: (value) {
                    setState(() {
                      _editorSettings = _editorSettings.copyWith(spellCheckEnabled: value);
                    });
                    widget.onEditorSettingsChanged?.call(_editorSettings);
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 主题模式
        Card(
          shape: cardShape,
          elevation: cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '主题',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('深色模式'),
                  value: _editorSettings.darkModeEnabled,
                  onChanged: (value) {
                    setState(() {
                      _editorSettings = _editorSettings.copyWith(darkModeEnabled: value);
                    });
                    widget.onEditorSettingsChanged?.call(_editorSettings);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
