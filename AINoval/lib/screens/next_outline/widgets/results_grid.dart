import 'package:ainoval/blocs/next_outline/next_outline_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/next_outline/next_outline_bloc.dart';
import '../../../models/novel_structure.dart';
import '../../../models/user_ai_model_config_model.dart';
import 'package:ainoval/screens/next_outline/widgets/result_card.dart';
import 'package:ainoval/widgets/common/empty_state_placeholder.dart';
import 'package:ainoval/widgets/common/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// 结果网格
class ResultsGrid extends StatefulWidget {
  /// 剧情选项列表
  final List<OutlineOptionState> outlineOptions;

  /// 当前选中的剧情选项ID
  final String? selectedOptionId;

  /// AI模型配置列表
  final List<UserAIModelConfigModel> aiModelConfigs;

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
        Row(
          children: [
            Icon(
              Icons.format_list_bulleted,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(
              '生成结果',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

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
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
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

              const SizedBox(height: 30),

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
            OutlinedButton.icon(
              onPressed: widget.isGenerating || widget.isSaving
                  ? null
                  : () => widget.onRegenerateAll(null),
              icon: const Icon(LucideIcons.refresh_cw, size: 18),
              label: const Text('重新生成(全部)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(LucideIcons.save, size: 18),
                label: Text(
                  widget.isSaving ? '保存中...' : '保存选中的大纲',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // 提示并重试
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _regenerateHintController,
                decoration: InputDecoration(
                  hintText: '输入提示以优化所有生成...',
                  prefixIcon: Icon(
                    LucideIcons.lightbulb, 
                    size: 18, 
                    color: Colors.amber.shade700
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.amber.shade500),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
              icon: const Icon(LucideIcons.sparkles, size: 18),
              label: const Text('提示并重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade100,
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                leading: const Icon(LucideIcons.folder_plus),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSaveOutline(widget.selectedOptionId!, 'NEW_CHAPTER');
                },
              ),

              // 添加到章节末尾
              ListTile(
                title: const Text('添加到章节末尾'),
                subtitle: const Text('在现有章节末尾添加一个场景'),
                leading: const Icon(LucideIcons.list_plus),
                onTap: () {
                  Navigator.of(context).pop();
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
    // 从 Bloc 状态获取章节列表
    final chapters = context.read<NextOutlineBloc>().state.chapters;

    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可用的章节来添加场景')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('选择要添加到的章节'),
          children: chapters.map((chapter) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // 调用保存回调，并传递选中的章节ID作为 precedingChapterId
                // 注意：后端需要根据 insertType='CHAPTER_END' 来处理这个 precedingChapterId
                widget.onSaveOutline(widget.selectedOptionId!, insertType); // 暂时保持原样，后端需明确处理
                // 如果后端确实需要 precedingChapterId 来表示添加到哪个章节末尾，应修改SaveNextOutlineRequest
                // 并在这里传递 chapter.id
                // 例如: widget.onSaveOutline(widget.selectedOptionId!, insertType, precedingChapterId: chapter.id);
              },
              child: Text(chapter.title, overflow: TextOverflow.ellipsis),
            );
          }).toList()
          ..add( // 添加取消选项
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            )
          ),
        );
      },
    );

    // 注意: 这里的 onSaveOutline 调用暂时保持原样，因为 SaveNextOutlineRequest 没有 precedingChapterId 字段
    // 如果需求是要明确指定添加到哪个章节末尾，后端 SaveNextOutlineRequest 和相关服务需要调整以接收章节ID。
  }

  /// 计算网格列数
  int _calculateCrossAxisCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 3;
  }
}
