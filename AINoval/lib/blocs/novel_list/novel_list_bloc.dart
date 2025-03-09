import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/repositories/novel_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/novel_list/novel_list_event.dart';

// 状态定义
class NovelListState extends Equatable {
  
  const NovelListState({
    this.novels = const [],
    this.filteredNovels = const [],
    this.status = NovelListStatus.initial,
    this.errorMessage = '',
    this.searchQuery = '',
    this.filterOption = FilterOption.all,
    this.sortOption = SortOption.dateDesc,
    this.groupOption = GroupOption.none,
  });
  final List<NovelSummary> novels;
  final List<NovelSummary> filteredNovels;
  final NovelListStatus status;
  final String errorMessage;
  final String searchQuery;
  final FilterOption filterOption;
  final SortOption sortOption;
  final GroupOption groupOption;
  
  @override
  List<Object?> get props => [
    novels,
    filteredNovels,
    status,
    errorMessage,
    searchQuery,
    filterOption,
    sortOption,
    groupOption,
  ];
  
  NovelListState copyWith({
    List<NovelSummary>? novels,
    List<NovelSummary>? filteredNovels,
    NovelListStatus? status,
    String? errorMessage,
    String? searchQuery,
    FilterOption? filterOption,
    SortOption? sortOption,
    GroupOption? groupOption,
  }) {
    return NovelListState(
      novels: novels ?? this.novels,
      filteredNovels: filteredNovels ?? this.filteredNovels,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      filterOption: filterOption ?? this.filterOption,
      sortOption: sortOption ?? this.sortOption,
      groupOption: groupOption ?? this.groupOption,
    );
  }
}

// 状态枚举
enum NovelListStatus {
  initial,
  loading,
  loaded,
  error,
}

// BLoC实现
class NovelListBloc extends Bloc<NovelListEvent, NovelListState> {
  
  NovelListBloc({required this.repository}) : super(const NovelListState()) {
    on<LoadNovels>(_onLoadNovels);
    on<SearchNovels>(_onSearchNovels);
    on<FilterNovels>(_onFilterNovels);
    on<SortNovels>(_onSortNovels);
    on<GroupNovels>(_onGroupNovels);
    on<DeleteNovel>(_onDeleteNovel);
    on<CreateNovel>(_onCreateNovel);
    on<UpdateNovel>(_onUpdateNovel);
  }
  final NovelRepository repository;
  
