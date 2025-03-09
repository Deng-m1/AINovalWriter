import 'package:equatable/equatable.dart';

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

// 过滤选项
enum FilterOption {
  all,
  inProgress,
  completed,
  recent,
}

class FilterNovels extends NovelListEvent {
  
  FilterNovels({required this.filterOption});
  final FilterOption filterOption;
  
  @override
  List<Object?> get props => [filterOption];
}

// 排序选项
enum SortOption {
  titleAsc,
  titleDesc,
  dateAsc,
  dateDesc,
  wordCountAsc,
  wordCountDesc,
}

class SortNovels extends NovelListEvent {
  
  SortNovels({required this.sortOption});
  final SortOption sortOption;
  
  @override
  List<Object?> get props => [sortOption];
}

// 分组选项
enum GroupOption {
  none,
  byDate,
  byCompletion,
}

class GroupNovels extends NovelListEvent {
  
  GroupNovels({required this.groupOption});
  final GroupOption groupOption;
  
  @override
  List<Object?> get props => [groupOption];
}

class DeleteNovel extends NovelListEvent {
  
  DeleteNovel({required this.novelId});
  final String novelId;
  
  @override
  List<Object?> get props => [novelId];
}

class CreateNovel extends NovelListEvent {
  
  CreateNovel({required this.title});
  final String title;
  
  @override
  List<Object?> get props => [title];
}

class UpdateNovel extends NovelListEvent {
  
  UpdateNovel({required this.novelId, required this.title});
  final String novelId;
  final String title;
  
  @override
  List<Object?> get props => [novelId, title];
} 