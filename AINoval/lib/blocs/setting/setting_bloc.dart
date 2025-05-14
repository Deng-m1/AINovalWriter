import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/models/setting_group.dart';
import 'package:ainoval/services/api_service/repositories/novel_setting_repository.dart';
import 'package:ainoval/utils/logger.dart';

// 事件
abstract class SettingEvent extends Equatable {
  const SettingEvent();

  @override
  List<Object?> get props => [];
}

// 加载设定组列表事件
class LoadSettingGroups extends SettingEvent {
  final String novelId;
  
  const LoadSettingGroups(this.novelId);
  
  @override
  List<Object?> get props => [novelId];
}

// 加载设定条目列表事件
class LoadSettingItems extends SettingEvent {
  final String novelId;
  final String? groupId;
  final String? type;
  final String? name;
  final int page;
  final int size;
  
  const LoadSettingItems({
    required this.novelId, 
    this.groupId, 
    this.type, 
    this.name, 
    this.page = 0, 
    this.size = 20,
  });
  
  @override
  List<Object?> get props => [novelId, groupId, type, name, page, size];
}

// 创建设定组事件
class CreateSettingGroup extends SettingEvent {
  final String novelId;
  final SettingGroup group;
  
  const CreateSettingGroup({
    required this.novelId,
    required this.group,
  });
  
  @override
  List<Object?> get props => [novelId, group];
}

// 更新设定组事件
class UpdateSettingGroup extends SettingEvent {
  final String novelId;
  final String groupId;
  final SettingGroup group;
  
  const UpdateSettingGroup({
    required this.novelId,
    required this.groupId,
    required this.group,
  });
  
  @override
  List<Object?> get props => [novelId, groupId, group];
}

// 删除设定组事件
class DeleteSettingGroup extends SettingEvent {
  final String novelId;
  final String groupId;
  
  const DeleteSettingGroup({
    required this.novelId,
    required this.groupId,
  });
  
  @override
  List<Object?> get props => [novelId, groupId];
}

// 设置设定组激活状态事件
class SetGroupActiveContext extends SettingEvent {
  final String novelId;
  final String groupId;
  final bool isActive;
  
  const SetGroupActiveContext({
    required this.novelId,
    required this.groupId,
    required this.isActive,
  });
  
  @override
  List<Object?> get props => [novelId, groupId, isActive];
}

// 创建设定条目事件
class CreateSettingItem extends SettingEvent {
  final String novelId;
  final NovelSettingItem item;
  
  const CreateSettingItem({
    required this.novelId,
    required this.item,
  });
  
  @override
  List<Object?> get props => [novelId, item];
}

// 更新设定条目事件
class UpdateSettingItem extends SettingEvent {
  final String novelId;
  final String itemId;
  final NovelSettingItem item;
  
  const UpdateSettingItem({
    required this.novelId,
    required this.itemId,
    required this.item,
  });
  
  @override
  List<Object?> get props => [novelId, itemId, item];
}

// 删除设定条目事件
class DeleteSettingItem extends SettingEvent {
  final String novelId;
  final String itemId;
  
  const DeleteSettingItem({
    required this.novelId,
    required this.itemId,
  });
  
  @override
  List<Object?> get props => [novelId, itemId];
}

// 添加条目到设定组事件
class AddItemToGroup extends SettingEvent {
  final String novelId;
  final String groupId;
  final String itemId;
  
  const AddItemToGroup({
    required this.novelId,
    required this.groupId,
    required this.itemId,
  });
  
  @override
  List<Object?> get props => [novelId, groupId, itemId];
}

// 从设定组移除条目事件
class RemoveItemFromGroup extends SettingEvent {
  final String novelId;
  final String groupId;
  final String itemId;
  
  const RemoveItemFromGroup({
    required this.novelId,
    required this.groupId,
    required this.itemId,
  });
  
  @override
  List<Object?> get props => [novelId, groupId, itemId];
}

// 添加设定条目关系事件
class AddSettingRelationship extends SettingEvent {
  final String novelId;
  final String itemId;
  final String targetItemId;
  final String relationshipType;
  final String? description;
  
  const AddSettingRelationship({
    required this.novelId,
    required this.itemId,
    required this.targetItemId,
    required this.relationshipType,
    this.description,
  });
  
  @override
  List<Object?> get props => [novelId, itemId, targetItemId, relationshipType, description];
}

// 删除设定条目关系事件
class RemoveSettingRelationship extends SettingEvent {
  final String novelId;
  final String itemId;
  final String targetItemId;
  final String relationshipType;
  
  const RemoveSettingRelationship({
    required this.novelId,
    required this.itemId,
    required this.targetItemId,
    required this.relationshipType,
  });
  
  @override
  List<Object?> get props => [novelId, itemId, targetItemId, relationshipType];
}

// 状态
enum SettingStatus { initial, loading, success, failure }

class SettingState extends Equatable {
  final SettingStatus groupsStatus;
  final SettingStatus itemsStatus;
  final List<SettingGroup> groups;
  final List<NovelSettingItem> items;
  final String? selectedGroupId;
  final String? error;
  
