part of 'sidebar_bloc.dart';



abstract class SidebarEvent extends Equatable {
  const SidebarEvent();

  @override
  List<Object> get props => [];
}

// 加载小说结构和摘要事件
class LoadNovelStructure extends SidebarEvent {
  final String novelId;

  const LoadNovelStructure(this.novelId);

  @override
  List<Object> get props => [novelId];
}
