import 'package:ainoval/blocs/next_outline/next_outline_state.dart';
import 'package:ainoval/models/user_ai_model_config.dart';
import 'package:flutter/material.dart';

/// 结果卡片
class ResultCard extends StatefulWidget {
  /// 剧情选项
  final OutlineOptionState option;

  /// 是否被选中
  final bool isSelected;

  /// AI模型配置列表
  final List<UserAIModelConfig> aiModelConfigs;

  /// 选中回调
  final VoidCallback onSelected;

  /// 重新生成回调
  final Function(String configId, String? hint) onRegenerateSingle;

  /// 保存回调
  final Function(String insertType) onSave;

  const ResultCard({
    Key? key,
    required this.option,
    this.isSelected = false,
    required this.aiModelConfigs,
    required this.onSelected,
    required this.onRegenerateSingle,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  String? _selectedConfigId;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();

    // 默认选择第一个模型配置
    if (widget.aiModelConfigs.isNotEmpty) {
      _selectedConfigId = widget.aiModelConfigs.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovering
            ? (Matrix4.identity()..translate(0, -4))
            : Matrix4.identity(),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: _isHovering || widget.isSelected ? 6.0 : 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: widget.isSelected
                ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                : _isHovering
                    ? BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(128), width: 1.5)
                    : BorderSide.none,
          ),
          child: Stack(
            children: [
              // 卡片内容
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 内容区域
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题
                          Text(
                            widget.option.title ?? '生成中...',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // 内容
                          Expanded(
                            child: ValueListenableBuilder<String>(
                              valueListenable: widget.option.contentStreamController,
                              builder: (context, content, child) {
                                return SingleChildScrollView(
                                  child: Text(
                                    content.isEmpty ? '正在生成内容...' : content,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      height: 1.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 底部操作区
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 模型选择下拉框
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedConfigId,
                              items: widget.aiModelConfigs.map((config) {
                                return DropdownMenuItem<String>(
                                  value: config.id,
                                  child: Text(
                                    config.name,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedConfigId = value;
                                  });
                                }
                              },
                              isDense: true,
                              isExpanded: true,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 重新生成按钮
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: '使用选定模型重新生成',
                          onPressed: widget.option.isGenerating || _selectedConfigId == null
                              ? null
                              : () => widget.onRegenerateSingle(_selectedConfigId!, null),
                        ),

                        const SizedBox(width: 8),

                        // 选择按钮
                        ElevatedButton(
                          onPressed: widget.option.isGenerating
                              ? null
                              : widget.onSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                            foregroundColor: widget.isSelected
                                ? Colors.white
                                : Colors.black.withAlpha(222),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(widget.isSelected ? '已选择' : '选择此大纲'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 加载遮罩
              if (widget.option.isGenerating)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withAlpha(179),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