  const SettingState({
    this.groupsStatus = SettingStatus.initial,
    this.itemsStatus = SettingStatus.initial,
    this.groups = const [],
    this.items = const [],
    this.selectedGroupId,
    this.error,
  });
  
  SettingState copyWith({
    SettingStatus? groupsStatus,
    SettingStatus? itemsStatus,
    List<SettingGroup>? groups,
    List<NovelSettingItem>? items,
    String? selectedGroupId,
    String? error,
  }) {
    return SettingState(
      groupsStatus: groupsStatus ?? this.groupsStatus,
      itemsStatus: itemsStatus ?? this.itemsStatus,
      groups: groups ?? this.groups,
      items: items ?? this.items,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      error: error ?? this.error,
    );
  }
  
  @override
  List<Object?> get props => [groupsStatus, itemsStatus, groups, items, selectedGroupId, error];
}

// Bloc
class SettingBloc extends Bloc<SettingEvent, SettingState> {
  final NovelSettingRepository settingRepository;
  
  SettingBloc({required this.settingRepository}) : super(const SettingState()) {
    on<LoadSettingGroups>(_onLoadSettingGroups);
    on<LoadSettingItems>(_onLoadSettingItems);
    on<CreateSettingGroup>(_onCreateSettingGroup);
    on<UpdateSettingGroup>(_onUpdateSettingGroup);
    on<DeleteSettingGroup>(_onDeleteSettingGroup);
    on<SetGroupActiveContext>(_onSetGroupActiveContext);
    on<CreateSettingItem>(_onCreateSettingItem);
    on<UpdateSettingItem>(_onUpdateSettingItem);
    on<DeleteSettingItem>(_onDeleteSettingItem);
    on<AddItemToGroup>(_onAddItemToGroup);
    on<RemoveItemFromGroup>(_onRemoveItemFromGroup);
    on<AddSettingRelationship>(_onAddSettingRelationship);
    on<RemoveSettingRelationship>(_onRemoveSettingRelationship);
  }
  
  Future<void> _onLoadSettingGroups(
    LoadSettingGroups event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(groupsStatus: SettingStatus.loading));
      
      final groups = await settingRepository.getNovelSettingGroups(
        novelId: event.novelId,
      );
      
