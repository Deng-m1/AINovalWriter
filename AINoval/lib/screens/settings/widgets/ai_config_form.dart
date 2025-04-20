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
  bool _showApiKey = false; // 控制API Key是否显示

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

      // 处理API密钥
      String? apiKey = _apiKeyController.text.trim();
      if (apiKey.isEmpty) {
        apiKey = null;
      }

      if (_isEditMode) {
        bloc.add(UpdateAiConfig(
          userId: widget.userId,
          configId: widget.configToEdit!.id,
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          apiKey: apiKey,
          apiEndpoint:
              _apiEndpointController.text.trim(), // Send empty string to clear
        ));
      } else {
        bloc.add(AddAiConfig(
          userId: widget.userId,
          provider: _selectedProvider!,
          modelName: _selectedModel!,
          apiKey: apiKey ?? "", // 如果为null，传递空字符串
          alias: _aliasController.text.trim().isEmpty
              ? _selectedModel
              : _aliasController.text.trim(),
          apiEndpoint: _apiEndpointController.text.trim(),
        ));
      }
      // The BlocListener in SettingsPanel will handle hiding the form on success/error
    }
  }

  // 处理模型选择
  void _handleModelSelected(String model) {
    setState(() {
      _selectedModel = model;
      // 设置别名默认为模型名称
      if (_aliasController.text.isEmpty) {
        _aliasController.text = model;
      }
    });
  }

  // 处理提供商选择
  void _handleProviderSelected(String provider) {
    if (provider != _selectedProvider) {
      setState(() {
        _selectedProvider = provider;
        _selectedModel = null;
      });
      _loadModels(provider);
      
      // 自动填充该提供商的API信息
      _autoFillApiInfo(provider);
    }
  }

  // 切换API Key的显示/隐藏
  void _toggleApiKeyVisibility() {
    setState(() {
      _showApiKey = !_showApiKey;
    });
  }

  // 自动填充API信息
  void _autoFillApiInfo(String provider) {
    // 获取该提供商的默认配置
    final defaultConfig = context.read<AiConfigBloc>().state.getProviderDefaultConfig(provider);
    if (defaultConfig != null && defaultConfig.id.isNotEmpty) {
      // 向后端获取实际的API密钥
      final bloc = context.read<AiConfigBloc>();
      
      setState(() {
        // 填充API Endpoint
        if (!_isEditMode && _apiEndpointController.text.isEmpty && defaultConfig.apiEndpoint.isNotEmpty) {
          _apiEndpointController.text = defaultConfig.apiEndpoint;
        }
        
        // 这里我们需要向后端请求实际的API密钥
        // 但由于API密钥是敏感信息，我们假设后端接口只返回了"API_KEY_FOR_PROVIDER"作为示例
        // 在实际应用中，替换为实际的获取API密钥的调用
        if (!_isEditMode && _apiKeyController.text.isEmpty) {
          // 注意：在真实应用中这里会是实际的API密钥
          _apiKeyController.text = "API_KEY_FOR_${provider.toUpperCase()}";
          _showApiKey = true; // 让用户看到API密钥以便确认
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AiConfigBloc, AiConfigState>(
      listener: (context, state) {
        if (!mounted) return; // Ensure widget is still mounted

        bool needsSetState = false;

        // --- Provider Loading & List Update ---
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
          _isLoadingModels = false;
          needsSetState = true;
        }

        // --- Saving State Update ---
        if (_isSaving && state.actionStatus != AiConfigActionStatus.loading) {
          if (state.actionStatus == AiConfigActionStatus.success) {
            widget.onCancel();
          }
          _isSaving = false;
          needsSetState = true;
        }

        if (needsSetState) {
          setState(() {});
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 标题
                Text(
                  _isEditMode ? '编辑模型服务' : '添加新模型服务',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // 主要内容区域 - 左右布局
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧提供商列表
                      if (!_isEditMode) // 在编辑模式下不显示左侧列表
                        SizedBox(
                          width: 180,
                          child: ProviderList(
                            providers: _providers,
                            selectedProvider: _selectedProvider,
                            onProviderSelected: _handleProviderSelected,
                          ),
                        ),
                      
                      if (!_isEditMode)
                        const SizedBox(width: 16),
                      
                      // 右侧配置区域
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Provider显示（仅编辑模式）
                            if (_isEditMode && _selectedProvider != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  '提供商: $_selectedProvider',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // 模型搜索框（仅添加模式）
                            if (!_isEditMode && _selectedProvider != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '选择模型',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 36,
                                      child: SearchableModelDropdown(
                                        models: _models,
                                        onModelSelected: _handleModelSelected,
                                        hintText: '搜索可用模型',
                                      ),
                    ),
                  ],
                ),
                              ),

                            // 已选模型显示（仅添加模式）
                            if (!_isEditMode && _selectedModel != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  '已选模型: $_selectedModel',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            
                            // 模型显示（仅编辑模式）
                            if (_isEditMode && _selectedModel != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  '模型: $_selectedModel',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // 别名输入框
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '别名 (可选)',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 36,
                child: TextFormField(
                  controller: _aliasController,
                                      style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                                        hintText: '例如：我的 ${_selectedModel ?? '模型'}',
                                        hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).hintColor.withOpacity(0.7),
                                        ),
                    border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12, 
                                          vertical: 0
                                        ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                                          : Theme.of(context).colorScheme.surfaceContainerLowest.withOpacity(0.7),
                                      ),
                                    ),
                    ),
                  ],
                ),
                            ),

                            // API Key输入框
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'API Key',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 36,
                child: TextFormField(
                  controller: _apiKeyController,
                                            obscureText: !_showApiKey,
                                            style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                                              hintText: _isEditMode ? '留空则不更新' : '输入您的API密钥',
                                              hintStyle: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(context).hintColor.withOpacity(0.7),
                                              ),
                    border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 12, 
                                                vertical: 0
                                              ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                                                ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                                                : Theme.of(context).colorScheme.surfaceContainerLowest.withOpacity(0.7),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _showApiKey ? Icons.visibility_off : Icons.visibility,
                                                  size: 18,
                                                ),
                                                onPressed: _toggleApiKeyVisibility,
                                              ),
                  ),
                  validator: (value) {
                    if (!_isEditMode && (value == null || value.trim().isEmpty)) {
                                                return 'API Key 不能为空';
                    }
                    return null;
                  },
                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // 如果有该提供商的已配置密钥，显示提示
                                  if (!_isEditMode && _selectedProvider != null)
                                    BlocBuilder<AiConfigBloc, AiConfigState>(
                                      builder: (context, state) {
                                        final defaultConfig = state.getProviderDefaultConfig(_selectedProvider!);
                                        final hasFilledApiKey = _apiKeyController.text.isNotEmpty;
                                        
                                        if (defaultConfig != null && defaultConfig.id.isNotEmpty && hasFilledApiKey) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  size: 14,
                                                  color: Colors.green,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '已填充该提供商的API密钥，请确认或修改',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                  ],
                ),
                            ),

                            // API Endpoint输入框
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'API Endpoint (可选)',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 36,
                child: TextFormField(
                  controller: _apiEndpointController,
                                            style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                                              hintText: '例如：https://api.openai.com/v1',
                                              hintStyle: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(context).hintColor.withOpacity(0.7),
                                              ),
                    border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 12, 
                                                vertical: 0
                                              ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                                                ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                                                : Theme.of(context).colorScheme.surfaceContainerLowest.withOpacity(0.7),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // 如果有该提供商的已配置API地址，显示提示
                                  if (!_isEditMode && _selectedProvider != null)
                                    BlocBuilder<AiConfigBloc, AiConfigState>(
                                      builder: (context, state) {
                                        final defaultConfig = state.getProviderDefaultConfig(_selectedProvider!);
                                        if (defaultConfig != null && defaultConfig.id.isNotEmpty && defaultConfig.apiEndpoint.isNotEmpty) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 14,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '已使用该提供商的API地址: ${defaultConfig.apiEndpoint}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                ],
                              ),
                            ),

                            // 模型分组列表（仅在选择了提供商时显示）
                            if (!_isEditMode && _selectedProvider != null && !_isLoadingModels)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '可用模型',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: BlocBuilder<AiConfigBloc, AiConfigState>(
                                        builder: (context, state) {
                                          final modelGroup = state.modelGroups[_selectedProvider];
                                          if (modelGroup == null) {
                                            return const Center(
                                              child: Text('没有可用的模型', style: TextStyle(fontSize: 13)),
                                            );
                                          }
                                          return SingleChildScrollView(
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: ModelGroupList(
                                                modelGroup: modelGroup,
                                                onModelSelected: _handleModelSelected,
                                                selectedModel: _selectedModel,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // 加载中提示
                            if (_isLoadingModels)
                              const Center(
                                child: CircularProgressIndicator(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 底部按钮区域
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSaving ? null : widget.onCancel,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            width: 1.0,
                          ),
                        ),
                        child: const Text('取消', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                    ElevatedButton(
                        onPressed: _isSaving || (_selectedModel == null && !_isEditMode) ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                                height: 16,
                                width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                            : Text(_isEditMode ? '保存更改' : '添加', style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
