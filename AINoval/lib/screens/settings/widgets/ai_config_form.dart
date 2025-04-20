import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:ainoval/models/ai_model_group.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/screens/settings/widgets/model_group_list.dart';
import 'package:ainoval/screens/settings/widgets/provider_list.dart';
import 'package:ainoval/screens/settings/widgets/searchable_model_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Placeholder for localization, replace with your actual import
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AiConfigForm extends StatefulWidget {
  // Callback when cancel is pressed
  // Optional: Callback on successful save if specific action needed besides hiding form
  // final VoidCallback? onSaveSuccess;

  const AiConfigForm({
    super.key,
    required this.userId,
    required this.onCancel,
    this.configToEdit,
    // this.onSaveSuccess,
  });
  final UserAIModelConfigModel? configToEdit;
  final String userId;
  final VoidCallback onCancel;

  @override
  State<AiConfigForm> createState() => _AiConfigFormState();
}

class _AiConfigFormState extends State<AiConfigForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _aliasController;
  late TextEditingController _apiKeyController;
  late TextEditingController _apiEndpointController;

  String? _selectedProvider;
  String? _selectedModel;
  bool _isLoadingProviders = false;
  bool _isLoadingModels = false;
  bool _isSaving = false; // Track internal saving state

  List<String> _providers = [];
  List<String> _models = [];

  bool get _isEditMode => widget.configToEdit != null;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _aliasController =
        TextEditingController(text: widget.configToEdit?.alias ?? '');
    _apiKeyController = TextEditingController(); // API key is never pre-filled
    _apiEndpointController =
        TextEditingController(text: widget.configToEdit?.apiEndpoint ?? '');

    // <<< Reset selections if in Add mode >>>
    if (!_isEditMode) {
      _selectedProvider = null;
      _selectedModel = null;
      _providers = []; // Also clear lists initially for add mode
      _models = [];
    } else {
      // If editing, keep the initial values
      _selectedProvider = widget.configToEdit?.provider;
      _selectedModel = widget.configToEdit?.modelName;
    }

    // Use context safely after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Check mount status
      final bloc = context.read<AiConfigBloc>();
      // Pre-populate lists from current Bloc state if available
      // This helps if Bloc already has data when form initializes
      if (_providers.isEmpty) {
        _providers = bloc.state.availableProviders;
      }
      if (_models.isEmpty &&
          _selectedProvider != null &&
          bloc.state.selectedProviderForModels == _selectedProvider) {
        _models = bloc.state.modelsForProvider;
      }

      // --- Trigger loading ---
      // Always try to load providers when the form inits,
      // as the list might be stale or empty (especially in add mode).
      // The BlocListener will handle the loading indicator state.
      _loadProviders();

      // If editing and provider is selected, ensure models are loaded.
      if (_isEditMode && _selectedProvider != null) {
        // Check if models for this provider are already in Bloc state
        if (bloc.state.selectedProviderForModels != _selectedProvider ||
            bloc.state.modelsForProvider.isEmpty) {
          _loadModels(_selectedProvider!); // Load if not present or empty
        } else if (_models.isEmpty) {
          // Or if our local list is empty
          _models = bloc.state.modelsForProvider; // Populate from Bloc
          setState(() {}); // Update UI if models were populated synchronously
        }
      }
    });
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _apiKeyController.dispose();
    _apiEndpointController.dispose();
    // Don't clear models here as the Bloc state might be needed elsewhere
    // context.read<AiConfigBloc>().add(ClearProviderModels());
    super.dispose();
  }

  void _loadProviders() {
    if (!mounted) return; // Check if widget is still in the tree
    setState(() {
      _isLoadingProviders = true;
    });
    context.read<AiConfigBloc>().add(LoadAvailableProviders());
  }

  void _loadModels(String provider) {
    if (!mounted) return;
    setState(() {
      _isLoadingModels = true;
      // Reset model only if it's not edit mode or if provider actually changes
      if (!_isEditMode || provider != _selectedProvider) {
        _selectedModel = null;
      }
      _models = []; // Clear previous models for the dropdown
    });
    context.read<AiConfigBloc>().add(LoadModelsForProvider(provider: provider));
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      final bloc = context.read<AiConfigBloc>();

      if (_isEditMode) {
        bloc.add(UpdateAiConfig(
          userId: widget.userId,
          configId: widget.configToEdit!.id,
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          apiKey: _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
          apiEndpoint:
              _apiEndpointController.text.trim(), // Send empty string to clear
        ));
      } else {
        bloc.add(AddAiConfig(
          userId: widget.userId,
          provider: _selectedProvider!,
          modelName: _selectedModel!,
          apiKey: _apiKeyController.text.trim(),
          alias: _aliasController.text.trim().isEmpty
              ? _selectedModel
              : _aliasController.text.trim(),
          apiEndpoint: _apiEndpointController.text.trim(),
        ));
      }
      // The BlocListener in SettingsPanel will handle hiding the form on success/error
    }
  }

  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context)!; // Use if available

    // Use BlocListener to update local state based on Bloc changes
    return BlocListener<AiConfigBloc, AiConfigState>(
      listener: (context, state) {
        if (!mounted) return; // Ensure widget is still mounted

        bool needsSetState = false;

        // --- Provider Loading & List Update ---
        // Stop loading if providers are loaded OR if there's a general error message (potential load failure)
        if (_isLoadingProviders &&
            (state.availableProviders.isNotEmpty ||
                state.errorMessage != null)) {
          _isLoadingProviders = false;
          needsSetState = true;
        }
        if (state.availableProviders != _providers) {
          _providers = state.availableProviders;
          needsSetState = true;
        }

        // --- Model Loading & List Update ---
        // Stop loading if models for the selected provider are loaded OR if there's a general error message
        if (state.selectedProviderForModels == _selectedProvider) {
          if (_isLoadingModels &&
              (state.modelsForProvider.isNotEmpty ||
                  state.errorMessage != null)) {
            _isLoadingModels = false;
            needsSetState = true;
          }
          if (state.modelsForProvider != _models) {
            _models = state.modelsForProvider;
            if (!_models.contains(_selectedModel)) {
              _selectedModel = null;
            }
            needsSetState = true;
          }
        } else if (_isLoadingModels) {
          // If we were loading models, but state is for a different provider or error
          _isLoadingModels = false;
          needsSetState = true;
        }

        // --- Saving State Update ---
        // Stop saving indicator if action is no longer loading (success or error)
        if (_isSaving && state.actionStatus != AiConfigActionStatus.loading) {
          // <<< Check if the action that just finished was a success >>>
          if (state.actionStatus == AiConfigActionStatus.success) {
            // If *this form* was saving and it succeeded, trigger the cancel callback to close it.
            widget.onCancel();
          }
          // Always reset _isSaving regardless of success/error
          _isSaving = false;
          needsSetState = true;
        }

        if (needsSetState) {
          setState(() {});
        }
      },
      child: SingleChildScrollView(
        // Allows scrolling if content overflows
        padding: const EdgeInsets.symmetric(
            vertical: 16.0, horizontal: 8.0), // Add some padding
        child: Form(
          key: _formKey,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(51) // 0.2 opacity
                : Theme.of(context).colorScheme.surfaceContainerLowest.withAlpha(179), // 0.7 opacity
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withAlpha(51) // 0.2 opacity
                    : Colors.black.withAlpha(13), // 0.05 opacity
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withAlpha(26) // 0.1 opacity
                  : Colors.black.withAlpha(13), // 0.05 opacity
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Take minimum vertical space
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
              // 标题
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  _isEditMode ? '编辑模型服务' : '添加新模型服务',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

              // --- Provider Dropdown ---
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: _buildDropdownFormField(
                  value: _selectedProvider,
                  hintText: '选择提供商', // Placeholder
                  labelText: '提供商', // Placeholder
                  items: _providers,
                  isLoading: _isLoadingProviders,
                  onChanged: _isEditMode
                      ? null
                      : (String? newValue) {
                          if (newValue != null && newValue != _selectedProvider) {
                            setState(() {
                              _selectedProvider = newValue;
                              _selectedModel = null; // Reset model
                              _models = []; // Clear models
                            });
                            _loadModels(newValue);
                          }
                        },
                  validator: (value) =>
                      value == null ? '请选择提供商' : null, // Placeholder
                  disabledHintValue:
                      _selectedProvider, // Show value when disabled
                ),
              ),

              // --- Model Dropdown ---
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: _buildDropdownFormField(
                  value: _selectedModel,
                  hintText: '选择模型', // Placeholder
                  labelText: '模型', // Placeholder
                  items: _models,
                  isLoading: _isLoadingModels,
                  // Disable if editing, or no provider selected, or models loading, or no models available
                  onChanged: (_isEditMode ||
                          _selectedProvider == null ||
                          _isLoadingModels ||
                          _models.isEmpty)
                      ? null
                      : (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedModel = newValue;
                            });
                          }
                        },
                  validator: (value) =>
                      value == null ? '请选择模型' : null, // Placeholder
                  disabledHintValue: _selectedModel, // Show value when disabled
                ),
              ),

              // --- Alias ---
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _aliasController,
                  decoration: InputDecoration(
                    labelText: '别名 (可选)', // Placeholder
                    hintText: '例如：我的 ${_selectedModel ?? '模型'}', // Placeholder
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 16.0), // Adjust padding
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128)
                      : Theme.of(context).colorScheme.surfaceContainerLowest.withAlpha(230),
                  ),
                  // No validator, alias is optional
                ),
              ),

              // --- API Key ---
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'API Key', // Placeholder
                    hintText: _isEditMode ? '留空则不更新' : null, // Placeholder
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 16.0),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128)
                      : Theme.of(context).colorScheme.surfaceContainerLowest.withAlpha(230),
                  ),
                  validator: (value) {
                    if (!_isEditMode && (value == null || value.trim().isEmpty)) {
                      return 'API Key 不能为空'; // Placeholder
                    }
                    return null;
                  },
                ),
              ),

              // --- API Endpoint ---
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _apiEndpointController,
                  decoration: InputDecoration(
                    labelText: 'API Endpoint (可选)', // Placeholder
                    hintText: '例如： https://api.openai.com/v1', // Placeholder
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 16.0),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128)
                      : Theme.of(context).colorScheme.surfaceContainerLowest.withAlpha(230),
                  ),
                  // No validator, endpoint is optional
                ),
              ),

              // --- Action Buttons ---
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSaving ? null : widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withAlpha(128),
                        ),
                      ),
                      child: const Text('取消', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditMode ? '保存更改' : '添加',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  // Helper to build consistent dropdowns
  Widget _buildDropdownFormField({
    required String? value,
    required String hintText,
    required String labelText,
    required List<String> items,
    required bool isLoading,
    required ValueChanged<String?>? onChanged,
    required FormFieldValidator<String>? validator,
    required String? disabledHintValue,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      value:
          items.contains(value) ? value : null, // Ensure value exists in items
      hint: Text(hintText),
      isExpanded: true,
      onChanged: onChanged,
      items: items.map<DropdownMenuItem<String>>((String itemValue) {
        return DropdownMenuItem<String>(
          value: itemValue,
          child: Text(itemValue, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withAlpha(128),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withAlpha(128),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 16.0, horizontal: 16.0), // Adjust padding
        filled: true,
        fillColor: isDark
          ? theme.colorScheme.surfaceContainerHighest.withAlpha(128)
          : theme.colorScheme.surfaceContainerLowest.withAlpha(230),
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(10.0),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : null,
      ),
      dropdownColor: isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      disabledHint: disabledHintValue != null
          ? Text(disabledHintValue,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.disabledColor))
          : null,
      style: onChanged == null
          ? TextStyle(color: theme.disabledColor)
          : null,
    );
  }
}
