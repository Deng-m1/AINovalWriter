import 'package:flutter/material.dart';
import 'package:ainoval/models/prompt_models.dart';

/// AI辅助工具栏组件
class AIAssistToolbar extends StatelessWidget {
  /// 是否正在处理中
  final bool isProcessing;
  
  /// 当前选择的优化风格
  final OptimizationStyle selectedStyle;
  
  /// 风格变更回调
  final Function(OptimizationStyle) onStyleChanged;
  
  /// 当前保留比例 (0.0-1.0)
  final double preserveRatio;
  
  /// 保留比例变更回调
  final Function(double) onRatioChanged;
  
  /// 点击优化按钮的回调
  final VoidCallback onOptimizeRequested;
  
  const AIAssistToolbar({
    Key? key,
    this.isProcessing = false,
    required this.selectedStyle,
    required this.onStyleChanged,
    required this.preserveRatio,
    required this.onRatioChanged,
    required this.onOptimizeRequested,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'AI 辅助优化',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 优化风格选择和保留比例设置
          Row(
            children: [
              // 优化风格选择
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('优化风格:'),
                    const SizedBox(height: 8),
                    _buildStyleSelector(context),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              
              // 保留比例设置
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '保留原始内容: ${(preserveRatio * 100).toInt()}%',
                    ),
                    Slider(
                      value: preserveRatio,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '${(preserveRatio * 100).toInt()}%',
                      onChanged: isProcessing ? null : onRatioChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 优化按钮
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: isProcessing
                  ? Container(
                      width: 16,
                      height: 16,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: Text(isProcessing ? '正在优化...' : 'AI优化'),
              onPressed: isProcessing ? null : onOptimizeRequested,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建风格选择器
  Widget _buildStyleSelector(BuildContext context) {
    return SegmentedButton<OptimizationStyle>(
      segments: [
        ButtonSegment<OptimizationStyle>(
          value: OptimizationStyle.professional,
          label: const Text('专业'),
          icon: const Icon(Icons.business),
        ),
        ButtonSegment<OptimizationStyle>(
          value: OptimizationStyle.creative,
          label: const Text('创意'),
          icon: const Icon(Icons.lightbulb),
        ),
        ButtonSegment<OptimizationStyle>(
          value: OptimizationStyle.concise,
          label: const Text('简洁'),
          icon: const Icon(Icons.short_text),
        ),
      ],
      selected: {selectedStyle},
      onSelectionChanged: isProcessing 
          ? null 
          : (Set<OptimizationStyle> selection) {
              if (selection.isNotEmpty) {
                onStyleChanged(selection.first);
              }
            },
    );
  }
} 