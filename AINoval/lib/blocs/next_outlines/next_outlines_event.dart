import 'package:equatable/equatable.dart';
import 'package:ainoval/models/next_outline.dart';

/// 剧情推演事件基类
abstract class NextOutlinesEvent extends Equatable {
  const NextOutlinesEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化剧情推演
class InitializeNextOutlines extends NextOutlinesEvent {
  final String novelId;

  const InitializeNextOutlines({required this.novelId});

  @override
  List<Object?> get props => [novelId];
}

/// 生成剧情大纲
class GenerateNextOutlines extends NextOutlinesEvent {
  final String novelId;
  final String targetChapter;
  final int numOptions;
  final String? authorGuidance;

  const GenerateNextOutlines({
    required this.novelId,
    required this.targetChapter,
    required this.numOptions,
    this.authorGuidance,
  });

  @override
  List<Object?> get props => [novelId, targetChapter, numOptions, authorGuidance];
}

/// 选择剧情大纲
class SelectNextOutline extends NextOutlinesEvent {
  final String outlineId;

  const SelectNextOutline({required this.outlineId});

  @override
  List<Object?> get props => [outlineId];
}

/// 保存选中的剧情大纲
class SaveSelectedOutline extends NextOutlinesEvent {
  final String novelId;
  final String? targetChapterId;

  const SaveSelectedOutline({
    required this.novelId,
    this.targetChapterId,
  });

  @override
  List<Object?> get props => [novelId, targetChapterId];
}

/// 重新生成剧情大纲
class RegenerateNextOutlines extends NextOutlinesEvent {
  final String novelId;

  const RegenerateNextOutlines({required this.novelId});

  @override
  List<Object?> get props => [novelId];
}

/// 使用提示重新生成剧情大纲
class RegenerateWithHint extends NextOutlinesEvent {
  final String novelId;
  final String hint;

  const RegenerateWithHint({
    required this.novelId,
    required this.hint,
  });

  @override
  List<Object?> get props => [novelId, hint];
}

/// 清除剧情大纲
class ClearNextOutlines extends NextOutlinesEvent {}
