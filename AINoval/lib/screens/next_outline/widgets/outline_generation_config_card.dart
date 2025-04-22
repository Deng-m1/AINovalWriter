import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';


import '../../../models/novel_structure.dart';
import '../../../models/user_ai_model_config_model.dart';

/// 剧情大纲生成配置卡片
class OutlineGenerationConfigCard extends StatefulWidget {
  /// 章节列表
  final List<Chapter> chapters;

  /// AI模型配置列表
  final List<UserAIModelConfigModel> aiModelConfigs;

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
  String? _chapterRangeError;

  @override
  void initState() {
    super.initState();
    _numOptions = widget.numOptions;
    _authorGuidanceController = TextEditingController(text: widget.authorGuidance);

    // 默认选择第一个模型配置
    if (widget.aiModelConfigs.isNotEmpty) {
      _selectedConfigIds = [widget.aiModelConfigs.first.id];
    }
    
    // 初始化时验证章节范围
    _validateChapterRange(widget.startChapterId, widget.endChapterId);
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
    
    // 当起止章节ID变化时验证范围
    if (oldWidget.startChapterId != widget.startChapterId || 
        oldWidget.endChapterId != widget.endChapterId) {
      _validateChapterRange(widget.startChapterId, widget.endChapterId);
    }
  }
  
  /// 验证章节范围，确保开始章节不晚于结束章节
  void _validateChapterRange(String? startId, String? endId) {
    setState(() {
      _chapterRangeError = null;
      
      if (startId != null && endId != null && widget.chapters.isNotEmpty) {
        // 查找章节索引
        int? startIndex;
        int? endIndex;
        
        for (int i = 0; i < widget.chapters.length; i++) {
          if (widget.chapters[i].id == startId) {
            startIndex = i;
          }
          if (widget.chapters[i].id == endId) {
            endIndex = i;
          }
          
          // 如果两个索引都找到了，可以提前结束循环
          if (startIndex != null && endIndex != null) {
            break;
          }
        }
        
        // 检查有效性
        if (startIndex != null && endIndex != null && startIndex > endIndex) {
          _chapterRangeError = '起始章节不能晚于结束章节';
        }
      }
    });
  }

  @override
  void dispose() {
    _authorGuidanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 检查按钮是否应该禁用 (正在生成、没有选择模型或有错误)
    final bool isGenerateButtonDisabled = widget.isGenerating || 
                                          _selectedConfigIds.isEmpty ||
                                          _chapterRangeError != null;

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
            
            // 章节范围错误提示
            if (_chapterRangeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _chapterRangeError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                ),
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
                onPressed: isGenerateButtonDisabled
                    ? null
                    : () {
                        widget.onGenerate(
                          _numOptions,
                          _authorGuidanceController.text.isEmpty ? null : _authorGuidanceController.text,
                          _selectedConfigIds.isEmpty ? null : _selectedConfigIds,
                        );
                      },
                icon: widget.isGenerating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(LucideIcons.brain_circuit, size: 20),
                label: Text(widget.isGenerating ? '生成中...' : '生成剧情大纲'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          items: [2, 3, 4, 5].map((number) {
            return DropdownMenuItem<int>(
              value: number,
              child: Text('$number'),
            );
          }).toList(),
          onChanged: widget.isGenerating
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _numOptions = value;
                    });
                    widget.onNumOptionsChanged(value);
                  }
                },
          isExpanded: true,
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
          enabled: !widget.isGenerating,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '例如：希望侧重角色A的成长；引入新的反派；避免涉及魔法元素...',
            contentPadding: EdgeInsets.all(12),
          ),
          maxLines: 3,
          onChanged: widget.onAuthorGuidanceChanged,
        ),
        const SizedBox(height: 4),
        Text(
          '告诉 AI 您对下一段剧情的期望或限制',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 构建AI模型选择器
  Widget _buildAIModelSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI 模型选择',
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
              onSelected: widget.isGenerating
                  ? null
                  : (selected) {
                      setState(() {
                        if (selected) {
                          _selectedConfigIds.add(config.id);
                        } else {
                          _selectedConfigIds.remove(config.id);
                        }
                      });
                    },
              avatar: isSelected
                  ? Icon(
                      LucideIcons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  : null,
            );
          }).toList(),
        ),
        if (_selectedConfigIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '请至少选择一个 AI 模型',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          )
        else if (_selectedConfigIds.length < _numOptions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '注意：部分模型将被重复使用',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
