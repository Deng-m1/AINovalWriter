import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/repositories/novel_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 事件定义
abstract class NovelListEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadNovels extends NovelListEvent {}

class SearchNovels extends NovelListEvent {
  
  SearchNovels({required this.query});
  final String query;
  
  @override
  List<Object?> get props => [query];
}

class FilterNovels extends NovelListEvent {
  
  FilterNovels({required this.filterOption});
  final FilterOption filterOption;
  
  @override
  List<Object?> get props => [filterOption];
}

class SortNovels extends NovelListEvent {
  
  SortNovels({required this.sortOption});
  final SortOption sortOption;
  
  @override
  List<Object?> get props => [sortOption];
}

class GroupNovels extends NovelListEvent {
  
  GroupNovels({required this.groupOption});
  final GroupOption groupOption;
  
  @override
  List<Object?> get props => [groupOption];
}

class DeleteNovel extends NovelListEvent {
  
  DeleteNovel({required this.id});
  final String id;
  
  @override
  List<Object?> get props => [id];
}

// 状态定义
abstract class NovelListState extends Equatable {
  @override
  List<Object?> get props => [];
}

class NovelListInitial extends NovelListState {}

class NovelListLoading extends NovelListState {}

class NovelListLoaded extends NovelListState {
  
  NovelListLoaded({
    required this.novels,
    this.sortOption = SortOption.lastEdited,
    this.filterOption = const FilterOption(),
    this.groupOption = GroupOption.none,
    this.searchQuery = '',
  });
  final List<NovelSummary> novels;
  final SortOption sortOption;
  final FilterOption filterOption;
  final GroupOption groupOption;
  final String searchQuery;
  
  @override
  List<Object?> get props => [novels, sortOption, filterOption, groupOption, searchQuery];
}

class NovelListError extends NovelListState {
  
  NovelListError({required this.message});
  final String message;
  
  @override
  List<Object?> get props => [message];
}

// 排序选项
enum SortOption {
  lastEdited,
  title,
  wordCount,
  creationDate,
}

// 分组选项
enum GroupOption {
  none,
  series,
  date,
}

// 过滤选项
class FilterOption extends Equatable {
  
  const FilterOption({
    this.showCompleted = true,
    this.showInProgress = true,
    this.showPlanned = true,
  });
  final bool showCompleted;
  final bool showInProgress;
  final bool showPlanned;
  
  @override
  List<Object?> get props => [showCompleted, showInProgress, showPlanned];
}

// Bloc实现
class NovelListBloc extends Bloc<NovelListEvent, NovelListState> {
  
  NovelListBloc({required this.repository}) : super(NovelListInitial()) {
    on<LoadNovels>(_onLoadNovels);
    on<SearchNovels>(_onSearchNovels);
    on<FilterNovels>(_onFilterNovels);
    on<SortNovels>(_onSortNovels);
    on<GroupNovels>(_onGroupNovels);
    on<DeleteNovel>(_onDeleteNovel);
  }
  final NovelRepository repository;
  
  Future<void> _onLoadNovels(LoadNovels event, Emitter<NovelListState> emit) async {
    emit(NovelListLoading());
    try {
      final novels = await repository.getNovels();
      emit(NovelListLoaded(novels: novels));
    } catch (e) {
      emit(NovelListError(message: e.toString()));
    }
  }
  
  Future<void> _onSearchNovels(SearchNovels event, Emitter<NovelListState> emit) async {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      try {
        final searchResults = await repository.searchNovels(event.query);
        emit(NovelListLoaded(
          novels: searchResults,
          searchQuery: event.query,
          sortOption: currentState.sortOption,
          filterOption: currentState.filterOption,
          groupOption: currentState.groupOption,
        ));
      } catch (e) {
        emit(NovelListError(message: e.toString()));
      }
    }
  }
  
  void _onFilterNovels(FilterNovels event, Emitter<NovelListState> emit) {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      emit(NovelListLoaded(
        novels: currentState.novels,
        searchQuery: currentState.searchQuery,
        sortOption: currentState.sortOption,
        filterOption: event.filterOption,
        groupOption: currentState.groupOption,
      ));
    }
  }
  
  void _onSortNovels(SortNovels event, Emitter<NovelListState> emit) {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      final sortedNovels = List<NovelSummary>.from(currentState.novels);
      
      switch (event.sortOption) {
        case SortOption.lastEdited:
          sortedNovels.sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));
          break;
        case SortOption.title:
          sortedNovels.sort((a, b) => a.title.compareTo(b.title));
          break;
        case SortOption.wordCount:
          sortedNovels.sort((a, b) => b.wordCount.compareTo(a.wordCount));
          break;
        case SortOption.creationDate:
          // 实际应用中可能需要单独的创建时间字段
          sortedNovels.sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));
          break;
      }
      
      emit(NovelListLoaded(
        novels: sortedNovels,
        searchQuery: currentState.searchQuery,
        sortOption: event.sortOption,
        filterOption: currentState.filterOption,
        groupOption: currentState.groupOption,
      ));
    }
  }
  
  void _onGroupNovels(GroupNovels event, Emitter<NovelListState> emit) {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      emit(NovelListLoaded(
        novels: currentState.novels,
        searchQuery: currentState.searchQuery,
        sortOption: currentState.sortOption,
        filterOption: currentState.filterOption,
        groupOption: event.groupOption,
      ));
    }
  }
  
  Future<void> _onDeleteNovel(DeleteNovel event, Emitter<NovelListState> emit) async {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      try {
        await repository.deleteNovel(event.id);
        final updatedNovels = currentState.novels.where((novel) => novel.id != event.id).toList();
        emit(NovelListLoaded(
          novels: updatedNovels,
          searchQuery: currentState.searchQuery,
          sortOption: currentState.sortOption,
          filterOption: currentState.filterOption,
          groupOption: currentState.groupOption,
        ));
      } catch (e) {
        emit(NovelListError(message: e.toString()));
      }
    }
  }
} 