import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/models/novel_structure.dart' hide Scene;

/// AI生成面板，提供场景摘要生成和摘要生成场景功能
class AIGenerationPanel extends StatefulWidget {
  const AIGenerationPanel({Key? key}) : super(key: key);

  @override
  State<AIGenerationPanel> createState() => _AIGenerationPanelState();
}

class _AIGenerationPanelState extends State<AIGenerationPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _styleInstructionsController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 加载提示词
    context.read<PromptBloc>().add(const LoadAllPromptsRequested());
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _summaryController.dispose();
    _styleInstructionsController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, editorState) {
        if (editorState is! EditorLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 面板标题
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'AI助手',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            
            // 标签栏
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '生成摘要'),
                Tab(text: '生成场景'),
              ],
            ),
            
            // 标签内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 场景生成摘要面板
                  _buildSceneToSummaryPanel(context, editorState),
                  
                  // 摘要生成场景面板
                  _buildSummaryToScenePanel(context, editorState),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// 构建场景生成摘要面板
  Widget _buildSceneToSummaryPanel(BuildContext context, EditorLoaded state) {
    // 获取当前活跃的场景
    final activeSceneId = state.activeSceneId;
    final activeScene = activeSceneId != null 
        ? _findSceneById(state.novel, activeSceneId) 
        : null;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 场景信息
          if (activeScene != null) ...[
            Text(
              '当前场景：${activeScene.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '字数：${activeScene.wordCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            Text(
              '请先选择一个场景',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 16),
          
          // 风格指令输入
          TextField(
            controller: _styleInstructionsController,
            decoration: const InputDecoration(
              labelText: '风格指令（可选）',
              hintText: '例如：简洁明了，突出关键情节',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          // 提示词信息
          BlocBuilder<PromptBloc, PromptState>(
            builder: (context, promptState) {
              final sceneToSummaryPrompt = promptState?.prompts[AIFeatureType.sceneToSummary];
              
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('使用的提示词', style: Theme.of(context).textTheme.labelMedium),
                        TextButton(
                          onPressed: () {
                            // 跳转到设置页面
                            // TODO: 实现跳转到提示词设置页面的逻辑
                          },
                          child: const Text('编辑'),
                        ),
                      ],
                    ),
                    Text(
                      sceneToSummaryPrompt?.activePrompt ?? '加载中...',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // 生成结果
          if (state.aiSummaryGenerationStatus == AIGenerationStatus.completed && 
              state.generatedSummary != null) ...[
            Text(
              '生成结果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(state.generatedSummary!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // 复制到剪贴板
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('复制'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: activeSceneId != null ? () {
                    // 使用生成的摘要更新场景摘要
                    if (state.generatedSummary != null && 
                        state.activeSceneId != null && 
                        state.activeChapterId != null && 
                        state.activeActId != null) {
                      context.read<EditorBloc>().add(UpdateSummary(
                        novelId: state.novel.id,
                        actId: state.activeActId!,
                        chapterId: state.activeChapterId!,
                        sceneId: state.activeSceneId!,
                        summary: state.generatedSummary!,
                      ));
                    }
                  } : null,
                  icon: const Icon(Icons.save),
                  label: const Text('保存为摘要'),
                ),
              ],
            ),
          ] else if (state.aiSummaryGenerationStatus == AIGenerationStatus.generating) ...[
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在生成摘要，请稍候...'),
                  ],
                ),
              ),
            ),
          ] else if (state.aiSummaryGenerationStatus == AIGenerationStatus.failed) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('生成失败: ${state.aiGenerationError ?? "未知错误"}'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: activeSceneId != null ? () {
                        // 重试
                        context.read<EditorBloc>().add(
                          GenerateSceneSummaryRequested(
                            sceneId: activeSceneId,
                            styleInstructions: _styleInstructionsController.text.isNotEmpty 
                                ? _styleInstructionsController.text 
                                : null,
                          ),
                        );
                      } : null,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Spacer(),
          ],
          
          // 生成按钮
          if (state.aiSummaryGenerationStatus != AIGenerationStatus.generating)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: activeSceneId != null ? () {
                  // 触发摘要生成
                  context.read<EditorBloc>().add(
                    GenerateSceneSummaryRequested(
                      sceneId: activeSceneId,
                      styleInstructions: _styleInstructionsController.text.isNotEmpty 
                          ? _styleInstructionsController.text 
                          : null,
                    ),
                  );
                } : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成摘要'),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 构建摘要生成场景面板
  Widget _buildSummaryToScenePanel(BuildContext context, EditorLoaded state) {
    final isGenerating = state.aiSceneGenerationStatus == AIGenerationStatus.generating;
    final hasGenerated = state.aiSceneGenerationStatus == AIGenerationStatus.completed && 
                         state.generatedSceneContent != null;
    final hasFailed = state.aiSceneGenerationStatus == AIGenerationStatus.failed;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 摘要文本输入
          TextField(
            controller: _summaryController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '场景摘要/大纲',
              hintText: '请输入场景大纲或摘要，AI将根据此内容生成完整场景',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          // 风格指令输入
          TextField(
            controller: _styleInstructionsController,
            decoration: const InputDecoration(
              labelText: '风格指令（可选）',
              hintText: '例如：多对话，少描写，悬疑风格',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          // 提示词信息
          BlocBuilder<PromptBloc, PromptState>(
            builder: (context, promptState) {
              final summaryToScenePrompt = promptState?.prompts[AIFeatureType.summaryToScene];
              
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('使用的提示词', style: Theme.of(context).textTheme.labelMedium),
                        TextButton(
                          onPressed: () {
                            // 跳转到设置页面
                            // TODO: 实现跳转到提示词设置页面的逻辑
                          },
                          child: const Text('编辑'),
                        ),
                      ],
                    ),
                    Text(
                      summaryToScenePrompt?.activePrompt ?? '加载中...',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // 章节选择（可选）
          if (state.novel.acts.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '目标章节（可选）',
                border: OutlineInputBorder(),
              ),
              value: state.activeChapterId,
              items: _buildChapterDropdownItems(state.novel),
              onChanged: (chapterId) {
                if (chapterId != null) {
                  // 查找选中章节所属的Act
                  String? actId;
                  for (final act in state.novel.acts) {
                    for (final chapter in act.chapters) {
                      if (chapter.id == chapterId) {
                        actId = act.id;
                        break;
                      }
                    }
                    if (actId != null) break;
                  }
                  
                  if (actId != null) {
                    // 更新活跃章节
                    context.read<EditorBloc>().add(SetActiveChapter(
                      actId: actId,
                      chapterId: chapterId,
                    ));
                  }
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          
          // 生成结果
          if (hasGenerated) ...[
            Text(
              '生成结果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(state.generatedSceneContent!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // 复制到剪贴板
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('复制'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: state.activeChapterId != null ? () {
                    // 创建新场景并使用生成的内容
                    // TODO: 实现创建新场景并使用生成内容的逻辑
                  } : null,
                  icon: const Icon(Icons.add),
                  label: const Text('创建新场景'),
                ),
              ],
            ),
          ] else if (isGenerating) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      state.isStreamingGeneration 
                          ? '正在流式生成场景内容...' 
                          : '正在生成场景内容，请稍候...',
                    ),
                    if (state.isStreamingGeneration && state.generatedSceneContent != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(color: Theme.of(context).colorScheme.outline),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(state.generatedSceneContent!),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else if (hasFailed) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('生成失败: ${state.aiGenerationError ?? "未知错误"}'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // 重试
                        if (_summaryController.text.isNotEmpty) {
                          context.read<EditorBloc>().add(
                            GenerateSceneFromSummaryRequested(
                              novelId: state.novel.id,
                              summary: _summaryController.text,
                              chapterId: state.activeChapterId,
                              styleInstructions: _styleInstructionsController.text.isNotEmpty 
                                  ? _styleInstructionsController.text 
                                  : null,
                            ),
                          );
                        }
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Spacer(),
          ],
          
          // 生成按钮
          if (!isGenerating)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _summaryController.text.isNotEmpty ? () {
                      // 触发场景生成
                      context.read<EditorBloc>().add(
                        GenerateSceneFromSummaryRequested(
                          novelId: state.novel.id,
                          summary: _summaryController.text,
                          chapterId: state.activeChapterId,
                          styleInstructions: _styleInstructionsController.text.isNotEmpty 
                              ? _styleInstructionsController.text 
                              : null,
                          useStreamingMode: true,
                        ),
                      );
                    } : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('流式生成场景'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _summaryController.text.isNotEmpty ? () {
                      // 触发场景生成（非流式）
                      context.read<EditorBloc>().add(
                        GenerateSceneFromSummaryRequested(
                          novelId: state.novel.id,
                          summary: _summaryController.text,
                          chapterId: state.activeChapterId,
                          styleInstructions: _styleInstructionsController.text.isNotEmpty 
                              ? _styleInstructionsController.text 
                              : null,
                          useStreamingMode: false,
                        ),
                      );
                    } : null,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('快速生成场景'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  /// 构建章节下拉菜单选项
  List<DropdownMenuItem<String>> _buildChapterDropdownItems(Novel novel) {
    final items = <DropdownMenuItem<String>>[];
    
    for (final act in novel.acts) {
      // 添加Act分组标题
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          child: Text(
            act.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      );
      
      // 添加Act下的Chapter
      for (final chapter in act.chapters) {
        items.add(
          DropdownMenuItem<String>(
            value: chapter.id,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(chapter.title),
            ),
          ),
        );
      }
    }
    
    return items;
  }
  
  /// 在Novel中查找指定ID的场景
  SceneInfo? _findSceneById(Novel novel, String sceneId) {
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        for (final scene in chapter.scenes) {
          if (scene.id == sceneId) {
            return SceneInfo(
              id: scene.id,
              title: '${act.title} > ${chapter.title} > 场景${chapter.scenes.indexOf(scene) + 1}',
              wordCount: scene.wordCount,
            );
          }
        }
      }
    }
    return null;
  }
}

/// 场景信息，用于显示
class SceneInfo {
  final String id;
  final String title;
  final int wordCount;
  
  SceneInfo({
    required this.id,
    required this.title,
    required this.wordCount,
  });
} 