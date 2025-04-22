import 'package:ainoval/blocs/next_outline/next_outline_state.dart';
import '../../../models/novel_structure.dart';
import '../../../models/user_ai_model_config_model.dart';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

/// 结果卡片
class ResultCard extends StatefulWidget {
  /// 剧情选项
  final OutlineOptionState option;

  /// 是否被选中
  final bool isSelected;

  /// AI模型配置列表
  final List<UserAIModelConfigModel> aiModelConfigs;

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
        duration: const Duration(milliseconds: 250),
        transform: _isHovering
            ? (Matrix4.identity()..translate(0, -4))
            : Matrix4.identity(),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: _isHovering || widget.isSelected ? 8.0 : 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题
                          Row(
                            children: [
                              Icon(
                                Icons.auto_stories,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.option.title ?? '生成中...',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 内容
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ValueListenableBuilder<String>(
                                valueListenable: widget.option.contentStreamController,
                                builder: (context, content, child) {
                                  if (content.isEmpty && widget.option.isGenerating) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            '正在生成内容...',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return SingleChildScrollView(
                                    child: AnimatedTextKit(
                                      animatedTexts: [
                                        TypewriterAnimatedText(
                                          content,
                                          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            height: 1.6,
                                            color: Colors.grey.shade800,
                                          ),
                                          speed: const Duration(milliseconds: 40),
                                        ),
                                      ],
                                      isRepeatingAnimation: false,
                                      displayFullTextOnTap: true,
                                      key: ValueKey(widget.option.optionId + content),
                                    )
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 底部操作区
                  Container(
                    padding: const EdgeInsets.all(16),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedConfigId,
                                items: widget.aiModelConfigs
                                    .where((config) => config.isValidated)
                                    .map((config) {
                                  return DropdownMenuItem<String>(
                                    value: config.id,
                                    child: Text(
                                      config.name,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    if (widget.aiModelConfigs.any((c) => c.isValidated && c.id == value)) {
                                      setState(() {
                                        _selectedConfigId = value;
                                      });
                                    }
                                  }
                                },
                                isDense: true,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // 重新生成按钮
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: '使用选定模型重新生成',
                            onPressed: widget.option.isGenerating || _selectedConfigId == null
                                ? null
                                : () => widget.onRegenerateSingle(_selectedConfigId!, null),
                            color: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),

                        const SizedBox(width: 10),

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
                                : Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: widget.isSelected 
                                    ? Colors.transparent 
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                            elevation: widget.isSelected ? 2 : 0,
                          ),
                          child: Text(
                            widget.isSelected ? '已选择' : '选择此大纲',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                    color: Colors.white.withOpacity(0.7),
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
