import 'package:equatable/equatable.dart';
import 'package:ainoval/models/prompt_models.dart';

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
  final AIFeatureType featureType;

  const SelectFeatureRequested(this.featureType);

  @override
  List<Object?> get props => [featureType];
}

/// 请求保存提示词事件
class SavePromptRequested extends PromptEvent {
  final AIFeatureType featureType;
  final String promptText;

  const SavePromptRequested(this.featureType, this.promptText);

  @override
  List<Object?> get props => [featureType, promptText];
}

/// 请求重置提示词事件
class ResetPromptRequested extends PromptEvent {
  final AIFeatureType featureType;

  const ResetPromptRequested(this.featureType);

  @override
  List<Object?> get props => [featureType];
} 