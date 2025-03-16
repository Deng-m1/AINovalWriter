part of 'editor_version_bloc.dart';

/// 编辑器版本控制状态
abstract class EditorVersionState extends Equatable {
  const EditorVersionState();
  
  @override
  List<Object?> get props => [];
}

/// 初始状态
class EditorVersionInitial extends EditorVersionState {}

/// 加载中状态
class EditorVersionLoading extends EditorVersionState {}

/// 版本历史记录加载完成状态
class EditorVersionHistoryLoaded extends EditorVersionState {
  
  const EditorVersionHistoryLoaded(this.history);
  final List<SceneHistoryEntry> history;
  
  @override
  List<Object?> get props => [history];
}

/// 版本历史为空状态
class EditorVersionHistoryEmpty extends EditorVersionState {}

/// 版本差异加载完成状态
class EditorVersionDiffLoaded extends EditorVersionState {
  
  const EditorVersionDiffLoaded(this.diff);
  final SceneVersionDiff diff;
  
  @override
  List<Object?> get props => [diff];
}

/// 版本恢复完成状态
class EditorVersionRestored extends EditorVersionState {
  
  const EditorVersionRestored(this.scene);
  final Scene scene;
  
  @override
  List<Object?> get props => [scene];
}

/// 版本保存完成状态
class EditorVersionSaved extends EditorVersionState {
  
  const EditorVersionSaved(this.scene);
  final Scene scene;
  
  @override
  List<Object?> get props => [scene];
}

/// 错误状态
class EditorVersionError extends EditorVersionState {
  
  const EditorVersionError(this.message);
  final String message;
  
  @override
  List<Object?> get props => [message];
} 