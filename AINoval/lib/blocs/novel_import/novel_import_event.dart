part of 'novel_import_bloc.dart';

/// 小说导入事件
abstract class NovelImportEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// 导入小说文件事件
class ImportNovelFile extends NovelImportEvent {
  @override
  List<Object?> get props => [];
}

/// 导入状态更新事件
class ImportStatusUpdate extends NovelImportEvent {
  /// 创建导入状态更新事件
  ImportStatusUpdate({
    required this.status,
    required this.message,
    this.jobId,
  });

  /// 状态
  final String status;
  
  /// 消息
  final String message;
  
  /// 任务ID
  final String? jobId;

  @override
  List<Object?> get props => [status, message, jobId];
}

/// 重置导入状态事件
class ResetImportState extends NovelImportEvent {
  @override
  List<Object?> get props => [];
} 