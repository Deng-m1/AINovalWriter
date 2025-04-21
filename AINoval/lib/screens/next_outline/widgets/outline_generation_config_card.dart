import 'package:ainoval/models/editor/chapter.dart';
import 'package:ainoval/models/user_ai_model_config.dart';
import 'package:flutter/material.dart';

/// 剧情大纲生成配置卡片
class OutlineGenerationConfigCard extends StatefulWidget {
  /// 章节列表
  final List<Chapter> chapters;

  /// AI模型配置列表
  final List<UserAIModelConfig> aiModelConfigs;

  /// 当前选中的上下文开始章节ID
  final String? startChapterId;

  /// 当前选中的上下文结束章节ID
  final String? endChapterId;

  /// 生成选项数量
  final int numOptions;

  /// 作者引导
  final String? authorGuidance;

  /// 是否正在生成
  final bool isGenerating;

  /// 开始章节变更回调
  final Function(String?) onStartChapterChanged;

  /// 结束章节变更回调
  final Function(String?) onEndChapterChanged;

  /// 选项数量变更回调
  final Function(int) onNumOptionsChanged;

  /// 作者引导变更回调
  final Function(String?) onAuthorGuidanceChanged;

  /// 生成回调
  final Function(int numOptions, String? authorGuidance, List<String>? selectedConfigIds) onGenerate;

  const OutlineGenerationConfigCard({
    Key? key,
    required this.chapters,
    required this.aiModelConfigs,
    this.startChapterId,
    this.endChapterId,
    this.numOptions = 3,
    this.authorGuidance,
    this.isGenerating = false,
    required this.onStartChapterChanged,
    required this.onEndChapterChanged,
    required this.onNumOptionsChanged,
    required this.onAuthorGuidanceChanged,
    required this.onGenerate,
  }) : super(key: key);

  @override
  State<OutlineGenerationConfigCard> createState() => _OutlineGenerationConfigCardState();
}

class _OutlineGenerationConfigCardState extends State<OutlineGenerationConfigCard> {
  late int _numOptions;
  late TextEditingController _authorGuidanceController;
  List<String> _selectedConfigIds = [];

  @override
  void initState() {
    super.initState();
    _numOptions = widget.numOptions;
    _authorGuidanceController = TextEditingController(text: widget.authorGuidance);

    // 默认选择第一个模型配置
    if (widget.aiModelConfigs.isNotEmpty) {
      _selectedConfigIds = [widget.aiModelConfigs.first.id];
    }
  }

  @override
  void didUpdateWidget(OutlineGenerationConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.authorGuidance != widget.authorGuidance) {
      _authorGuidanceController.text = widget.authorGuidance ?? '';
    }

    if (oldWidget.numOptions != widget.numOptions) {
      _numOptions = widget.numOptions;
    }
  }

  @override
  void dispose() {
    _authorGuidanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '生成选项',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 配置网格
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    // 上下文开始章节
                    SizedBox(
                      width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                      child: _buildStartChapterDropdown(),
                    ),

                    // 上下文结束章节
                    SizedBox(
                      width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                      child: _buildEndChapterDropdown(),
                    ),

                    // 生成选项数量
                    SizedBox(
                      width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                      child: _buildNumOptionsDropdown(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // 作者引导
            _buildAuthorGuidanceField(),

            const SizedBox(height: 16),

            // AI模型选择
            if (widget.aiModelConfigs.isNotEmpty)
              _buildAIModelSelection(),

            const SizedBox(height: 16),

            // 生成按钮
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: widget.isGenerating
                    ? null
                    : () => widget.onGenerate(
                          _numOptions,
                          _authorGuidanceController.text.isEmpty
                              ? null
                              : _authorGuidanceController.text,
                          _selectedConfigIds.isEmpty ? null : _selectedConfigIds,
                        ),
                icon: widget.isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.psychology),
                label: Text(widget.isGenerating ? '生成中...' : '生成剧情大纲'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建上下文开始章节下拉框
  Widget _buildStartChapterDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '上下文开始章节',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.startChapterId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          items: widget.chapters.map((chapter) {
            return DropdownMenuItem<String>(
              value: chapter.id,
              child: Text(
                chapter.title,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            widget.onStartChapterChanged(value);
          },
          hint: const Text('选择开始章节'),
          isExpanded: true,
        ),
        const SizedBox(height: 4),
        Text(
          '选择剧情上下文的起始章节',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 构建上下文结束章节下拉框
  Widget _buildEndChapterDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '上下文结束章节',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.endChapterId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          items: widget.chapters.map((chapter) {
            return DropdownMenuItem<String>(
              value: chapter.id,
              child: Text(
                chapter.title,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            widget.onEndChapterChanged(value);
          },
          hint: const Text('选择结束章节'),
          isExpanded: true,
        ),
        const SizedBox(height: 4),
        Text(
          '选择剧情上下文的结束章节',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 构建生成选项数量下拉框
  Widget _buildNumOptionsDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '生成选项数量',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _numOptions,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          items: [2, 3, 4, 5].map((count) {
            return DropdownMenuItem<int>(
              value: count,
              child: Text('$count'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _numOptions = value;
              });
              widget.onNumOptionsChanged(value);
            }
          },
          isExpanded: true,
        ),
        const SizedBox(height: 4),
        Text(
          '选择要生成的剧情选项数量',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 构建作者引导文本框
  Widget _buildAuthorGuidanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '作者偏好/引导 (可选)',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _authorGuidanceController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '例如：希望侧重角色A的成长；引入新的反派；避免涉及魔法元素...',
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          maxLines: 3,
          onChanged: widget.onAuthorGuidanceChanged,
        ),
        const SizedBox(height: 4),
        Text(
          '告诉AI您对下一段剧情的期望或限制',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 构建AI模型选择
  Widget _buildAIModelSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI模型选择',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.aiModelConfigs.map((config) {
            final isSelected = _selectedConfigIds.contains(config.id);

            return FilterChip(
              label: Text(config.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedConfigIds.add(config.id);
                  } else {
                    _selectedConfigIds.remove(config.id);
                  }
                });
              },
              avatar: isSelected ? const Icon(Icons.check, size: 16) : null,
            );
          }).toList(),
        ),
        if (_selectedConfigIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '请至少选择一个AI模型',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
        if (_selectedConfigIds.length < _numOptions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '提示：选择的模型数量少于生成选项数量，部分模型将被重复使用',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
