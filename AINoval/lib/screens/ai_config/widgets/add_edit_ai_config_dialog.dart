import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AddEditAiConfigDialog extends StatefulWidget {
  final UserAIModelConfigModel? configToEdit;
  final String userId; // Needed for add/update events

  const AddEditAiConfigDialog({
    super.key,
    required this.userId,
    this.configToEdit,
  });

  @override
  State<AddEditAiConfigDialog> createState() => _AddEditAiConfigDialogState();
}

class _AddEditAiConfigDialogState extends State<AddEditAiConfigDialog> {
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
    _aliasController = TextEditingController(text: widget.configToEdit?.alias ?? '');
    _apiKeyController = TextEditingController(); // API key is never pre-filled for editing
    _apiEndpointController = TextEditingController(text: widget.configToEdit?.apiEndpoint ?? '');
    _selectedProvider = widget.configToEdit?.provider;
    _selectedModel = widget.configToEdit?.modelName;

     // Request providers immediately if needed
     if (!_isEditMode) {
       _loadProviders();
     } else if (_selectedProvider != null) {
        // If editing, load providers to populate dropdown, and models for the selected provider
        _loadProviders();
        _loadModels(_selectedProvider!);
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _apiKeyController.dispose();
    _apiEndpointController.dispose();
    // Clear models when dialog is closed
    context.read<AiConfigBloc>().add(ClearProviderModels());
    super.dispose();
  }

   void _loadProviders() {
     setState(() {
       _isLoadingProviders = true;
     });
     // Use the Bloc provided via context
     context.read<AiConfigBloc>().add(LoadAvailableProviders());
   }

   void _loadModels(String provider) {
     setState(() {
       _isLoadingModels = true;
       _selectedModel = null; // Reset model selection when provider changes
       _models = []; // Clear previous models
     });
     context.read<AiConfigBloc>().add(LoadModelsForProvider(provider: provider));
   }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
        setState(() { _isSaving = true; });
      final bloc = context.read<AiConfigBloc>();

      if (_isEditMode) {
        bloc.add(UpdateAiConfig(
          userId: widget.userId,
          configId: widget.configToEdit!.id,
          alias: _aliasController.text.trim().isEmpty ? null : _aliasController.text.trim(), // Only send if not empty, or let backend decide
          apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(), // Only send if changed
          apiEndpoint: _apiEndpointController.text.trim(), // Send empty string to clear endpoint
        ));
      } else {
        bloc.add(AddAiConfig(
          userId: widget.userId,
          provider: _selectedProvider!,
          modelName: _selectedModel!,
          apiKey: _apiKeyController.text.trim(),
          alias: _aliasController.text.trim().isEmpty ? _selectedModel : _aliasController.text.trim(), // Default alias to model name if empty
          apiEndpoint: _apiEndpointController.text.trim(),
        ));
      }
       // Listen for completion state change to close dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<AiConfigBloc, AiConfigState>(
      listener: (context, state) {
         // Update local lists and loading states based on Bloc state
          setState(() {
             _providers = state.availableProviders;
             _isLoadingProviders = false; // Assuming load finishes once providers appear

             if (state.selectedProviderForModels == _selectedProvider) {
                 _models = state.modelsForProvider;
                 _isLoadingModels = false;
             } else if (_selectedProvider != null && state.selectedProviderForModels != _selectedProvider){
                // Handle case where Bloc state is for a different provider than selected
                _isLoadingModels = false; // Stop loading indicator
             }

              // Handle save completion or error
             if (_isSaving) {
                if (state.actionStatus == AiConfigActionStatus.success || state.actionStatus == AiConfigActionStatus.error) {
                   _isSaving = false;
                   if (state.actionStatus == AiConfigActionStatus.success && mounted) {
                      Navigator.of(context).pop(); // Close dialog on success
                   }
                    // Error message is handled by the main screen's listener
                }
             }
          });
      },
      child: AlertDialog(
        // title: Text(_isEditMode ? l10n.editConfigTitle : l10n.addConfigTitle), // TODO: Add l10n
        title: Text(_isEditMode ? '编辑配置' : '添加配置'), // Placeholder
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // --- Provider Dropdown ---
                DropdownButtonFormField<String>(
                  value: _selectedProvider,
                  // hint: Text(l10n.selectProviderHint), // TODO: Add l10n
                  hint: Text('选择提供商'), // Placeholder
                  isExpanded: true,
                  onChanged: _isEditMode
                      ? null // Cannot change provider when editing
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
                  items: _providers.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  // validator: (value) => value == null ? l10n.providerRequired : null, // TODO: Add l10n
                  validator: (value) => value == null ? '请选择提供商' : null, // Placeholder
                  decoration: InputDecoration(
                      // labelText: l10n.providerLabel, // TODO: Add l10n
                      labelText: '提供商', // Placeholder
                      border: OutlineInputBorder(),
                      suffixIcon: _isLoadingProviders ? Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  ),
                   disabledHint: _isEditMode ? Text(_selectedProvider ?? '') : null, // Show selected value when disabled
                   style: _isEditMode ? TextStyle(color: Theme.of(context).disabledColor) : null,
                ),
                const SizedBox(height: 16),

                // --- Model Dropdown ---
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                   // hint: Text(l10n.selectModelHint), // TODO: Add l10n
                   hint: Text('选择模型'), // Placeholder
                   isExpanded: true,
                  onChanged: _isEditMode || _selectedProvider == null || _isLoadingModels
                      ? null // Cannot change model when editing or provider not selected or loading
                      : (String? newValue) {
                          setState(() {
                            _selectedModel = newValue;
                          });
                        },
                  items: _models.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                   // validator: (value) => value == null ? l10n.modelRequired : null, // TODO: Add l10n
                   validator: (value) => value == null ? '请选择模型' : null, // Placeholder
                   decoration: InputDecoration(
                      // labelText: l10n.modelLabel, // TODO: Add l10n
                      labelText: '模型', // Placeholder
                      border: OutlineInputBorder(),
                      suffixIcon: _isLoadingModels ? Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                   ),
                   disabledHint: _isEditMode ? Text(_selectedModel ?? '') : null, // Show selected value when disabled
                   style: _isEditMode ? TextStyle(color: Theme.of(context).disabledColor) : null,
                ),
                const SizedBox(height: 16),

