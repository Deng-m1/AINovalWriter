import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';
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

// 添加创建小说的事件
class CreateNovel extends NovelListEvent {
  
  CreateNovel({
    required this.title,
    this.seriesName,
  });
  final String title;
  final String? seriesName;
  
  @override
  List<Object?> get props => [title, seriesName];
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
    required List<NovelSummary> allNovels,
    this.sortOption = SortOption.lastEdited,
    this.filterOption = const FilterOption(),
    this.groupOption = GroupOption.none,
    this.searchQuery = '',
  }) : _allNovels = allNovels,
       novels = _applySearchAndFilterAndSort(allNovels, searchQuery, filterOption, sortOption);

  final List<NovelSummary> _allNovels;
  final List<NovelSummary> novels;

  final SortOption sortOption;
  final FilterOption filterOption;
  final GroupOption groupOption;
  final String searchQuery;
  
  @override
  List<Object?> get props => [_allNovels, novels, sortOption, filterOption, groupOption, searchQuery];

  static List<NovelSummary> _applySearchAndFilterAndSort(
    List<NovelSummary> novels,
    String searchQuery,
    FilterOption filterOption,
    SortOption sortOption,
  ) {
    List<NovelSummary> processedNovels = List.from(novels);

    if (searchQuery.isNotEmpty) {
      processedNovels = processedNovels.where((novel) {
        final titleMatch = novel.title.toLowerCase().contains(searchQuery.toLowerCase());
        final seriesMatch = novel.seriesName.toLowerCase().contains(searchQuery.toLowerCase());
        return titleMatch || seriesMatch;
      }).toList();
    }

    if (filterOption.series != null && filterOption.series!.isNotEmpty) {
      processedNovels = processedNovels.where((novel) {
        return novel.seriesName.toLowerCase() == filterOption.series!.toLowerCase();
      }).toList();
    }

    switch (sortOption) {
      case SortOption.lastEdited:
        processedNovels.sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));
        break;
      case SortOption.title:
        processedNovels.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.wordCount:
        processedNovels.sort((a, b) => b.wordCount.compareTo(a.wordCount));
        break;
      case SortOption.creationDate:
        processedNovels.sort((a, b) => b.lastEditTime.compareTo(a.lastEditTime));
        break;
      case SortOption.actCount:
        processedNovels.sort((a, b) => b.actCount.compareTo(a.actCount));
        break;
      case SortOption.chapterCount:
        processedNovels.sort((a, b) => b.chapterCount.compareTo(a.chapterCount));
        break;
      case SortOption.sceneCount:
        processedNovels.sort((a, b) => b.sceneCount.compareTo(a.sceneCount));
        break;
    }
    return processedNovels;
  }

  NovelListLoaded copyWith({
    List<NovelSummary>? allNovels,
    SortOption? sortOption,
    FilterOption? filterOption,
    GroupOption? groupOption,
    String? searchQuery,
  }) {
    return NovelListLoaded(
      allNovels: allNovels ?? _allNovels,
      sortOption: sortOption ?? this.sortOption,
      filterOption: filterOption ?? this.filterOption,
      groupOption: groupOption ?? this.groupOption,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
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
  actCount,
  chapterCount,
  sceneCount,
}

// 分组选项
enum GroupOption {
  none,
  series,
  status,
}

// 过滤选项
class FilterOption extends Equatable {
  
  const FilterOption({
    this.showCompleted = true,
    this.showInProgress = true,
    this.showNotStarted = true,
    this.minWordCount = 0,
    this.maxWordCount,
    this.series,
  });
  
  final bool showCompleted;
  final bool showInProgress;
  final bool showNotStarted;
  final int minWordCount;
  final int? maxWordCount;
  final String? series;
  
  @override
  List<Object?> get props => [
    showCompleted,
    showInProgress,
    showNotStarted,
    minWordCount,
    maxWordCount,
    series,
  ];
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
    on<CreateNovel>(_onCreateNovel);
  }
  
  final NovelRepository repository;
  
  // 防止重复加载标志  
  bool _isLoading = false;
  
  Future<void> _onLoadNovels(LoadNovels event, Emitter<NovelListState> emit) async {
    // 如果已经在加载中，则不重复加载
    if (_isLoading || state is NovelListLoading) return;
    
    _isLoading = true;
    emit(NovelListLoading());
    
    try {
      final novels = await repository.fetchNovels();
      // 转换为NovelSummary列表
      final novelSummaries = novels.map((novel) => NovelSummary(
        id: novel.id,
        title: novel.title,
        coverUrl: novel.coverUrl,
        lastEditTime: novel.updatedAt,
        wordCount: novel.wordCount,
        readTime: novel.readTime,
        version: novel.version,
        completionPercentage: 0.0,
        lastEditedChapterId: novel.lastEditedChapterId,
        author: novel.author?.username,
        contributors: novel.contributors,
        actCount: novel.acts.length,
        chapterCount: novel.acts.fold(0, (sum, act) => sum + act.chapters.length),
        sceneCount: novel.acts.fold(0, (sum, act) => 
          sum + act.chapters.fold(0, (sumChapter, chapter) => 
            sumChapter + chapter.scenes.length
          )
        ),
      )).toList();
      emit(NovelListLoaded(allNovels: novelSummaries));
    } catch (e) {
      emit(NovelListError(message: e.toString()));
    } finally {
      _isLoading = false;
    }
  }
  
  Future<void> _onSearchNovels(SearchNovels event, Emitter<NovelListState> emit) async {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      emit(currentState.copyWith(searchQuery: event.query));
    }
  }
  
  void _onFilterNovels(FilterNovels event, Emitter<NovelListState> emit) {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      emit(currentState.copyWith(filterOption: event.filterOption));
    }
  }
  
  void _onSortNovels(SortNovels event, Emitter<NovelListState> emit) {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      emit(currentState.copyWith(sortOption: event.sortOption));
    }
  }
  
  void _onGroupNovels(GroupNovels event, Emitter<NovelListState> emit) {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      emit(currentState.copyWith(groupOption: event.groupOption));
    }
  }
  
  Future<void> _onDeleteNovel(DeleteNovel event, Emitter<NovelListState> emit) async {
    final currentState = state;
    if (currentState is NovelListLoaded) {
      try {
        await repository.deleteNovel(event.id);
        final updatedNovels = currentState._allNovels.where((novel) => novel.id != event.id).toList();
        emit(currentState.copyWith(allNovels: updatedNovels));
      } catch (e) {
        emit(NovelListError(message: e.toString()));
      }
    }
  }
  
  // 添加创建小说的处理方法
  Future<void> _onCreateNovel(CreateNovel event, Emitter<NovelListState> emit) async {
    try {
      final newNovel = await repository.createNovel(event.title);
      
      // 将Novel转换为NovelSummary
      final novelSummary = NovelSummary(
        id: newNovel.id,
        title: newNovel.title,
        coverUrl: newNovel.coverUrl,
        lastEditTime: newNovel.updatedAt,
        wordCount: newNovel.wordCount,
        readTime: newNovel.readTime,
        version: newNovel.version,
        seriesName: event.seriesName ?? '',
        completionPercentage: 0.0,
        author: newNovel.author?.username,
        contributors: newNovel.contributors,
        actCount: newNovel.acts.length,
        chapterCount: newNovel.acts.fold(0, (sum, act) => sum + act.chapters.length),
        sceneCount: newNovel.acts.fold(0, (sum, act) => 
          sum + act.chapters.fold(0, (sumChapter, chapter) => 
            sumChapter + chapter.scenes.length
          )
        ),
      );
      
      // 直接更新状态，添加新创建的小说
      final currentState = state;
      if (currentState is NovelListLoaded) {
        final updatedNovels = List<NovelSummary>.from(currentState._allNovels)..add(novelSummary);
        emit(currentState.copyWith(allNovels: updatedNovels));
      } else {
        // 如果当前不是加载状态，则重新加载整个列表
        add(LoadNovels());
      }
    } catch (e) {
      emit(NovelListError(message: e.toString()));
    }
  }
} 