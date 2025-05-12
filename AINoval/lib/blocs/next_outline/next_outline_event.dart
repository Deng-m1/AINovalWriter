import 'package:ainoval/models/next_outline/next_outline_dto.dart';
import 'package:equatable/equatable.dart';

/// 剧情推演事件
abstract class NextOutlineEvent extends Equatable {
  const NextOutlineEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化事件
class NextOutlineInitialized extends NextOutlineEvent {
  final String novelId;

  const NextOutlineInitialized({required this.novelId});

  @override
  List<Object?> get props => [novelId];
}

/// 加载章节列表事件
class LoadChaptersRequested extends NextOutlineEvent {
  final String novelId;

  const LoadChaptersRequested({required this.novelId});

  @override
  List<Object?> get props => [novelId];
}

/// 加载AI模型配置事件
class LoadAIModelConfigsRequested extends NextOutlineEvent {
  const LoadAIModelConfigsRequested();
}

/// 更新上下文章节范围事件
class UpdateChapterRangeRequested extends NextOutlineEvent {
  final String? startChapterId;
  final String? endChapterId;

  const UpdateChapterRangeRequested({
    this.startChapterId,
    this.endChapterId,
  });

  @override
  List<Object?> get props => [startChapterId, endChapterId];
}

/// 生成剧情大纲事件
class GenerateNextOutlinesRequested extends NextOutlineEvent {
  final GenerateNextOutlinesRequest request;

  const GenerateNextOutlinesRequested({required this.request});

  @override
  List<Object?> get props => [request];
}

/// 重新生成全部剧情大纲事件
class RegenerateAllOutlinesRequested extends NextOutlineEvent {
  final String? regenerateHint;

  const RegenerateAllOutlinesRequested({this.regenerateHint});

  @override
  List<Object?> get props => [regenerateHint];
}

/// 重新生成单个剧情大纲事件
class RegenerateSingleOutlineRequested extends NextOutlineEvent {
  final RegenerateOptionRequest request;

  const RegenerateSingleOutlineRequested({required this.request});

  @override
  List<Object?> get props => [request];
}

/// 选择剧情大纲事件
class OutlineSelected extends NextOutlineEvent {
  final String optionId;

  const OutlineSelected({required this.optionId});

  @override
  List<Object?> get props => [optionId];
}

/// 保存选中的剧情大纲事件
class SaveSelectedOutlineRequested extends NextOutlineEvent {
  final SaveNextOutlineRequest request;
  final int? selectedOutlineIndex;

  const SaveSelectedOutlineRequested({
    required this.request,
    this.selectedOutlineIndex,
  });

  @override
  List<Object?> get props => [request, selectedOutlineIndex];
}

/// 接收到大纲生成块事件
class OutlineGenerationChunkReceived extends NextOutlineEvent {
  final String optionId;
  final String? optionTitle;
  final String textChunk;
  final bool isFinalChunk;
  final String? error;

  const OutlineGenerationChunkReceived({
    required this.optionId,
    this.optionTitle,
    required this.textChunk,
    required this.isFinalChunk,
    this.error,
  });

  @override
  List<Object?> get props => [optionId, optionTitle, textChunk, isFinalChunk, error];
}

/// 生成错误事件
class GenerationErrorOccurred extends NextOutlineEvent {
  final String error;

  const GenerationErrorOccurred({required this.error});

  @override
  List<Object?> get props => [error];
}
