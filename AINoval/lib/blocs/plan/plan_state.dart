part of 'plan_bloc.dart';

abstract class PlanState extends Equatable {
  const PlanState();
  
  @override
  List<Object?> get props => [];
}

class PlanInitial extends PlanState {}

class PlanLoading extends PlanState {}

class PlanLoaded extends PlanState {
  
  const PlanLoaded({
    required this.novel,
    this.isDirty = false,
    this.isSaving = false,
    this.lastSaveTime,
    this.errorMessage,
  });
  final novel_models.Novel novel;
  final bool isDirty;
  final bool isSaving;
  final DateTime? lastSaveTime;
  final String? errorMessage;
  
  @override
  List<Object?> get props => [
    novel,
    isDirty,
    isSaving,
    lastSaveTime,
    errorMessage,
  ];
  
  PlanLoaded copyWith({
    novel_models.Novel? novel,
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSaveTime,
    String? errorMessage,
  }) {
    return PlanLoaded(
      novel: novel ?? this.novel,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      lastSaveTime: lastSaveTime ?? this.lastSaveTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class PlanError extends PlanState {
  const PlanError({required this.message});
  final String message;
  
  @override
  List<Object?> get props => [message];
} 