part of 'novel_import_bloc.dart';

/// 小说导入状态
abstract class NovelImportState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// 初始状态
class NovelImportInitial extends NovelImportState {
  @override
  List<Object?> get props => [];
}

/// 导入进行中状态
class NovelImportInProgress extends NovelImportState {
  /// 创建导入进行中状态
  NovelImportInProgress({
    required this.status,
    required this.message,
    this.jobId,
    this.progress = 0.0,
  });

  /// 当前状态 (PREPARING, UPLOADING, PROCESSING, SAVING, INDEXING)
  final String status;
  
  /// 状态消息
  final String message;
  
  /// 任务ID
  final String? jobId;
  
  /// 进度 (0.0-1.0)
  final double progress;

  @override
  List<Object?> get props => [status, message, jobId, progress];
}

/// 导入成功状态
class NovelImportSuccess extends NovelImportState {
  /// 创建导入成功状态
  NovelImportSuccess({
    required this.message,
  });

  /// 成功消息
  final String message;

  @override
  List<Object?> get props => [message];
}

/// 导入失败状态
class NovelImportFailure extends NovelImportState {
  /// 创建导入失败状态
  NovelImportFailure({
    required this.message,
  });

  /// 错误消息
  final String message;

  @override
  List<Object?> get props => [message];
} 