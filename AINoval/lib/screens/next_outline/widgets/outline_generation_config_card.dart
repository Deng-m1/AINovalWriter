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

  /// 跳转到添加模型页面的回调
  final VoidCallback? onNavigateToAddModel;

  /// 跳转到配置特定模型页面的回调
  final Function(String configId)? onConfigureModel;

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
    this.onNavigateToAddModel,
    this.onConfigureModel,
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

  // --- 新增：根据模型名称获取图标 ---
  IconData _getIconForModel(String modelName) {
    final lowerCaseName = modelName.toLowerCase();
    if (lowerCaseName.contains('gemini')) {
      return LucideIcons.gem;
    } else if (lowerCaseName.contains('deepseek')) {
      return LucideIcons.search_code;
    } else if (lowerCaseName.contains('gpt') || lowerCaseName.contains('openai')) {
      return LucideIcons.brain_circuit;
    } else if (lowerCaseName.contains('beta') || lowerCaseName.contains('test')) {
      return LucideIcons.flask_conical;
    } else if (lowerCaseName.contains('flash') || lowerCaseName.contains('fast')) {
       return LucideIcons.zap;
    }
    return LucideIcons.cpu; // 默认图标
  }
  // --- 结束新增 ---

  @override
  Widget build(BuildContext context) {
    // 检查按钮是否应该禁用 (正在生成、没有选择模型或有错误)
    final bool isGenerateButtonDisabled = widget.isGenerating || 
                                          _selectedConfigIds.isEmpty ||
                                          _chapterRangeError != null;

    return Card(
      elevation: 2,
      color: Colors.white, // 设置卡片背景为白色
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 增加圆角
      ),
      child: Padding(
        padding: const EdgeInsets.all(24), // 增加内边距
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth >= 960;
            
            return isWideScreen 
              ? _buildWideLayout(context, isGenerateButtonDisabled, constraints) 
              : _buildNarrowLayout(context, isGenerateButtonDisabled);
          },
        ),
      ),
    );
  }
  
  /// 宽屏布局（AI模型配置显示在右侧）
  Widget _buildWideLayout(BuildContext context, bool isGenerateButtonDisabled, BoxConstraints constraints) {
    final Color primaryColor = Colors.indigo; // 定义主色调为靛蓝色

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '生成选项',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor, // 使用靛蓝色
                ),
              ),
              const SizedBox(height: 24),
        
              _buildChapterConfigFields(constraints.maxWidth * 0.65, primaryColor),
              
              if (_chapterRangeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _chapterRangeError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ),
        
              const SizedBox(height: 24),
        
              _buildAuthorGuidanceField(primaryColor),
        
              const SizedBox(height: 32),
        
              Align(
                alignment: Alignment.centerRight,
                child: _buildGenerateButton(isGenerateButtonDisabled, primaryColor),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 32),
        
        if (widget.aiModelConfigs.isNotEmpty)
          Expanded(
            flex: 2,
            child: _buildAIModelSelection(true, primaryColor),
          ),
      ],
    );
  }
  
  /// 窄屏布局（AI模型配置显示在下方）
  Widget _buildNarrowLayout(BuildContext context, bool isGenerateButtonDisabled) {
    final Color primaryColor = Colors.indigo; // 定义主色调为靛蓝色

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '生成选项',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor, // 使用靛蓝色
          ),
        ),
        const SizedBox(height: 20),

        _buildChapterConfigFields(double.infinity, primaryColor),
        
        if (_chapterRangeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _chapterRangeError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
          ),

        const SizedBox(height: 24),

        _buildAuthorGuidanceField(primaryColor),

        const SizedBox(height: 24),

        if (widget.aiModelConfigs.isNotEmpty)
          _buildAIModelSelection(false, primaryColor),

        const SizedBox(height: 32),

        Align(
          alignment: Alignment.centerRight,
          child: _buildGenerateButton(isGenerateButtonDisabled, primaryColor),
        ),
      ],
    );
  }
  
  /// 构建章节配置区域
  Widget _buildChapterConfigFields(double totalWidth, Color primaryColor) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: totalWidth < 600 ? totalWidth : (totalWidth - 32) / 3,
          child: _buildStartChapterDropdown(primaryColor),
        ),

        SizedBox(
          width: totalWidth < 600 ? totalWidth : (totalWidth - 32) / 3,
          child: _buildEndChapterDropdown(primaryColor),
        ),

        SizedBox(
          width: totalWidth < 600 ? totalWidth : (totalWidth - 32) / 3,
          child: _buildNumOptionsDropdown(primaryColor),
        ),
      ],
    );
  }
  
  /// 构建生成按钮
  Widget _buildGenerateButton(bool isDisabled, Color primaryColor) {
    return ElevatedButton.icon(
      onPressed: isDisabled
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
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white, // 加载时图标颜色为白色
                strokeWidth: 2,
              ),
            )
          : const Icon(LucideIcons.brain_circuit, size: 20),
      label: Text(
        widget.isGenerating ? '生成中...' : '生成剧情大纲',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor, // 按钮背景色为靛蓝色
        foregroundColor: Colors.white, // 按钮文字和图标颜色为白色
        disabledBackgroundColor: primaryColor.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// 构建上下文开始章节下拉框
  Widget _buildStartChapterDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.book_copy, // 更换图标
              size: 18,
              color: primaryColor,
            ),
            const SizedBox(width: 8),
            const Text(
              '上下文开始章节',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.startChapterId,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor), // 聚焦时边框颜色
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
          icon: const Icon(LucideIcons.chevron_down, size: 20), // 更换图标
          dropdownColor: Colors.white,
        ),
        const SizedBox(height: 6),
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
  Widget _buildEndChapterDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.book_marked, // 更换图标
              size: 18,
              color: primaryColor,
            ),
            const SizedBox(width: 8),
            const Text(
              '上下文结束章节',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.endChapterId,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor), // 聚焦时边框颜色
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
          icon: const Icon(LucideIcons.chevron_down, size: 20), // 更换图标
          dropdownColor: Colors.white,
        ),
        const SizedBox(height: 6),
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
  Widget _buildNumOptionsDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.list_ordered, // 更换图标
              size: 18,
              color: primaryColor,
            ),
            const SizedBox(width: 8),
            const Text(
              '生成选项数量',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _numOptions,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor), // 聚焦时边框颜色
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
          icon: const Icon(LucideIcons.chevron_down, size: 20), // 更换图标
          dropdownColor: Colors.white,
        ),
      ],
    );
  }

  /// 构建作者引导文本框
  Widget _buildAuthorGuidanceField(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.lightbulb, // 更换图标
              size: 18,
              color: primaryColor,
            ),
            const SizedBox(width: 8),
            const Text(
              '作者偏好/引导 (可选)',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _authorGuidanceController,
          enabled: !widget.isGenerating,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor), // 聚焦时边框颜色
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            hintText: '例如：希望侧重角色A的成长；引入新的反派；避免涉及魔法元素...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: const TextStyle(height: 1.5),
          maxLines: 3,
          onChanged: widget.onAuthorGuidanceChanged,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              LucideIcons.info, // 更换图标
              size: 14,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              '告诉 AI 您对下一段剧情的期望或限制',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建AI模型选择器 (列表形式)
  Widget _buildAIModelSelection(bool isWideScreen, Color primaryColor) {
    // --- 不再过滤，使用全部模型 --- 
    final allConfigs = widget.aiModelConfigs;

    // 如果模型列表为空
    if (allConfigs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
             children: [
              Icon(
                LucideIcons.list_checks,
                size: 18,
                color: primaryColor.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
               const Text(
                'AI 模型选择',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (widget.onNavigateToAddModel != null)
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('添加模型', style: TextStyle(fontSize: 12)),
                  onPressed: widget.onNavigateToAddModel,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero)
                )
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '没有配置任何模型。请前往设置页面添加模型服务。',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          )
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
            Icon(
              LucideIcons.list_checks,
              size: 18,
              color: primaryColor,
            ),
            const SizedBox(width: 8),
             const Text(
              'AI 模型选择',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (widget.onNavigateToAddModel != null)
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('添加模型', style: TextStyle(fontSize: 12)),
                onPressed: widget.onNavigateToAddModel,
                style: TextButton.styleFrom(padding: EdgeInsets.zero)
              )
          ],
        ),
        const SizedBox(height: 12),

        // 模型列表 - 显示所有，区分已验证和未验证
        Column(
          children: allConfigs.map((config) { // <-- 使用全部列表
            final isSelected = _selectedConfigIds.contains(config.id);
            final isValidated = config.isValidated;
            final iconColor = isSelected ? primaryColor : (isValidated ? Colors.grey.shade700 : Colors.grey.shade400);
            final textColor = isValidated ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey.shade500;

            // --- 如果已验证 --- 
            if (isValidated) {
              return CheckboxListTile(
                title: Text(config.name, style: TextStyle(color: textColor)),
                value: isSelected,
                onChanged: widget.isGenerating
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedConfigIds.add(config.id);
                          } else {
                            _selectedConfigIds.remove(config.id);
                          }
                        });
                      },
                secondary: Icon(
                  _getIconForModel(config.name),
                  color: iconColor,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: primaryColor,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              );
            } 
            // --- 如果未验证 --- 
            else {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Icon( // 使用 CheckboxListTile 的 secondary 占位，保持对齐
                  _getIconForModel(config.name),
                  color: iconColor,
                ),
                title: Text(config.name, style: TextStyle(color: textColor, fontStyle: FontStyle.italic)),
                subtitle: Text('未验证', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                trailing: OutlinedButton.icon( // 添加配置按钮
                  icon: const Icon(Icons.settings_outlined, size: 14),
                  label: const Text('前往配置', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    if (widget.onConfigureModel != null) {
                      widget.onConfigureModel!(config.id);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: BorderSide(color: Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                enabled: false, // 整体禁用 ListTile 的交互
              );
            }
          }).toList(),
        ),

        // 提示信息 (保持不变)
        if (_selectedConfigIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  LucideIcons.circle_alert, // 更换图标
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '请至少选择一个 AI 模型',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else if (_selectedConfigIds.length < _numOptions)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  LucideIcons.circle_alert, // 更换图标
                  size: 16,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  '注意：部分模型将被重复使用',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
