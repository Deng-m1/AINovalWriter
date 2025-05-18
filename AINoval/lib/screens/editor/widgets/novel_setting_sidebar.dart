import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/setting/setting_bloc.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/models/setting_group.dart';
import 'package:ainoval/models/setting_type.dart'; // 导入设定类型枚举
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/screens/editor/widgets/novel_setting_detail.dart';
import 'package:ainoval/screens/editor/widgets/novel_setting_group_dialog.dart';
import 'package:ainoval/screens/editor/widgets/menu_builder.dart';
import 'package:ainoval/screens/editor/widgets/dropdown_manager.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/screens/editor/widgets/custom_dropdown.dart';
import 'dart:async'; // 添加StreamSubscription需要的导入

/// 小说设定侧边栏组件
/// 
/// 用于管理小说设定条目和设定组，以树状列表方式展示
class NovelSettingSidebar extends StatefulWidget {
  final String novelId;
  
  const NovelSettingSidebar({
    Key? key,
    required this.novelId,
  }) : super(key: key);

  @override
  State<NovelSettingSidebar> createState() => _NovelSettingSidebarState();
}

class _NovelSettingSidebarState extends State<NovelSettingSidebar> {
  final TextEditingController _searchController = TextEditingController();
  
  // 是否正在创建或编辑设定条目
  bool _isEditingItem = false;
  
  // 是否正在查看设定条目详情
  bool _isViewingItem = false;
  
  // 当前选中的设定条目ID
  String? _selectedItemId;

  // 当前添加设定条目所属的组ID
  String? _currentGroupId;

  // 展开的设定组ID集合
  final Set<String> _expandedGroupIds = {};
  
