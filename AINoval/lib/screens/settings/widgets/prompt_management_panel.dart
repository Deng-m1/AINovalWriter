import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/prompt_models.dart';

/// 提示词管理面板
class PromptManagementPanel extends StatefulWidget {
  const PromptManagementPanel({Key? key}) : super(key: key);

  @override
  State<PromptManagementPanel> createState() => _PromptManagementPanelState();
}

class _PromptManagementPanelState extends State<PromptManagementPanel> {
  final TextEditingController _promptController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // 加载所有提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
  }
  
  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PromptBloc, PromptState>(
      listener: (context, state) {
        // 当选择了提示词类型时，更新编辑器内容
        if (state.selectedPrompt != null) {
          _promptController.text = state.selectedPrompt!.activePrompt;
        }
        
        // 显示错误信息
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '提示词管理',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              
              // 功能类型选择
              _buildFeatureTypeSelector(context, state),
              const SizedBox(height: 16),
              
              // 提示词编辑区域
              if (state.selectedFeatureType != null) ...[
                _buildPromptEditor(context, state),
              ] else ...[
                const Center(
                  child: Text('请选择一个功能类型'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  /// 构建功能类型选择区域
  Widget _buildFeatureTypeSelector(BuildContext context, PromptState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '功能类型',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        
        // 功能类型选择卡片
        Row(
          children: [
            _buildFeatureTypeCard(
              context,
              AIFeatureType.sceneToSummary,
              '场景生成摘要',
              '根据场景内容自动生成摘要',
              state.selectedFeatureType == AIFeatureType.sceneToSummary,
            ),
            const SizedBox(width: 16),
            _buildFeatureTypeCard(
              context,
              AIFeatureType.summaryToScene,
              '摘要生成场景',
              '根据摘要生成完整场景内容',
              state.selectedFeatureType == AIFeatureType.summaryToScene,
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建功能类型选择卡片
  Widget _buildFeatureTypeCard(
    BuildContext context,
    AIFeatureType featureType,
    String title,
    String description,
    bool isSelected,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          context.read<PromptBloc>().add(SelectFeatureRequested(featureType));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primaryContainer 
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.onPrimaryContainer 
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.onPrimaryContainer 
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建提示词编辑区域
  Widget _buildPromptEditor(BuildContext context, PromptState state) {
    final selectedPrompt = state.selectedPrompt;
    final isCustomized = selectedPrompt?.isCustomized ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '提示词编辑',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            
            // 自定义状态指示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCustomized 
                    ? Colors.blue.withOpacity(0.1) 
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCustomized ? Colors.blue : Colors.grey,
                ),
              ),
              child: Text(
                isCustomized ? '已自定义' : '系统默认',
                style: TextStyle(
                  fontSize: 12,
                  color: isCustomized ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // 提示词文本编辑器
        TextField(
          controller: _promptController,
          maxLines: 10,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: '请输入提示词',
            helperText: '为AI生成提供指导性的提示词，控制生成的风格和内容。',
            helperMaxLines: 2,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
        ),
        const SizedBox(height: 16),
        
        // 操作按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 重置按钮
            OutlinedButton(
              onPressed: () {
                // 弹出确认对话框
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('确认重置'),
                    content: Text('确定要恢复为系统默认提示词吗？自定义内容将会丢失。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (state.selectedFeatureType != null) {
                            context.read<PromptBloc>().add(
                              ResetPromptRequested(state.selectedFeatureType!),
                            );
                          }
                        },
                        child: Text('确定'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('重置为默认'),
            ),
            const SizedBox(width: 16),
            
            // 保存按钮
            FilledButton(
              onPressed: state.isLoading 
                  ? null 
                  : () {
                      if (state.selectedFeatureType != null) {
                        context.read<PromptBloc>().add(
                          SavePromptRequested(
                            state.selectedFeatureType!,
                            _promptController.text,
                          ),
                        );
                      }
                    },
              child: state.isLoading 
                  ? SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ) 
                  : Text('保存'),
            ),
          ],
        ),
      ],
    );
  }
} 