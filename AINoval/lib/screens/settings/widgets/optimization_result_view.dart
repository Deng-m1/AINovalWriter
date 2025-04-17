import 'package:flutter/material.dart';
import 'package:ainoval/models/prompt_models.dart';

/// 优化结果视图组件
class OptimizationResultView extends StatefulWidget {
  /// 原始内容
  final String original;
  
  /// 优化后的内容
  final String optimized;
  
  /// 优化区块
  final List<OptimizationSection> sections;
  
  /// 统计信息
  final OptimizationStatistics statistics;
  
  /// 接受全部优化的回调
  final VoidCallback onAccept;
  
  /// 拒绝优化的回调
  final VoidCallback onReject;
  
  /// 部分接受优化的回调（传入接受的区块索引列表）
  final Function(List<int>) onPartialAccept;
  
  const OptimizationResultView({
    Key? key,
    required this.original,
    required this.optimized,
    required this.sections,
    required this.statistics,
    required this.onAccept,
    required this.onReject,
    required this.onPartialAccept,
  }) : super(key: key);

  @override
  State<OptimizationResultView> createState() => _OptimizationResultViewState();
}

class _OptimizationResultViewState extends State<OptimizationResultView> {
  /// 选择接受的区块索引
  final List<int> _selectedSections = [];
  
  /// 显示模式：对比或单独显示
  bool _showDiff = true;
  
  @override
  void initState() {
    super.initState();
    
    // 初始默认选择所有修改的区块
    for (int i = 0; i < widget.sections.length; i++) {
      if (widget.sections[i].isModified) {
        _selectedSections.add(i);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和统计信息
          _buildHeader(context),
          const SizedBox(height: 16),
          
          // 内容区域
          SizedBox(
            height: 300, // 固定高度，可滚动
            child: _showDiff 
                ? _buildDiffView(context) 
                : _buildSideBySideView(context),
          ),
          
          const SizedBox(height: 16),
          
          // 底部操作按钮
          _buildBottomActions(context),
        ],
      ),
    );
  }
  
  /// 构建标题和统计信息
  Widget _buildHeader(BuildContext context) {
    final stats = widget.statistics;
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // 标题
        Icon(
          Icons.auto_awesome,
          size: 20,
          color: theme.colorScheme.secondary,
        ),
        const SizedBox(width: 8),
        Text(
          'AI优化结果',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
          ),
        ),
        const Spacer(),
        
        // 显示模式切换
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              label: Text('对比视图'),
              icon: Icon(Icons.compare_arrows),
            ),
            ButtonSegment<bool>(
              value: false,
              label: Text('并排视图'),
              icon: Icon(Icons.view_week),
            ),
          ],
          selected: {_showDiff},
          onSelectionChanged: (Set<bool> selection) {
            setState(() {
              _showDiff = selection.first;
            });
          },
        ),
        const SizedBox(width: 16),
        
        // 统计信息
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '词数变化: ${stats.originalWordCount} → ${stats.optimizedWordCount}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '优化比例: ${(stats.changeRatio * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建对比视图
  Widget _buildDiffView(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView.builder(
      itemCount: widget.sections.length,
      itemBuilder: (context, index) {
        final section = widget.sections[index];
        final isSelected = _selectedSections.contains(index);
        
        // 未修改的区块，没有选择框
        if (section.isUnchanged) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              section.content,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
          );
        }
        
        // 修改的区块，有选择框
        return Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected 
                      ? theme.colorScheme.secondary 
                      : theme.colorScheme.outline,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 原始内容
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.remove_circle_outline,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            section.original ?? '',
                            style: const TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 优化后内容
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            section.content,
                            style: const TextStyle(
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 选择按钮
            Positioned(
              top: 8,
              right: 8,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      if (!_selectedSections.contains(index)) {
                        _selectedSections.add(index);
                      }
                    } else {
                      _selectedSections.remove(index);
                    }
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// 构建并排视图
  Widget _buildSideBySideView(BuildContext context) {
    return Row(
      children: [
        // 原始内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '原始内容',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(widget.original),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // 优化后内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '优化后内容',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(widget.optimized),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// 构建底部操作按钮
  Widget _buildBottomActions(BuildContext context) {
    final int totalModified = widget.sections.where((s) => s.isModified).length;
    final int selectedCount = _selectedSections.length;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 已选择区块计数
        Text(
          '已选择 $selectedCount / $totalModified 处修改',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        
        // 操作按钮
        Row(
          children: [
            // 拒绝按钮
            OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('拒绝'),
              onPressed: widget.onReject,
            ),
            const SizedBox(width: 12),
            
            // 接受所选按钮
            FilledButton.tonal(
              onPressed: selectedCount > 0 
                  ? () => widget.onPartialAccept(_selectedSections)
                  : null,
              child: const Text('接受所选'),
            ),
            const SizedBox(width: 12),
            
            // 接受全部按钮
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('接受全部'),
              onPressed: widget.onAccept,
            ),
          ],
        ),
      ],
    );
  }
} 