  @override
  void initState() {
    super.initState();
    
    // 获取当前设定状态
    final settingState = context.read<SettingBloc>().state;
    
    AppLogger.i('NovelSettingSidebar', '初始化 - 组状态: ${settingState.groupsStatus}, 组数量: ${settingState.groups.length}, 条目状态: ${settingState.itemsStatus}, 条目数量: ${settingState.items.length}');
    
    // 只有当状态为初始状态或失败状态时才加载数据，避免重复请求
    if (settingState.groupsStatus == SettingStatus.initial ||
        settingState.groupsStatus == SettingStatus.failure) {
      context.read<SettingBloc>().add(LoadSettingGroups(widget.novelId));
    }
    
    if (settingState.itemsStatus == SettingStatus.initial ||
        settingState.itemsStatus == SettingStatus.failure) {
      context.read<SettingBloc>().add(LoadSettingItems(novelId: widget.novelId));
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // 切换设定组展开/折叠状态
  void _toggleGroupExpansion(String groupId) {
    final settingState = context.read<SettingBloc>().state;
    final group = settingState.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => SettingGroup(name: '未知设定组'),
    );
    
    setState(() {
      if (_expandedGroupIds.contains(groupId)) {
        _expandedGroupIds.remove(groupId);
        AppLogger.i('NovelSettingSidebar', '折叠设定组: ${group.name}');
      } else {
        _expandedGroupIds.add(groupId);
        AppLogger.i('NovelSettingSidebar', '展开设定组: ${group.name}, 组内条目ID数量: ${group.itemIds?.length ?? 0}, 实际条目数量: ${settingState.items.length}');
        
        // 检查是否有任何组内条目未加载
        final missingItems = <String>[];
        if (group.itemIds != null) {
          for (final itemId in group.itemIds!) {
            if (!settingState.items.any((item) => item.id == itemId)) {
              missingItems.add(itemId);
            }
          }
        }
        
        // 如果有未加载的条目，重新加载所有条目
        if (missingItems.isNotEmpty) {
          AppLogger.i('NovelSettingSidebar', '发现未加载的条目: $missingItems, 重新加载所有条目');
          context.read<SettingBloc>().add(LoadSettingItems(
            novelId: widget.novelId,
          ));
        }
      }
    });
  }
  
  // 创建新设定组
  void _createSettingGroup() {
    final settingBloc = context.read<SettingBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: settingBloc,
          child: NovelSettingGroupDialog(
            novelId: widget.novelId,
            onSave: (group) {
              settingBloc.add(CreateSettingGroup(
                novelId: widget.novelId,
                group: group,
              ));
            },
          ),
        );
      },
    );
  }
  
  // 编辑设定组
  void _editSettingGroup(String groupId) {
    final settingBloc = context.read<SettingBloc>();
    final group = settingBloc.state.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => SettingGroup(name: '未知设定组'),
    );
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: settingBloc,
          child: NovelSettingGroupDialog(
            novelId: widget.novelId,
            group: group,
            onSave: (updatedGroup) {
              settingBloc.add(UpdateSettingGroup(
                novelId: widget.novelId,
                groupId: groupId,
                group: updatedGroup,
              ));
            },
          ),
        );
      },
    );
  }
  
  // 删除设定组
  void _deleteSettingGroup(String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个设定组吗？组内的设定条目将不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SettingBloc>().add(DeleteSettingGroup(
                novelId: widget.novelId,
                groupId: groupId,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  // 创建新设定条目
  void _createSettingItem({String? groupId}) {
    setState(() {
      _isEditingItem = true;
      _selectedItemId = null;
      _currentGroupId = groupId;  // 记录当前组ID
    });
  }
  
  // 编辑设定条目
  void _editSettingItem(String itemId) {
    setState(() {
      _isEditingItem = true;
      _selectedItemId = itemId;
    });
  }
  
  // 查看设定条目
  void _viewSettingItem(String itemId) {
    setState(() {
      _isViewingItem = true;
      _selectedItemId = itemId;
    });
  }
  
  // 删除设定条目
  void _deleteSettingItem(String itemId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个设定条目吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SettingBloc>().add(DeleteSettingItem(
                novelId: widget.novelId,
                itemId: itemId,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  // 保存设定条目
  void _saveSettingItem(NovelSettingItem item, String? groupId) {
    AppLogger.i('NovelSettingSidebar', '保存设定条目: ${item.name}, ID=${item.id}, 传入组ID=${groupId}');
    
    if (item.id == null) {
      // 创建新条目
      final settingBloc = context.read<SettingBloc>();
      
      // 改为先清除状态，再进行API操作，避免状态变化导致bloc关闭
      setState(() {
        _isEditingItem = false;
        _selectedItemId = null;
        _currentGroupId = null; // 清除当前组ID
      });
      
      if (groupId != null) {
        // 使用传入的组ID创建并添加到组中
        settingBloc.add(CreateSettingItemAndAddToGroup(
          novelId: widget.novelId,
          item: item,
          groupId: groupId,
        ));
        
        AppLogger.i('NovelSettingSidebar', '使用组ID创建并添加到组: $groupId');
      } else {
        // 无组ID时直接创建条目
        settingBloc.add(CreateSettingItem(
          novelId: widget.novelId,
          item: item,
        ));
        
        AppLogger.i('NovelSettingSidebar', '无组ID创建');
      }
    } else {
      // 更新现有条目
      context.read<SettingBloc>().add(UpdateSettingItem(
        novelId: widget.novelId,
        itemId: item.id!,
        item: item,
      ));
      
      // 返回到列表视图
      setState(() {
        _isEditingItem = false;
        _selectedItemId = null;
        _currentGroupId = null; // 清除当前组ID
      });
    }
  }
  
  // 取消编辑设定条目
  void _cancelEditingItem() {
    setState(() {
      _isEditingItem = false;
      _selectedItemId = null;
      _currentGroupId = null; // 清除当前组ID
    });
  }
  
  // 取消查看设定条目
  void _cancelViewingItem() {
    setState(() {
      _isViewingItem = false;
      _selectedItemId = null;
    });
  }
  
  // 激活或取消激活设定组
  void _toggleGroupActive(String groupId, bool currentIsActive) {
    context.read<SettingBloc>().add(SetGroupActiveContext(
      novelId: widget.novelId,
      groupId: groupId,
      isActive: !currentIsActive,
    ));
  }
  
  // 搜索设定条目
  void _searchItems(String searchTerm) {
    if (searchTerm.isEmpty) {
      // 如果搜索词为空，加载所有条目
      context.read<SettingBloc>().add(LoadSettingItems(
        novelId: widget.novelId,
      ));
    } else {
      // 搜索条目
      context.read<SettingBloc>().add(LoadSettingItems(
        novelId: widget.novelId,
        name: searchTerm,
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 如果正在编辑设定条目，显示设定详情组件
    if (_isEditingItem) {
      return NovelSettingDetail(
        itemId: _selectedItemId,
        novelId: widget.novelId,
        groupId: _currentGroupId, // 传递当前组ID
        isEditing: true,
        onSave: _saveSettingItem,
        onCancel: _cancelEditingItem,
      );
    }
    
    // 如果正在查看设定条目详情，显示设定详情组件
    if (_isViewingItem && _selectedItemId != null) {
      return NovelSettingDetail(
        itemId: _selectedItemId,
        novelId: widget.novelId,
        groupId: null,
        isEditing: false,
        onSave: _saveSettingItem,
        onCancel: _cancelViewingItem,
      );
    }
    
    return Material(
      color: Colors.grey.shade50,
      child: Container(
        color: Colors.grey.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索和操作栏
            _buildSearchBar(theme),
            
            // 内容区域
            Expanded(
              child: BlocBuilder<SettingBloc, SettingState>(
                builder: (context, state) {
                  if (state.groupsStatus == SettingStatus.loading && state.groups.isEmpty) {
                    return _buildLoadingState();
                  }
                  
                  if (state.groupsStatus == SettingStatus.failure) {
                    return _buildErrorState(state.error);
                  }
                  
                  if (state.groups.isEmpty && state.items.isEmpty) {
                    return _buildEmptyState(theme);
                  }
                  
                  return _buildSettingList(theme, state);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建搜索和操作栏
  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                ),
                decoration: InputDecoration(
                  hintText: '搜索设定...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _searchItems('');
                    },
                    splashRadius: 16,
                    tooltip: '清除',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  isDense: true,
                ),
                onSubmitted: _searchItems,
                onChanged: (value) {
                  if (value.isEmpty) {
                    _searchItems('');
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 新建条目按钮
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: () => _createSettingItem(),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新建条目'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.0,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 0,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 新建组按钮
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: _createSettingGroup,
              icon: const Icon(Icons.create_new_folder_outlined, size: 14),
              label: const Text('新建组'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: theme.colorScheme.secondary,
                  width: 1.0,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 0,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // 设置按钮
          IconButton(
            onPressed: () {
              // TODO: 实现设定设置功能
            },
            icon: Icon(
              Icons.settings_outlined,
              size: 16,
              color: Colors.grey.shade700,
            ),
            tooltip: '设定设置',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建加载状态
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  
  // 构建错误状态
  Widget _buildErrorState(String? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            '加载设定数据失败',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                error,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<SettingBloc>().add(LoadSettingGroups(widget.novelId));
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
  
  // 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设定库为空',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设定库存储您小说世界的信息，包括角色、地点、物品及更多设定内容。',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _createSettingGroup,
            child: Text(
              '→ 点击创建第一个设定组',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _createSettingItem(),
            child: Text(
              '→ 点击创建第一个设定条目',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建设定列表（树状结构）
  Widget _buildSettingList(ThemeData theme, SettingState state) {
    final isSearching = _searchController.text.isNotEmpty;
    
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 搜索结果
        if (isSearching && state.items.isNotEmpty)
          ..._buildSearchResultItems(theme, state.items),
        
        // 如果正在搜索且没有结果
        if (isSearching && state.items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '没有找到匹配"${_searchController.text}"的设定条目',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          
        // 不在搜索时显示设定组及其包含的条目
        if (!isSearching)
          ...state.groups.map((group) => 
            _buildSettingGroupItem(theme, group, state.items)),
      ],
    );
  }
  
  // 构建搜索结果的设定条目列表
  List<Widget> _buildSearchResultItems(ThemeData theme, List<NovelSettingItem> items) {
    return [
      // 搜索结果标题
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          '搜索结果',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ),
      // 搜索结果列表
      ...items.map((item) => _buildSettingItemTile(theme, item, null)),
    ];
  }

  // 构建设定组项目
  Widget _buildSettingGroupItem(ThemeData theme, SettingGroup group, List<NovelSettingItem> allItems) {
    final isExpanded = _expandedGroupIds.contains(group.id);
    
    // 调试信息
    if (isExpanded && group.id != null) {
      AppLogger.i('NovelSettingSidebar', '展开组 ${group.name}(${group.id}) - 组内条目IDs: ${group.itemIds}, 所有条目数量: ${allItems.length}');
    }
    
    // 筛选属于该组的条目
    final List<NovelSettingItem> groupItems = [];
    if (group.itemIds != null && group.itemIds!.isNotEmpty) {
      for (final itemId in group.itemIds!) {
        final item = allItems.firstWhere(
          (item) => item.id == itemId,
          orElse: () => NovelSettingItem(
            id: itemId, 
            name: "加载中...", 
            content: ""
          ),
        );
        groupItems.add(item);
      }
      
      // 按名称排序
      groupItems.sort((a, b) => a.name.compareTo(b.name));
      
      // 调试信息
      if (isExpanded) {
        AppLogger.i('NovelSettingSidebar', '筛选后组内条目数量: ${groupItems.length}');
      }
    }
    
    return Column(
      children: [
        // 设定组标题行
        InkWell(
          onTap: () {
            if (group.id != null) {
              _toggleGroupExpansion(group.id!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                // 展开/折叠图标
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                // 设定组图标
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.folder,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                // 设定组名称
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (group.description != null && group.description!.isNotEmpty)
                        Text(
                          group.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // 活跃状态图标
                if (group.isActiveContext == true)
                  Icon(
                    Icons.star,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                // 添加条目按钮
                if (group.id != null)
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => _createSettingItem(groupId: group.id),
                    tooltip: '添加设定条目到此组',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                // 设定组操作按钮
                _buildGroupMenuButton(theme, group),
              ],
            ),
          ),
        ),
        
        // 如果展开，显示该组的设定条目
        if (isExpanded && group.id != null)
          ..._buildSettingItems(theme, groupItems, group.id!),
      ],
    );
  }

  // 构建设定组菜单按钮
  Widget _buildGroupMenuButton(ThemeData theme, SettingGroup group) {
    if (group.id == null) return const SizedBox.shrink();
    
    return CustomDropdown(
      width: 200,
      align: 'right',
      trigger: Icon(
        Icons.more_vert,
        size: 16,
        color: Colors.grey.shade600,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownItem(
            icon: Icons.edit,
            label: '编辑设定组',
            onTap: () async {
              _editSettingGroup(group.id!);
            },
          ),
          DropdownItem(
            icon: group.isActiveContext == true ? Icons.star : Icons.star_border,
            label: group.isActiveContext == true ? '取消活跃状态' : '设为活跃上下文',
            onTap: () async {
              _toggleGroupActive(group.id!, group.isActiveContext ?? false);
            },
          ),
          DropdownItem(
            icon: Icons.add_circle_outline,
            label: '添加设定条目到此组',
            onTap: () async {
              _createSettingItem(groupId: group.id);
            },
          ),
          const DropdownDivider(),
          DropdownItem(
            icon: Icons.delete_outline,
            label: '删除设定组',
            isDangerous: true,
            onTap: () async {
              _deleteSettingGroup(group.id!);
            },
          ),
        ],
      ),
    );
  }
  
  // 构建设定条目列表
  List<Widget> _buildSettingItems(ThemeData theme, List<NovelSettingItem> items, String groupId) {
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 4, 16, 8),  // 减少左侧缩进
          child: Text(
            '该设定组下暂无条目',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ];
    }
    
    return items.map((item) => _buildSettingItemTile(theme, item, groupId)).toList();
  }
  
  // 构建设定条目项
  Widget _buildSettingItemTile(ThemeData theme, NovelSettingItem item, String? groupId) {
    // 将类型值转换为枚举
    final typeEnum = SettingType.fromValue(item.type ?? 'OTHER');
    final typeDisplayName = typeEnum.displayName;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(groupId != null ? 16 : 8, 8, 8, 8),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            if (item.id != null) {
              _viewSettingItem(item.id!);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：图标、类型和标题
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 设定类型图标 - 缩小尺寸
                    _buildTypeIcon(item.type ?? 'OTHER'),
                    const SizedBox(width: 10),
                    
                    // 设定类型文字 - 缩小尺寸
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getTypeColor(typeEnum).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        typeDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getTypeColor(typeEnum),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 设定条目标题
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    // 操作菜单
                    _buildItemMenuButton(theme, item),
                  ],
                ),
                
                // 生成方式标识（如果有）
                if (item.generatedBy != null && item.generatedBy!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        '由 ${item.generatedBy} 生成',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ),
                
                // 第二行：描述内容
                if (item.description != null && item.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 40),
                    child: Text(
                      item.description!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                // 显示属性（如果有）
                if (item.attributes != null && item.attributes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 40),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: item.attributes!.entries.map((e) => Chip(
                        label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      )).toList(),
                    ),
                  ),
                
                // 显示标签（如果有）
                if (item.tags != null && item.tags!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 40),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: item.tags!.map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 10)),
                        backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.6),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建设定条目菜单按钮
  Widget _buildItemMenuButton(ThemeData theme, NovelSettingItem item) {
    if (item.id == null) return const SizedBox.shrink();
    
    return CustomDropdown(
      width: 200,
      align: 'right',
      trigger: Icon(
        Icons.more_vert,
        size: 16,
        color: Colors.grey.shade600,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownItem(
            icon: Icons.visibility,
            label: '查看设定条目',
            onTap: () async {
              _viewSettingItem(item.id!);
            },
          ),
          DropdownItem(
            icon: Icons.edit,
            label: '编辑设定条目',
            onTap: () async {
              _editSettingItem(item.id!);
            },
          ),
          const DropdownDivider(),
          DropdownItem(
            icon: Icons.delete_outline,
            label: '删除设定条目',
            isDangerous: true,
            onTap: () async {
              _deleteSettingItem(item.id!);
            },
          ),
        ],
      ),
    );
  }
  
  // 根据设定条目类型构建对应图标
  Widget _buildTypeIcon(String type) {
    // 将类型值转换为枚举
    final typeEnum = SettingType.fromValue(type);
    
    return CircleAvatar(
      radius: 18,  // 缩小图标尺寸
      backgroundColor: _getTypeColor(typeEnum).withOpacity(0.1),
      child: Icon(
        _getTypeIconData(typeEnum),
        size: 18,  // 缩小图标尺寸
        color: _getTypeColor(typeEnum),
      ),
    );
  }

  // 获取类型图标
  IconData _getTypeIconData(SettingType type) {
    switch (type) {
      case SettingType.character:
        return Icons.person;
      case SettingType.location:
        return Icons.place;
      case SettingType.item:
        return Icons.inventory_2;
      case SettingType.lore:
        return Icons.public;
      case SettingType.event:
        return Icons.event;
      case SettingType.concept:
        return Icons.auto_awesome;
      case SettingType.faction:
        return Icons.groups;
      case SettingType.creature:
        return Icons.pets;
      case SettingType.magicSystem:
        return Icons.auto_fix_high;
      case SettingType.technology:
        return Icons.science;
      default:
        return Icons.article;
    }
  }

  // 根据设定条目类型获取对应颜色
  Color _getTypeColor(SettingType type) {
    switch (type) {
      case SettingType.character:
        return Colors.blue;
      case SettingType.location:
        return Colors.green;
      case SettingType.item:
        return Colors.orange;
      case SettingType.lore:
        return Colors.purple;
      case SettingType.event:
        return Colors.red;
      case SettingType.concept:
        return Colors.teal;
      case SettingType.faction:
        return Colors.indigo;
      case SettingType.creature:
        return Colors.brown;
      case SettingType.magicSystem:
        return Colors.cyan;
      case SettingType.technology:
        return Colors.blueGrey;
      default:
        return Colors.grey.shade700;
    }
  }
} 