                // --- Alias ---
                TextFormField(
                  controller: _aliasController,
                   decoration: InputDecoration(
                        // labelText: l10n.aliasLabel, // TODO: Add l10n
                        labelText: '别名 (可选)', // Placeholder
                        // hintText: l10n.aliasHint( _selectedModel ?? 'model'), // TODO: Add l10n
                        hintText: '例如：我的${_selectedModel ?? '模型'}', // Placeholder
                        border: OutlineInputBorder()),
                   // No validator, alias is optional or defaults
                ),
                const SizedBox(height: 16),

                // --- API Key ---
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                      // labelText: l10n.apiKeyLabel, // TODO: Add l10n
                      labelText: 'API Key', // Placeholder
                       // hintText: _isEditMode ? l10n.apiKeyEditHint : null, // TODO: Add l10n
                       hintText: _isEditMode ? '留空则不更新' : null, // Placeholder
                      border: OutlineInputBorder()),
                  validator: (value) {
                    if (!_isEditMode && (value == null || value.trim().isEmpty)) {
                      // return l10n.apiKeyRequired; // TODO: Add l10n
                      return 'API Key 不能为空'; // Placeholder
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // --- API Endpoint ---
                TextFormField(
                  controller: _apiEndpointController,
                  decoration: InputDecoration(
                      // labelText: l10n.apiEndpointLabel, // TODO: Add l10n
                      labelText: 'API Endpoint (可选)', // Placeholder
                      // hintText: l10n.apiEndpointHint, // TODO: Add l10n
                      hintText: '例如： https://api.openai.com/v1', // Placeholder
                      border: OutlineInputBorder()),
                  // No validator, endpoint is optional
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            // child: Text(l10n.cancel), // TODO: Add l10n
            child: Text('取消'), // Placeholder
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _submitForm,
             child: _isSaving
                 ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                 // : Text(_isEditMode ? l10n.saveChanges : l10n.add), // TODO: Add l10n
                 : Text(_isEditMode ? '保存更改' : '添加'), // Placeholder
          ),
        ],
      ),
    );
  }
}

// TODO: Add localization strings: editConfigTitle, addConfigTitle, selectProviderHint, providerRequired, providerLabel,
// selectModelHint, modelRequired, modelLabel, aliasLabel, aliasHint, apiKeyLabel, apiKeyEditHint, apiKeyRequired,
// apiEndpointLabel, apiEndpointHint, cancel, saveChanges, add 