import 'package:ainoval/blocs/next_outline/next_outline_state.dart';
import 'package:ainoval/models/user_ai_model_config.dart';
import 'package:ainoval/screens/next_outline/widgets/result_card.dart';
import 'package:ainoval/widgets/common/empty_state_placeholder.dart';
import 'package:ainoval/widgets/common/loading_indicator.dart';
import 'package:flutter/material.dart';

/// 结果网格
class ResultsGrid extends StatefulWidget {
  /// 剧情选项列表
  final List<OutlineOptionState> outlineOptions;

  /// 当前选中的剧情选项ID
  final String? selectedOptionId;

  /// AI模型配置列表
  final List<UserAIModelConfig> aiModelConfigs;

  /// 是否正在生成
  final bool isGenerating;

  /// 是否正在保存
  final bool isSaving;

  /// 选项选中回调
  final Function(String optionId) onOptionSelected;

  /// 重新生成单个选项回调
  final Function(String optionId, String configId, String? hint) onRegenerateSingle;

  /// 重新生成全部选项回调
  final Function(String? hint) onRegenerateAll;

  /// 保存大纲回调
  final Function(String optionId, String insertType) onSaveOutline;

  const ResultsGrid({
    Key? key,
    required this.outlineOptions,
    this.selectedOptionId,
    required this.aiModelConfigs,
    this.isGenerating = false,
    this.isSaving = false,
    required this.onOptionSelected,
    required this.onRegenerateSingle,
    required this.onRegenerateAll,
    required this.onSaveOutline,
  }) : super(key: key);

  @override
  State<ResultsGrid> createState() => _ResultsGridState();
}

class _ResultsGridState extends State<ResultsGrid> {
  final TextEditingController _regenerateHintController = TextEditingController();

  @override
  void dispose() {
    _regenerateHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '生成结果',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        // 全局加载状态
        if (widget.isGenerating && widget.outlineOptions.isEmpty)
          const Center(
            child: LoadingIndicator(message: '正在生成剧情选项，请稍候...'),
          )

        // 空状态
        else if (widget.outlineOptions.isEmpty)
          const EmptyStatePlaceholder(
            icon: Icons.description_outlined,
            title: '尚未生成剧情',
            message: '请在上方配置选项后点击"生成剧情大纲"。',
          )

        // 结果网格
        else
          Column(
            children: [
              // 结果卡片网格
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.outlineOptions.length,
                    itemBuilder: (context, index) {
                      final option = widget.outlineOptions[index];

                      return ResultCard(
                        option: option,
                        isSelected: widget.selectedOptionId == option.optionId,
                        aiModelConfigs: widget.aiModelConfigs,
                        onSelected: () => widget.onOptionSelected(option.optionId),
                        onRegenerateSingle: (configId, hint) =>
                          widget.onRegenerateSingle(option.optionId, configId, hint),
                        onSave: (insertType) =>
                          widget.onSaveOutline(option.optionId, insertType),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // 全局操作按钮
              if (widget.outlineOptions.isNotEmpty && !widget.isGenerating)
                _buildGlobalActionButtons(),
            ],
          ),
      ],
    );
  }

  /// 构建全局操作按钮
  Widget _buildGlobalActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            // 重新生成按钮
            ElevatedButton.icon(
              onPressed: widget.isGenerating || widget.isSaving
                  ? null
                  : () => widget.onRegenerateAll(null),
              icon: const Icon(Icons.refresh),
              label: const Text('重新生成(全部)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black.withAlpha(222),
              ),
            ),

            const Spacer(),

            // 保存按钮
            if (widget.selectedOptionId != null)
              ElevatedButton.icon(
                onPressed: widget.isGenerating || widget.isSaving
                    ? null
                    : () => _showSaveOptionsDialog(context),
                icon: widget.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(widget.isSaving ? '保存中...' : '保存选中的大纲'),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // 提示并重试
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _regenerateHintController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入提示以优化所有生成...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            ElevatedButton.icon(
              onPressed: widget.isGenerating || widget.isSaving || _regenerateHintController.text.isEmpty
                  ? null
                  : () {
                      final hint = _regenerateHintController.text;
                      widget.onRegenerateAll(hint);
                      _regenerateHintController.clear();
                    },
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('提示并重试(全部)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade100,
                foregroundColor: Colors.brown.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 显示保存选项对话框
  void _showSaveOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('保存大纲'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('请选择保存方式：'),
              const SizedBox(height: 16),

              // 新建章节
              ListTile(
                title: const Text('新建章节'),
                subtitle: const Text('创建一个新章节，并添加一个场景'),
                leading: const Icon(Icons.add_circle_outline),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSaveOutline(widget.selectedOptionId!, 'NEW_CHAPTER');
                },
              ),

              // 添加到章节末尾
              ListTile(
                title: const Text('添加到章节末尾'),
                subtitle: const Text('在现有章节末尾添加一个场景'),
                leading: const Icon(Icons.playlist_add),
                onTap: () {
                  Navigator.of(context).pop();
                  // 这里应该弹出章节选择对话框
                  _showChapterSelectionDialog(context, 'CHAPTER_END');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 显示章节选择对话框
  void _showChapterSelectionDialog(BuildContext context, String insertType) {
    // 这里应该实现章节选择对话框
    // 由于时间关系，这里简化为直接使用默认章节
    widget.onSaveOutline(widget.selectedOptionId!, insertType);
  }

  /// 计算网格列数
  int _calculateCrossAxisCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 3;
  }
}
