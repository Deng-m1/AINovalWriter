import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:ainoval/config/app_config.dart'; // <<< Import AppConfig
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/services/api_service/repositories/impl/user_ai_model_config_repository_impl.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'widgets/add_edit_ai_config_dialog.dart';
import 'widgets/ai_config_list_item.dart';

class AiConfigManagementScreen extends StatelessWidget {
  const AiConfigManagementScreen({super.key});

  // TODO: Replace with proper dependency injection for repository
  static final _tempApiClient = ApiClient(); // Temporary - use injected instance
  static final UserAIModelConfigRepository _repository = UserAIModelConfigRepositoryImpl(apiClient: _tempApiClient); // Temporary


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // <<< Get userId from AppConfig >>>
    // Ensure userId is available before navigating here, or handle null case
    final String? currentUserId = AppConfig.userId; // Allow null initially

    // Show an error/loading state if userId is null and required
    if (currentUserId == null) { // <<< Check for null
       return Scaffold(
           // appBar: AppBar(title: Text(l10n.errorTitle)), // TODO: Add l10n.errorTitle='错误'
           appBar: AppBar(title: Text('错误')), // Placeholder
           // body: Center(child: Text(l10n.errorUserNotLoggedIn)) // TODO: Add l10n.errorUserNotLoggedIn = '无法加载配置：用户未登录。'
           body: Center(child: Text('无法加载配置：用户未登录。')) // Placeholder
       ); // <<< 修正: 移除了多余的括号并添加了分号
    }