  // 处理加载小说事件
  Future<void> _onLoadNovels(
    LoadNovels event,
    Emitter<NovelListState> emit,
  ) async {
    emit(state.copyWith(status: NovelListStatus.loading));
    
    try {
      final novels = await repository.getNovels();
      final filteredNovels = _applyFiltersAndSort(
        novels,
        state.searchQuery,
        state.filterOption,
        state.sortOption,
      );
      
      emit(state.copyWith(
        novels: novels,
        filteredNovels: filteredNovels,
        status: NovelListStatus.loaded,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: NovelListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
  
  // 处理搜索小说事件
  Future<void> _onSearchNovels(
    SearchNovels event,
    Emitter<NovelListState> emit,
  ) async {
    final query = event.query;
    
    emit(state.copyWith(
      searchQuery: query,
      status: NovelListStatus.loading,
    ));
    
    try {
      List<NovelSummary> filteredNovels;
      
      if (query.isEmpty) {
        // 如果查询为空，应用当前的过滤和排序
        filteredNovels = _applyFiltersAndSort(
          state.novels,
          '',
          state.filterOption,
          state.sortOption,
        );
      } else {
        // 否则，从仓库获取搜索结果
        filteredNovels = await repository.searchNovels(query);
        // 应用当前的过滤和排序
        filteredNovels = _applyFiltersAndSort(
          filteredNovels,
          query,
          state.filterOption,
          state.sortOption,
        );
      }
      
      emit(state.copyWith(
        filteredNovels: filteredNovels,
        status: NovelListStatus.loaded,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: NovelListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
  
  // 处理过滤小说事件
  void _onFilterNovels(
    FilterNovels event,
    Emitter<NovelListState> emit,
  ) {
    final filterOption = event.filterOption;
    
    emit(state.copyWith(
      filterOption: filterOption,
      status: NovelListStatus.loading,
    ));
    
    final filteredNovels = _applyFiltersAndSort(
      state.novels,
      state.searchQuery,
      filterOption,
      state.sortOption,
    );
    
    emit(state.copyWith(
      filteredNovels: filteredNovels,
      status: NovelListStatus.loaded,
    ));
  }
  
  // 处理排序小说事件
  void _onSortNovels(
    SortNovels event,
    Emitter<NovelListState> emit,
  ) {
    final sortOption = event.sortOption;
    
    emit(state.copyWith(
      sortOption: sortOption,
      status: NovelListStatus.loading,
    ));
    
    final filteredNovels = _applyFiltersAndSort(
      state.novels,
      state.searchQuery,
      state.filterOption,
      sortOption,
    );
    
    emit(state.copyWith(
      filteredNovels: filteredNovels,
      status: NovelListStatus.loaded,
    ));
  }
  
  // 处理分组小说事件
  void _onGroupNovels(
    GroupNovels event,
    Emitter<NovelListState> emit,
  ) {
    emit(state.copyWith(
      groupOption: event.groupOption,
    ));
  }
  
  // 处理删除小说事件
  Future<void> _onDeleteNovel(
    DeleteNovel event,
    Emitter<NovelListState> emit,
  ) async {
    try {
      await repository.deleteNovel(event.novelId);
      
      // 重新加载小说列表
      add(LoadNovels());
    } catch (e) {
      emit(state.copyWith(
        status: NovelListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
  
  // 处理创建小说事件
  Future<void> _onCreateNovel(
    CreateNovel event,
    Emitter<NovelListState> emit,
  ) async {
    try {
      await repository.createNovel(event.title);
      
      // 重新加载小说列表
      add(LoadNovels());
    } catch (e) {
      emit(state.copyWith(
        status: NovelListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
  
  // 处理更新小说事件
  Future<void> _onUpdateNovel(
    UpdateNovel event,
    Emitter<NovelListState> emit,
  ) async {
    try {
      await repository.updateNovel(event.novelId, event.title);
      
      // 重新加载小说列表
      add(LoadNovels());
    } catch (e) {
      emit(state.copyWith(
        status: NovelListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
  
  // 应用过滤和排序
  List<NovelSummary> _applyFiltersAndSort(
    List<NovelSummary> novels,
    String query,
    FilterOption filterOption,
    SortOption sortOption,
  ) {
    // 首先应用搜索查询
    var result = query.isEmpty
        ? List<NovelSummary>.from(novels)
        : novels.where((novel) => 
            novel.title.toLowerCase().contains(query.toLowerCase())).toList();
    
    // 然后应用过滤
    switch (filterOption) {
      case FilterOption.inProgress:
        result = result.where((novel) => novel.completionPercentage < 1.0).toList();
        break;
      case FilterOption.completed:
        result = result.where((novel) => novel.completionPercentage >= 1.0).toList();
        break;
      case FilterOption.recent:
        // 获取最近7天的小说
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        result = result.where((novel) => novel.lastEditTime.isAfter(sevenDaysAgo)).toList();
        break;
      case FilterOption.all:
      default:
        // 不需要额外过滤
        break;
    }
    
    // 最后应用排序
    switch (sortOption) {
      case SortOption.titleAsc:
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.titleDesc:
        result.sort((a, b) => b.title.compareTo(a.title));
        break;
      case SortOption.dateAsc:
        result.sort((a, b) => a.lastEditTime.compareTo(b.lastEditTime));
        break;
      case SortOption.dateDesc:
        result.sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));
        break;
      case SortOption.wordCountAsc:
        result.sort((a, b) => a.wordCount.compareTo(b.wordCount));
        break;
      case SortOption.wordCountDesc:
        result.sort((a, b) => b.wordCount.compareTo(a.wordCount));
        break;
    }
    
    return result;
  }
} 