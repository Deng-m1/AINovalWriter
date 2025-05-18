part of 'ai_setting_generation_bloc.dart';

abstract class AISettingGenerationState extends Equatable {
  const AISettingGenerationState();

  @override
  List<Object?> get props => [];
}

class AISettingGenerationInitial extends AISettingGenerationState {}

class AISettingGenerationLoadingChapters extends AISettingGenerationState {}

class AISettingGenerationDataLoaded extends AISettingGenerationState {
  final List<Chapter> chapters;
  // availableSettingTypes are derived from SettingType enum directly in UI
  // User selections are managed by the UI state for now.

  const AISettingGenerationDataLoaded({required this.chapters});

  @override
  List<Object> get props => [chapters];
}

class AISettingGenerationInProgress extends AISettingGenerationState {}

class AISettingGenerationSuccess extends AISettingGenerationState {
  final List<NovelSettingItem> generatedSettings;
  final List<Chapter> chapters; // Keep chapters loaded

  const AISettingGenerationSuccess({
    required this.generatedSettings,
    required this.chapters,
  });

  @override
  List<Object> get props => [generatedSettings, chapters];
}

class AISettingGenerationFailure extends AISettingGenerationState {
  final String error;
  final List<Chapter> chapters; // Keep chapters loaded if available

  const AISettingGenerationFailure({
    required this.error,
    required this.chapters,
  });

  @override
  List<Object?> get props => [error, chapters];
} 