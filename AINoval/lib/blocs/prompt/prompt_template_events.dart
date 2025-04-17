import 'package:ainoval/models/prompt_models.dart';
import 'package:equatable/equatable.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';

/// 复制公共模板事件
class CopyPublicTemplateRequested extends PromptEvent {
  const CopyPublicTemplateRequested({required this.templateId});

  final String templateId;

  @override
  List<Object?> get props => [templateId];
}

/// 切换模板收藏状态事件
class ToggleTemplateFavoriteRequested extends PromptEvent {
  const ToggleTemplateFavoriteRequested({required this.templateId});

  final String templateId;

  @override
  List<Object?> get props => [templateId];
}

/// 创建提示词模板事件
class CreatePromptTemplateRequested extends PromptEvent {
  const CreatePromptTemplateRequested({
    required this.name,
    required this.content,
    required this.featureType,
  });

  final String name;
  final String content;
  final AIFeatureType featureType;

  @override
  List<Object?> get props => [name, content, featureType];
}

/// 更新提示词模板事件
class UpdatePromptTemplateRequested extends PromptEvent {
  const UpdatePromptTemplateRequested({
    required this.templateId,
    this.name,
    this.content,
  });

  final String templateId;
  final String? name;
  final String? content;

  @override
  List<Object?> get props => [templateId, name, content];
}

/// 删除模板事件
class DeleteTemplateRequested extends PromptEvent {
  const DeleteTemplateRequested({required this.templateId});

  final String templateId;

  @override
  List<Object?> get props => [templateId];
}

/// 流式优化提示词请求事件
class OptimizePromptStreamRequested extends PromptEvent {
  const OptimizePromptStreamRequested({
    required this.templateId,
    required this.request,
    this.onProgress,
    this.onResult,
    this.onError,
  });

  final String templateId;
  final OptimizePromptRequest request;
  final Function(double)? onProgress;
  final Function(OptimizationResult)? onResult;
  final Function(String)? onError;

  @override
  List<Object?> get props => [templateId, request];
}

/// 取消优化请求事件
class CancelOptimizationRequested extends PromptEvent {
  const CancelOptimizationRequested();
} 