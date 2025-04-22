import 'package:ainoval/blocs/next_outline/next_outline_bloc.dart';
import 'package:ainoval/blocs/next_outline/next_outline_event.dart';
import 'package:ainoval/blocs/next_outline/next_outline_state.dart';
import 'package:ainoval/models/next_outline/next_outline_dto.dart';
import 'package:ainoval/screens/next_outline/widgets/outline_generation_config_card.dart';
import 'package:ainoval/screens/next_outline/widgets/results_grid.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/next_outline_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/user_ai_model_config_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/next_outline_repository.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';

import 'package:ainoval/widgets/common/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 剧情推演屏幕
class NextOutlineScreen extends StatelessWidget {
  /// 小说ID
  final String novelId;
  
  /// 小说标题
  final String novelTitle;

  const NextOutlineScreen({
    Key? key,
    required this.novelId,
    required this.novelTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final editorRepository = EditorRepositoryImpl(apiClient: apiClient);
    
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<NextOutlineRepository>(
          create: (context) => NextOutlineRepositoryImpl(
            apiClient: apiClient,
          ),
        ),
        RepositoryProvider<UserAIModelConfigRepository>(
          create: (context) => UserAIModelConfigRepositoryImpl(
            apiClient: apiClient,
          ),
        ),
      ],
      child: BlocProvider(
        create: (context) => NextOutlineBloc(
          nextOutlineRepository: context.read<NextOutlineRepository>(),
          editorRepository: editorRepository,
          userAIModelConfigRepository: context.read<UserAIModelConfigRepository>(),
        )..add(NextOutlineInitialized(novelId: novelId)),
        child: _NextOutlineScreenContent(
          novelId: novelId,
          novelTitle: novelTitle,
        ),
      ),
    );
  }
}

/// 剧情推演屏幕内容
class _NextOutlineScreenContent extends StatelessWidget {
  /// 小说ID
  final String novelId;
  
  /// 小说标题
  final String novelTitle;

  const _NextOutlineScreenContent({
    Key? key,
    required this.novelId,
    required this.novelTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('剧情推演 - $novelTitle'),
        elevation: 1,
      ),
      body: BlocConsumer<NextOutlineBloc, NextOutlineState>(
        listenWhen: (previous, current) => 
          previous.generationStatus != current.generationStatus,
        listener: (context, state) {
          // 处理错误状态
          if (state.generationStatus == GenerationStatus.error && 
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          // 加载状态
          if (state.generationStatus == GenerationStatus.loadingChapters ||
              state.generationStatus == GenerationStatus.loadingModels) {
            return const Center(
              child: LoadingIndicator(message: '正在加载数据...'),
            );
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 配置面板
                OutlineGenerationConfigCard(
                  chapters: state.chapters,
                  aiModelConfigs: state.aiModelConfigs,
                  startChapterId: state.startChapterId,
                  endChapterId: state.endChapterId,
                  numOptions: state.numOptions,
                  authorGuidance: state.authorGuidance,
                  isGenerating: state.generationStatus == GenerationStatus.generatingInitial ||
                               state.generationStatus == GenerationStatus.generatingSingle,
                  onStartChapterChanged: (chapterId) {
                    context.read<NextOutlineBloc>().add(
                      UpdateChapterRangeRequested(
                        startChapterId: chapterId,
                        endChapterId: state.endChapterId,
                      ),
                    );
                  },
                  onEndChapterChanged: (chapterId) {
                    context.read<NextOutlineBloc>().add(
                      UpdateChapterRangeRequested(
                        startChapterId: state.startChapterId,
                        endChapterId: chapterId,
                      ),
                    );
                  },
                  onNumOptionsChanged: (value) {
                    // 暂存在本地，生成时会更新到状态
                  },
                  onAuthorGuidanceChanged: (value) {
                    // 暂存在本地，生成时会更新到状态
                  },
                  onGenerate: (numOptions, authorGuidance, selectedConfigIds) {
                    final request = GenerateNextOutlinesRequest(
                      startChapterId: state.startChapterId,
                      endChapterId: state.endChapterId,
                      numOptions: numOptions,
                      authorGuidance: authorGuidance,
                      selectedConfigIds: selectedConfigIds,
                    );
                    
                    context.read<NextOutlineBloc>().add(
                      GenerateNextOutlinesRequested(request: request),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // 结果区域
                ResultsGrid(
                  outlineOptions: state.outlineOptions,
                  selectedOptionId: state.selectedOptionId,
                  aiModelConfigs: state.aiModelConfigs,
                  isGenerating: state.generationStatus == GenerationStatus.generatingInitial,
                  isSaving: state.generationStatus == GenerationStatus.saving,
                  onOptionSelected: (optionId) {
                    context.read<NextOutlineBloc>().add(
                      OutlineSelected(optionId: optionId),
                    );
                  },
                  onRegenerateSingle: (optionId, configId, hint) {
                    final request = RegenerateOptionRequest(
                      optionId: optionId,
                      selectedConfigId: configId,
                      regenerateHint: hint,
                    );
                    
                    context.read<NextOutlineBloc>().add(
                      RegenerateSingleOutlineRequested(request: request),
                    );
                  },
                  onRegenerateAll: (hint) {
                    context.read<NextOutlineBloc>().add(
                      RegenerateAllOutlinesRequested(regenerateHint: hint),
                    );
                  },
                  onSaveOutline: (optionId, insertType) {
                    final request = SaveNextOutlineRequest(
                      outlineId: optionId,
                      insertType: insertType,
                    );
                    
                    context.read<NextOutlineBloc>().add(
                      SaveSelectedOutlineRequested(request: request),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
