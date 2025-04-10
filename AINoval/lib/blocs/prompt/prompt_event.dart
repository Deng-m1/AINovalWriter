import 'package:ainoval/models/prompt_models.dart';
import 'package:equatable/equatable.dart';

/// 提示词管理事件基类
abstract class PromptEvent extends Equatable {
  const PromptEvent();

  @override
  List<Object?> get props => [];
}

/// 请求加载所有提示词事件
class LoadAllPromptsRequested extends PromptEvent {
  const LoadAllPromptsRequested();
}

/// 请求选择功能类型事件
class SelectFeatureRequested extends PromptEvent {
  const SelectFeatureRequested(this.featureType);

  final AIFeatureType featureType;

  @override
  List<Object?> get props => [featureType];
}

/// 请求保存提示词事件
class SavePromptRequested extends PromptEvent {
  const SavePromptRequested(this.featureType, this.promptText);

  final AIFeatureType featureType;
  final String promptText;

  @override
  List<Object?> get props => [featureType, promptText];
}

/// 请求重置提示词事件
class ResetPromptRequested extends PromptEvent {
  const ResetPromptRequested(this.featureType);

  final AIFeatureType featureType;

  @override
  List<Object?> get props => [featureType];
}

/// 生成场景摘要事件
class GenerateSceneSummary extends PromptEvent {
  const GenerateSceneSummary({
    required this.novelId,
    required this.sceneId,
  });

  final String novelId;
  final String sceneId;

  @override
  List<Object?> get props => [novelId, sceneId];
}

/// 摘要生成场景事件
class GenerateSceneFromSummary extends PromptEvent {
  const GenerateSceneFromSummary({
    required this.novelId,
    required this.summary,
  });

  final String novelId;
  final String summary;

  @override
  List<Object?> get props => [novelId, summary];
}