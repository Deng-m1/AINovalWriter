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
  final List<SceneHistoryEntry> history;
  
  const EditorVersionHistoryLoaded(this.history);
  
  @override
  List<Object?> get props => [history];
}

/// 版本历史为空状态
class EditorVersionHistoryEmpty extends EditorVersionState {}

/// 版本差异加载完成状态
class EditorVersionDiffLoaded extends EditorVersionState {
  final SceneVersionDiff diff;
  
  const EditorVersionDiffLoaded(this.diff);
  
  @override
  List<Object?> get props => [diff];
}

/// 版本恢复完成状态
class EditorVersionRestored extends EditorVersionState {
  final Scene scene;
  
  const EditorVersionRestored(this.scene);
  
  @override
  List<Object?> get props => [scene];
}

/// 版本保存完成状态
class EditorVersionSaved extends EditorVersionState {
  final Scene scene;
  
  const EditorVersionSaved(this.scene);
  
  @override
  List<Object?> get props => [scene];
}

/// 错误状态
class EditorVersionError extends EditorVersionState {
  final String message;
  
  const EditorVersionError(this.message);
  
  @override
  List<Object?> get props => [message];
} 