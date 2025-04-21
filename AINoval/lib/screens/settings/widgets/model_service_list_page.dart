import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/screens/settings/widgets/model_service_card.dart';
import 'package:ainoval/screens/settings/widgets/model_service_header.dart';

/// 模型服务列表页面
/// 显示用户已配置的模型服务列表
class ModelServiceListPage extends StatefulWidget {
  const ModelServiceListPage({
    super.key,
    required this.userId,
    required this.onAddNew,
  });

  final String userId;
  final VoidCallback onAddNew;

  @override
  State<ModelServiceListPage> createState() => _ModelServiceListPageState();
}

class _ModelServiceListPageState extends State<ModelServiceListPage> {
  String _searchQuery = '';
  String _filterValue = 'all';

  @override
  void initState() {
    super.initState();
    // 加载用户配置列表
    _loadUserConfigs();
  }

  void _loadUserConfigs() {
    context.read<AiConfigBloc>().add(LoadAiConfigs(userId: widget.userId));
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _handleFilterChange(String value) {
    setState(() {
      _filterValue = value;
    });
  }

  void _handleVerify(String configId) {
    context.read<AiConfigBloc>().add(SetDefaultAiConfig(
      userId: widget.userId,
      configId: configId,
    ));
  }

  // 过滤配置列表
  List<UserAIModelConfigModel> _getFilteredConfigs(List<UserAIModelConfigModel> configs) {
    return configs.where((config) {
      // 搜索过滤
      final matchesSearch = _searchQuery.isEmpty ||
          config.alias.toLowerCase().contains(_searchQuery) ||
          config.provider.toLowerCase().contains(_searchQuery) ||
          config.modelName.toLowerCase().contains(_searchQuery);

      // 验证状态过滤
      bool matchesFilter = true;
      if (_filterValue == 'verified') {
        matchesFilter = config.isValidated;
      } else if (_filterValue == 'unverified') {
        matchesFilter = !config.isValidated;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // 将配置转换为卡片数据
  ModelServiceData _configToCardData(UserAIModelConfigModel config) {
    return ModelServiceData(
      id: config.id,
      name: config.alias,
      provider: config.provider,
      path: config.modelName,
      verified: config.isValidated,
      timestamp: config.updatedAt,
      description: '这是一个${config.provider}提供的${config.modelName}模型服务。',
      tags: ['AI', config.provider, if (config.isDefault) '默认'],
      apiEndpoint: config.apiEndpoint,
      performance: ModelPerformance(
        latency: 150, // 示例数据
        throughput: 10.5, // 示例数据
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 头部
          ModelServiceHeader(
            onSearch: _handleSearch,
            onAddNew: widget.onAddNew,
            onFilterChange: _handleFilterChange,
          ),

          // 内容区域
          Expanded(
            child: BlocBuilder<AiConfigBloc, AiConfigState>(
              builder: (context, state) {
                if (state.status == AiConfigStatus.loading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (state.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.withAlpha(204),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '加载失败',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadUserConfigs,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredConfigs = _getFilteredConfigs(state.configs);

                if (filteredConfigs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(102),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterValue != 'all'
                              ? '没有找到匹配的模型服务'
                              : '您还没有配置任何模型服务',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_searchQuery.isEmpty && _filterValue == 'all')
                          ElevatedButton.icon(
                            onPressed: widget.onAddNew,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('添加模型服务'),
                          ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 一行显示三个卡片
                    crossAxisSpacing: 16, // 水平间距
                    mainAxisSpacing: 16, // 垂直间距
                    childAspectRatio: 0.75, // 宽高比，调整为更适合卡片的比例
                  ),
                  itemCount: filteredConfigs.length,
                  itemBuilder: (context, index) {
                    final config = filteredConfigs[index];
                    final cardData = _configToCardData(config);

                    return ModelServiceCard(
                      model: cardData,
                      onVerify: _handleVerify,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
