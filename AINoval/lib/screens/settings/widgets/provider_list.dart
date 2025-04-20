import 'package:flutter/material.dart';

/// 提供商列表组件
/// 显示左侧的提供商列表，类似CherryStudio的UI
class ProviderList extends StatelessWidget {
  const ProviderList({
    super.key,
    required this.providers,
    required this.selectedProvider,
    required this.onProviderSelected,
  });

  final List<String> providers;
  final String? selectedProvider;
  final ValueChanged<String> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.2)
            : theme.colorScheme.surfaceContainerLowest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索模型平台...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
                    : theme.colorScheme.surfaceContainerLowest.withOpacity(0.7),
              ),
              onChanged: (value) {
                // 实现搜索功能
                // 这里可以添加搜索逻辑
              },
            ),
          ),
          
          // 提供商列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: providers.length,
              itemBuilder: (context, index) {
                final provider = providers[index];
                final isSelected = provider == selectedProvider;
                
                return _buildProviderItem(context, provider, isSelected);
              },
            ),
          ),
          
          // 底部添加按钮
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // 添加新提供商的逻辑
                },
                icon: const Icon(Icons.add),
                label: const Text('添加'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderItem(BuildContext context, String provider, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 获取提供商图标
    Widget providerIcon = _getProviderIcon(provider);
    
    return ListTile(
      leading: providerIcon,
      title: Text(
        _getProviderDisplayName(provider),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () => onProviderSelected(provider),
      // 如果是OpenRouter，添加一个标签
      trailing: provider.toLowerCase() == 'openrouter'
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ON',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
    );
  }

  // 获取提供商图标
  Widget _getProviderIcon(String provider) {
    final providerLower = provider.toLowerCase();
    
    // 根据提供商名称返回不同的图标
    IconData iconData;
    Color iconColor;
    
    if (providerLower == 'openai') {
      iconData = Icons.auto_awesome;
      iconColor = Colors.green;
    } else if (providerLower == 'anthropic') {
      iconData = Icons.psychology;
      iconColor = Colors.purple;
    } else if (providerLower == 'gemini') {
      iconData = Icons.star;
      iconColor = Colors.blue;
    } else if (providerLower == 'openrouter') {
      iconData = Icons.router;
      iconColor = Colors.orange;
    } else if (providerLower == 'ollama') {
      iconData = Icons.computer;
      iconColor = Colors.grey;
    } else if (providerLower == 'lm studio') {
      iconData = Icons.science;
      iconColor = Colors.indigo;
    } else {
      iconData = Icons.api;
      iconColor = Colors.grey;
    }
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 18,
      ),
    );
  }

  // 获取提供商显示名称
  String _getProviderDisplayName(String provider) {
    // 将提供商名称首字母大写
    if (provider.isEmpty) return '';
    
    if (provider.toLowerCase() == 'openai') {
      return 'OpenAI';
    } else if (provider.toLowerCase() == 'openrouter') {
      return 'OpenRouter';
    } else if (provider.toLowerCase() == 'lm studio') {
      return 'LM Studio';
    }
    
    return provider.substring(0, 1).toUpperCase() + provider.substring(1);
  }
}
