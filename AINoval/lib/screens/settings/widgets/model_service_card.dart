import 'package:flutter/material.dart';

/// 模型服务卡片的数据模型
class ModelServiceData {
  final String id;
  final String name;
  final String provider;
  final String path;
  final bool verified;
  final String? status;
  final DateTime timestamp;
  final String? description;
  final List<String>? tags;
  final String? apiEndpoint;
  final ModelPerformance? performance;

  ModelServiceData({
    required this.id,
    required this.name,
    required this.provider,
    required this.path,
    required this.verified,
    this.status,
    required this.timestamp,
    this.description,
    this.tags,
    this.apiEndpoint,
    this.performance,
  });
}

/// 模型性能数据
class ModelPerformance {
  final int latency; // 毫秒
  final double throughput; // 请求/秒

  ModelPerformance({
    required this.latency,
    required this.throughput,
  });
}

/// 模型服务卡片组件
class ModelServiceCard extends StatefulWidget {
  const ModelServiceCard({
    super.key,
    required this.model,
    required this.onVerify,
  });

  final ModelServiceData model;
  final Function(String) onVerify;

  @override
  State<ModelServiceCard> createState() => _ModelServiceCardState();
}

class _ModelServiceCardState extends State<ModelServiceCard> {
  bool _expanded = false;
  // 未使用的变量已移除

  // 获取提供商图标
  Widget _getProviderLogo(String provider) {
    final providerLower = provider.toLowerCase();

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

    return Icon(
      iconData,
      color: iconColor,
      size: 24,
    );
  }

  // 获取状态颜色
  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('error') || statusLower.contains('失败')) {
      return Colors.red;
    } else if (statusLower.contains('warning') || statusLower.contains('警告')) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  // 获取状态文本
  String _getStatusText(String status) {
    return status;
  }

  // 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 获取性能颜色
  Color _getPerformanceColor(int latency) {
    if (latency < 100) {
      return Colors.green;
    } else if (latency < 300) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.model.verified
              ? theme.colorScheme.outline.withAlpha(51)
              : theme.colorScheme.outline.withAlpha(77),
          width: widget.model.verified ? 0.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片主体内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部：图标和名称
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 提供商图标
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: _getProviderLogo(widget.model.provider),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 名称
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.model.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.model.provider,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withAlpha(179),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // 操作菜单
                      PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                        padding: EdgeInsets.zero,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.copy, size: 16),
                                SizedBox(width: 8),
                                Text('复制路径', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                            onTap: () {
                              // 复制路径逻辑
                            },
                          ),
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.star_outline, size: 16),
                                SizedBox(width: 8),
                                Text('添加到收藏', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                            onTap: () {
                              // 添加到收藏逻辑
                            },
                          ),
                          if (widget.model.apiEndpoint != null)
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.open_in_new, size: 16),
                                  SizedBox(width: 8),
                                  Text('访问API', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                              onTap: () {
                                // 访问API逻辑
                              },
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 模型路径
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.model.path,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const Spacer(),

                  // 状态标签
                  Row(
                    children: [
                      // 验证状态
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.model.verified
                              ? Colors.green.withAlpha(26)
                              : Colors.orange.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.model.verified
                                ? Colors.green.withAlpha(77)
                                : Colors.orange.withAlpha(77),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.model.verified
                                  ? Icons.check_circle_outline
                                  : Icons.access_time,
                              size: 10,
                              color: widget.model.verified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              widget.model.verified ? '已验证' : '待验证',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: widget.model.verified
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // 时间戳
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 10,
                            color: theme.colorScheme.onSurface.withAlpha(128),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatDate(widget.model.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 底部操作区
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(26),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // 查看详情按钮
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _expanded ? '收起详情' : '查看详情',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withAlpha(179),
                        ),
                      ),
                    ),
                  ),
                ),

                // 设为默认按钮（仅未验证时显示）
                if (!widget.model.verified)
                  Expanded(
                    child: InkWell(
                      onTap: () => widget.onVerify(widget.model.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.outline.withAlpha(26),
                              width: 1,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '设为默认',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