      emit(state.copyWith(
        groupsStatus: SettingStatus.success,
        groups: groups,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '加载设定组失败', e);
      emit(state.copyWith(
        groupsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onLoadSettingItems(
    LoadSettingItems event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(
        itemsStatus: SettingStatus.loading,
        selectedGroupId: event.groupId,
      ));
      
      final items = await settingRepository.getNovelSettingItems(
        novelId: event.novelId,
        type: event.type,
        name: event.name,
        page: event.page,
        size: event.size,
        sortBy: 'name',
        sortDirection: 'asc',
      );
      
      emit(state.copyWith(
        itemsStatus: SettingStatus.success,
        items: items,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '加载设定条目失败', e);
      emit(state.copyWith(
        itemsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onCreateSettingGroup(
    CreateSettingGroup event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(groupsStatus: SettingStatus.loading));
      
      final createdGroup = await settingRepository.createSettingGroup(
        novelId: event.novelId,
        settingGroup: event.group,
      );
      
      // 更新列表，添加新组
      final updatedGroups = List<SettingGroup>.from(state.groups)..add(createdGroup);
      
      emit(state.copyWith(
        groupsStatus: SettingStatus.success,
        groups: updatedGroups,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '创建设定组失败', e);
      emit(state.copyWith(
        groupsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onUpdateSettingGroup(
    UpdateSettingGroup event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(groupsStatus: SettingStatus.loading));
      
      final updatedGroup = await settingRepository.updateSettingGroup(
        novelId: event.novelId,
        groupId: event.groupId,
        settingGroup: event.group,
      );
      
      // 更新列表，替换更新的组
      final updatedGroups = state.groups.map((group) {
        return group.id == event.groupId ? updatedGroup : group;
      }).toList();
      
      emit(state.copyWith(
        groupsStatus: SettingStatus.success,
        groups: updatedGroups,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '更新设定组失败', e);
      emit(state.copyWith(
        groupsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onDeleteSettingGroup(
    DeleteSettingGroup event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(groupsStatus: SettingStatus.loading));
      
      await settingRepository.deleteSettingGroup(
        novelId: event.novelId,
        groupId: event.groupId,
      );
      
      // 更新列表，移除删除的组
      final updatedGroups = state.groups.where((group) => group.id != event.groupId).toList();
      
      // 如果删除的是当前选中的组，清除选中状态
      final selectedGroupId = state.selectedGroupId == event.groupId ? null : state.selectedGroupId;
      
      emit(state.copyWith(
        groupsStatus: SettingStatus.success,
        groups: updatedGroups,
        selectedGroupId: selectedGroupId,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '删除设定组失败', e);
      emit(state.copyWith(
        groupsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onSetGroupActiveContext(
    SetGroupActiveContext event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(groupsStatus: SettingStatus.loading));
      
      final updatedGroup = await settingRepository.setGroupActiveContext(
        novelId: event.novelId,
        groupId: event.groupId,
        isActive: event.isActive,
      );
      
      // 更新列表，替换更新的组
      final updatedGroups = state.groups.map((group) {
        return group.id == event.groupId ? updatedGroup : group;
      }).toList();
      
      emit(state.copyWith(
        groupsStatus: SettingStatus.success,
        groups: updatedGroups,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '设置设定组激活状态失败', e);
      emit(state.copyWith(
        groupsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onCreateSettingItem(
    CreateSettingItem event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(itemsStatus: SettingStatus.loading));
      
      final createdItem = await settingRepository.createSettingItem(
        novelId: event.novelId,
        settingItem: event.item,
      );
      
      // 更新列表，添加新条目
      final updatedItems = List<NovelSettingItem>.from(state.items)..add(createdItem);
      
      emit(state.copyWith(
        itemsStatus: SettingStatus.success,
        items: updatedItems,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '创建设定条目失败', e);
      emit(state.copyWith(
        itemsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onUpdateSettingItem(
    UpdateSettingItem event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(itemsStatus: SettingStatus.loading));
      
      final updatedItem = await settingRepository.updateSettingItem(
        novelId: event.novelId,
        itemId: event.itemId,
        settingItem: event.item,
      );
      
      // 更新列表，替换更新的条目
      final updatedItems = state.items.map((item) {
        return item.id == event.itemId ? updatedItem : item;
      }).toList();
      
      emit(state.copyWith(
        itemsStatus: SettingStatus.success,
        items: updatedItems,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '更新设定条目失败', e);
      emit(state.copyWith(
        itemsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onDeleteSettingItem(
    DeleteSettingItem event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(itemsStatus: SettingStatus.loading));
      
      await settingRepository.deleteSettingItem(
        novelId: event.novelId,
        itemId: event.itemId,
      );
      
      // 更新列表，移除删除的条目
      final updatedItems = state.items.where((item) => item.id != event.itemId).toList();
      
      emit(state.copyWith(
        itemsStatus: SettingStatus.success,
        items: updatedItems,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '删除设定条目失败', e);
      emit(state.copyWith(
        itemsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onAddItemToGroup(
    AddItemToGroup event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(groupsStatus: SettingStatus.loading));
      
      final updatedGroup = await settingRepository.addItemToGroup(
        novelId: event.novelId,
        groupId: event.groupId,
        itemId: event.itemId,
      );
      
      // 更新列表，替换更新的组
      final updatedGroups = state.groups.map((group) {
        return group.id == event.groupId ? updatedGroup : group;
      }).toList();
      
      emit(state.copyWith(
        groupsStatus: SettingStatus.success,
        groups: updatedGroups,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '添加条目到设定组失败', e);
      emit(state.copyWith(
        groupsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onRemoveItemFromGroup(
    RemoveItemFromGroup event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(groupsStatus: SettingStatus.loading));
      
      await settingRepository.removeItemFromGroup(
        novelId: event.novelId,
        groupId: event.groupId,
        itemId: event.itemId,
      );
      
      // 重新加载设定组列表以获取更新后的状态
      final updatedGroups = await settingRepository.getNovelSettingGroups(
        novelId: event.novelId,
      );
      
      emit(state.copyWith(
        groupsStatus: SettingStatus.success,
        groups: updatedGroups,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '从设定组移除条目失败', e);
      emit(state.copyWith(
        groupsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onAddSettingRelationship(
    AddSettingRelationship event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(itemsStatus: SettingStatus.loading));
      
      final updatedItem = await settingRepository.addSettingRelationship(
        novelId: event.novelId,
        itemId: event.itemId,
        targetItemId: event.targetItemId,
        relationshipType: event.relationshipType,
        description: event.description,
      );
      
      // 更新列表，替换更新的条目
      final updatedItems = state.items.map((item) {
        return item.id == event.itemId ? updatedItem : item;
      }).toList();
      
      emit(state.copyWith(
        itemsStatus: SettingStatus.success,
        items: updatedItems,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '添加设定条目关系失败', e);
      emit(state.copyWith(
        itemsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onRemoveSettingRelationship(
    RemoveSettingRelationship event,
    Emitter<SettingState> emit,
  ) async {
    try {
      emit(state.copyWith(itemsStatus: SettingStatus.loading));
      
      await settingRepository.removeSettingRelationship(
        novelId: event.novelId,
        itemId: event.itemId,
        targetItemId: event.targetItemId,
        relationshipType: event.relationshipType,
      );
      
      // 重新加载该设定条目以获取更新后的状态
      final updatedItem = await settingRepository.getSettingItemDetail(
        novelId: event.novelId,
        itemId: event.itemId,
      );
      
      // 更新列表，替换更新的条目
      final updatedItems = state.items.map((item) {
        return item.id == event.itemId ? updatedItem : item;
      }).toList();
      
      emit(state.copyWith(
        itemsStatus: SettingStatus.success,
        items: updatedItems,
      ));
    } catch (e) {
      AppLogger.e('SettingBloc', '删除设定条目关系失败', e);
      emit(state.copyWith(
        itemsStatus: SettingStatus.failure,
        error: e.toString(),
      ));
    }
  }
} 