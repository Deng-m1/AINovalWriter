import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 自动续写表单组件
class ContinueWritingForm extends StatefulWidget {
  const ContinueWritingForm({
    super.key,
    required this.novelId,
    required this.userId,
    required this.onCancel,
    required this.onSubmit,
    required this.userAiModelConfigRepository,
  });

  final String novelId;
  final String userId;
  final VoidCallback onCancel;
  final Function(Map<String, dynamic> parameters) onSubmit;
  final UserAIModelConfigRepository userAiModelConfigRepository;

  @override
  State<ContinueWritingForm> createState() => _ContinueWritingFormState();
}

class _ContinueWritingFormState extends State<ContinueWritingForm> {
  final _formKey = GlobalKey<FormState>();
  final _numberOfChaptersController = TextEditingController(text: '1');
  final _contextChapterCountController = TextEditingController(text: '3');
  final _customContextController = TextEditingController();
  final _writingStyleController = TextEditingController();

  List<UserAIModelConfigModel> _aiConfigs = [];
  bool _isLoadingConfigs = true;
  bool _isSubmitting = false;

  String? _selectedSummaryConfigId;
  String? _selectedContentConfigId;
  String _startContextMode = 'AUTO'; // 默认为自动模式
  
  @override
  void initState() {
    super.initState();
    _loadAiConfigs();
  }

  @override
  void dispose() {
    _numberOfChaptersController.dispose();
    _contextChapterCountController.dispose();
    _customContextController.dispose();
    _writingStyleController.dispose();
    super.dispose();
  }

  Future<void> _loadAiConfigs() async {
    setState(() {
      _isLoadingConfigs = true;
    });

    try {
      final configs = await widget.userAiModelConfigRepository.listConfigurations(
        userId: widget.userId,
        validatedOnly: true,
      );
      
      setState(() {
        _aiConfigs = configs;
        _isLoadingConfigs = false;
        
        // 如果有配置，预选第一个
        if (configs.isNotEmpty) {
          _selectedSummaryConfigId = configs.first.id;
          _selectedContentConfigId = configs.first.id;
        }
      });
    } catch (e) {
      AppLogger.e('ContinueWritingForm', '加载AI配置失败', e);
      setState(() {
        _isLoadingConfigs = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载AI配置失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final parameters = <String, dynamic>{
        'novelId': widget.novelId,
        'numberOfChapters': int.parse(_numberOfChaptersController.text),
        'aiConfigIdSummary': _selectedSummaryConfigId,
        'aiConfigIdContent': _selectedContentConfigId,
        'startContextMode': _startContextMode,
      };
      
      // 根据上下文模式添加对应参数
      if (_startContextMode == 'LAST_N_CHAPTERS') {
        parameters['contextChapterCount'] = int.parse(_contextChapterCountController.text);
      } else if (_startContextMode == 'CUSTOM') {
        parameters['customContext'] = _customContextController.text;
      }
      
      // 添加写作风格参数（如果有）
      if (_writingStyleController.text.isNotEmpty) {
        parameters['writingStyle'] = _writingStyleController.text;
      }
      
      // 提交表单
      widget.onSubmit(parameters);
    } catch (e) {
      AppLogger.e('ContinueWritingForm', '提交表单失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '自动续写设置',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 表单
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 续写章节数
                  TextFormField(
                    controller: _numberOfChaptersController,
                    decoration: const InputDecoration(
                      labelText: '续写章节数',
                      helperText: '设置要自动续写的章节数量',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入续写章节数';
                      }
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return '请输入有效的章节数';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 摘要模型选择
                  _isLoadingConfigs
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: '摘要生成模型',
                            helperText: '选择用于生成章节摘要的AI模型',
                            prefixIcon: Icon(Icons.summarize_outlined),
                          ),
                          value: _selectedSummaryConfigId,
                          items: _aiConfigs
                              .map((config) => DropdownMenuItem<String>(
                                    value: config.id,
                                    child: Text(config.alias ?? config.modelName),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSummaryConfigId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请选择摘要生成模型';
                            }
                            return null;
                          },
                        ),
                  const SizedBox(height: 16),
                  
                  // 内容模型选择
                  _isLoadingConfigs
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: '内容生成模型',
                            helperText: '选择用于生成章节内容的AI模型',
                            prefixIcon: Icon(Icons.text_fields),
                          ),
                          value: _selectedContentConfigId,
                          items: _aiConfigs
                              .map((config) => DropdownMenuItem<String>(
                                    value: config.id,
                                    child: Text(config.alias ?? config.modelName),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedContentConfigId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请选择内容生成模型';
                            }
                            return null;
                          },
                        ),
                  const SizedBox(height: 16),
                  
                  // 上下文模式选择
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '上下文模式',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // 上下文模式单选组
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildContextModeRadio('自动', 'AUTO'),
                          _buildContextModeRadio('最近N章', 'LAST_N_CHAPTERS'),
                          _buildContextModeRadio('自定义', 'CUSTOM'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '选择AI续写时使用的上下文模式',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 上下文章节数（仅当模式为LAST_N_CHAPTERS时显示）
                  if (_startContextMode == 'LAST_N_CHAPTERS')
                    TextFormField(
                      controller: _contextChapterCountController,
                      decoration: const InputDecoration(
                        labelText: '上下文章节数',
                        helperText: '设置AI生成时参考的最近章节数量',
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入上下文章节数';
                        }
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return '请输入有效的章节数';
                        }
                        return null;
                      },
                    ),
                  
                  // 自定义上下文（仅当模式为CUSTOM时显示）
                  if (_startContextMode == 'CUSTOM')
                    TextFormField(
                      controller: _customContextController,
                      decoration: const InputDecoration(
                        labelText: '自定义上下文',
                        helperText: '输入AI生成时参考的自定义上下文内容',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入自定义上下文';
                        }
                        if (value.length < 10) {
                          return '上下文内容过短，请提供更详细的信息';
                        }
                        return null;
                      },
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // 写作风格（可选）
                  TextFormField(
                    controller: _writingStyleController,
                    decoration: const InputDecoration(
                      labelText: '写作风格提示 (可选)',
                      helperText: '描述期望的写作风格，例如：悬疑、浪漫、幽默等',
                      prefixIcon: Icon(Icons.style),
                    ),
                    maxLines: 1,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 提交按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : widget.onCancel,
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        child: _isSubmitting
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('提交中...'),
                                ],
                              )
                            : const Text('开始任务'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建上下文模式单选按钮
  Widget _buildContextModeRadio(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _startContextMode == value,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _startContextMode = value;
          });
        }
      },
    );
  }
} 