    return BlocProvider(
      // Use ! because we checked for null above
      create: (context) => AiConfigBloc(repository: _repository)..add(LoadAiConfigs(userId: currentUserId!)),
      child: Scaffold(
        appBar: AppBar(
          // TODO: Add l10n.aiModelConfigTitle string
          // title: Text(l10n.aiModelConfigTitle), // Placeholder 'AI 模型配置'
          title: Text('AI 模型配置'), // Placeholder
        ),
        body: BlocConsumer<AiConfigBloc, AiConfigState>(
            listener: (context, state) {
              if (state.actionStatus == AiConfigActionStatus.error && state.actionErrorMessage != null) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                         // content: Text("${l10n.operationFailed}: ${state.actionErrorMessage!}"), // TODO: Add l10n.operationFailed = '操作失败'
                         content: Text("操作失败: ${state.actionErrorMessage!}"), // Placeholder
                         backgroundColor: Colors.red,
                       ),
                     );
              }
               // Optional: Show success message
               else if (state.actionStatus == AiConfigActionStatus.success) {
                   // Consider showing temporary success confirmations if needed
                   // ScaffoldMessenger.of(context).showSnackBar(
                   //   SnackBar(content: Text(l10n.operationSuccessful), backgroundColor: Colors.green), // TODO: Add l10n.operationSuccessful = '操作成功'
                   // );
                   // Reset action status after showing message? Maybe handle in BLoC directly.
               }
            },
            builder: (context, state) {
               if (state.status == AiConfigStatus.loading && state.configs.isEmpty) {
                 return const Center(child: CircularProgressIndicator());
               }
               if (state.status == AiConfigStatus.error && state.configs.isEmpty) {
                 return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Text(l10n.errorLoadingConfig, style: TextStyle(color: Colors.red)), // TODO: Add l10n.errorLoadingConfig = '加载配置时出错'
                        Text('加载配置时出错', style: TextStyle(color: Colors.red)), // Placeholder
                        if (state.errorMessage != null) Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(state.errorMessage!),
                        ),
                        ElevatedButton(
                           // Use ! because userId is checked non-null here
                          onPressed: () => context.read<AiConfigBloc>().add(LoadAiConfigs(userId: currentUserId!)),
                          // child: Text(l10n.retry), // TODO: Add l10n.retry = '重试'
                          child: Text('重试'), // Placeholder
                        )
                      ],
                    ));
               }

              final configs = state.configs;
              final bool isActionLoading = state.actionStatus == AiConfigActionStatus.loading;

              return Stack(
                 children: [
                   if (configs.isEmpty && state.status != AiConfigStatus.loading)
                       // Center(child: Text(l10n.noConfigsFound)), // TODO: Add l10n.noConfigsFound = '未找到任何配置'
                       Center(child: Text('未找到任何配置')), // Placeholder
                    ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80), // Add padding to avoid FAB overlap
                        itemCount: configs.length,
                        itemBuilder: (context, index) {
                        final config = configs[index];
                         // Pass specific loading state for the item if we track it by ID, otherwise use global action loading state
                         // bool itemIsLoading = isActionLoading && state.loadingConfigId == config.id; // Need state.loadingConfigId

                        return AiConfigListItem(
                            config: config,
                            // If not tracking individual item loading, disable buttons globally during action
                            isLoading: isActionLoading,
                            // Use ! for userId
                           onEdit: () => _showAddEditDialog(context, currentUserId!, config: config), // Pass userId
                            onDelete: () => _showDeleteConfirmation(context, currentUserId!, config), // Pass userId
                            onValidate: () => context
                                .read<AiConfigBloc>()
                                .add(ValidateAiConfig(userId: currentUserId!, configId: config.id)), // Use userId
                           onSetDefault: () => context
                                .read<AiConfigBloc>()
                                .add(SetDefaultAiConfig(userId: currentUserId!, configId: config.id)), // Use userId
                        );
                        },
                    ),
                   // Optional: Global loading indicator overlay
                   // if (isActionLoading)
                   //    Positioned.fill(
                   //       child: Container(
                   //        color: Colors.black.withOpacity(0.1),
                   //        child: const Center(child: CircularProgressIndicator()),
                   //       ),
                   //   ),
                 ],
               );
            },
        ),
        floatingActionButton: FloatingActionButton(
           // Use ! for userId
          onPressed: () => _showAddEditDialog(context, currentUserId!), // Pass userId
          // tooltip: l10n.addConfigTooltip, // TODO: Add l10n.addConfigTooltip = '添加配置'
          tooltip: '添加配置', // Placeholder
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // <<< Add userId parameter >>>
  void _showAddEditDialog(BuildContext context, String userId, {UserAIModelConfigModel? config}) {
     final aiConfigBloc = context.read<AiConfigBloc>(); // Get BLoC from current context
    showDialog(
      context: context,
       barrierDismissible: false, // Prevent closing while dialog action is in progress
      builder: (_) => BlocProvider.value( // Provide the *existing* BLoC instance to the dialog
         value: aiConfigBloc,
         child: AddEditAiConfigDialog(
            userId: userId, // Pass userId from parameter
            configToEdit: config,
          ),
       ),
    );
  }

 // <<< Add userId parameter >>>
  void _showDeleteConfirmation(BuildContext context, String userId, UserAIModelConfigModel config) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // title: Text(l10n.deleteConfigTitle), // TODO: Add l10n.deleteConfigTitle = '删除配置'
        title: Text('删除配置'), // Placeholder
        // content: Text(l10n.deleteConfigConfirmation(config.alias)), // TODO: Add l10n.deleteConfigConfirmation
        content: Text('确定要删除配置 ${config.alias} 吗？此操作无法撤销。'), // Placeholder
       actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            // child: Text(l10n.cancel), // TODO: Add l10n.cancel = '取消'
            child: Text('取消'), // Placeholder
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              // <<< Use userId from parameter >>>
              context.read<AiConfigBloc>().add(DeleteAiConfig(userId: userId, configId: config.id));
              Navigator.pop(ctx); // Close confirmation dialog
            },
            // child: Text(l10n.delete), // TODO: Add l10n.delete = '删除'
            child: Text('删除'), // Placeholder
          ),
        ],
      ),
    );
  }
}

// TODO: Add localization strings comment moved to the bottom for clarity
// TODO: Add the following localization strings to your .arb files:
// - errorTitle: '错误'
// - errorUserNotLoggedIn: '无法加载配置：用户未登录。'
// - aiModelConfigTitle: 'AI 模型配置'
// - operationFailed: '操作失败'
// - operationSuccessful: '操作成功' (Optional)
// - errorLoadingConfig: '加载配置时出错'
// - retry: '重试'
// - noConfigsFound: '未找到任何配置'
// - addConfigTooltip: '添加配置'
// - deleteConfigTitle: '删除配置'
// - deleteConfigConfirmation(String alias): '确定要删除配置 {alias} 吗？此操作无法撤销。' (Make sure your .arb supports parameters)
// - cancel: '取消'
// - delete: '删除'