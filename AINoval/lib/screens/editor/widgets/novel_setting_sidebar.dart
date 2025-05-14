import 'package:flutter/material.dart';
import 'package:ainoval/models/novel_setting_item.dart';
import 'package:ainoval/models/setting_group.dart';
import 'package:ainoval/utils/logger.dart';

/// 小说设定侧边栏组件
/// 
/// 用于管理小说设定条目和设定组
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
  
  // 设定组列表
  List<SettingGroup> _settingGroups = [];
  
  // 当前选中的设定组ID
  String? _selectedGroupId;
  
  // 当前显示的设定条目列表
  List<NovelSettingItem> _settingItems = [];
  
  // 是否正在加载数据
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettingGroups();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // 加载设定组列表
  Future<void> _loadSettingGroups() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // TODO: 调用仓储层方法加载设定组列表
      // _settingGroups = await settingRepository.getNovelSettingGroups(novelId: widget.novelId);
      
      setState(() {
        _isLoading = false;
        
        // MOCK DATA FOR UI DEVELOPMENT
        _settingGroups = [
          SettingGroup(id: "1", name: "角色设定", description: "主要角色和配角的设定"),
          SettingGroup(id: "2", name: "世界观", description: "小说世界的基本设定和规则"),
          SettingGroup(id: "3", name: "物品道具", description: "重要物品和道具的设定"),
        ];
      });
      
      // 如果有设定组，默认选中第一个
      if (_settingGroups.isNotEmpty) {
        _selectGroup(_settingGroups[0].id!);
      }
    } catch (e) {
      AppLogger.e('NovelSettingSidebar', '加载设定组失败', e);
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 选择设定组并加载其包含的设定条目
  Future<void> _selectGroup(String groupId) async {
    if (_selectedGroupId == groupId) return;
    
    setState(() {
      _selectedGroupId = groupId;
      _isLoading = true;
    });
    
    try {
      // TODO: 调用仓储层方法加载设定条目列表
      // _settingItems = await settingRepository.getNovelSettingItems(
      //   novelId: widget.novelId,
      //   groupId: groupId,
      // );
      
      setState(() {
        _isLoading = false;
        
        // MOCK DATA FOR UI DEVELOPMENT
        _settingItems = [
          NovelSettingItem(
            id: "1", 
            name: "主角", 
            type: "角色", 
            content: "主角是一个19岁的大学生，性格开朗...",
            description: "小说的主要角色",
          ),
          NovelSettingItem(
            id: "2", 
            name: "魔法系统", 
            type: "世界观", 
            content: "这个世界的魔法基于元素操控，共有五大元素...",
            description: "魔法系统的基本规则",
          ),
        ];
      });
    } catch (e) {
      AppLogger.e('NovelSettingSidebar', '加载设定条目失败', e);
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material( // 添加Material组件作为整个侧边栏的父组件
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
              child: _isLoading 
                  ? _buildLoadingState() 
                  : _settingGroups.isEmpty 
                      ? _buildEmptyState(theme) 
                      : _buildSettingContent(theme),
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
                      Icons.filter_list,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      // TODO: 实现筛选功能
                    },
                    splashRadius: 16,
                    tooltip: '筛选',
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
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 新建条目按钮
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: 实现创建新设定条目功能
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新建'),
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
            onTap: () {
              // TODO: 创建第一个设定组或条目
            },
            child: Text(
              '→ 点击上方的"新建"按钮创建第一个设定条目',
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
  
  // 构建设定内容
  Widget _buildSettingContent(ThemeData theme) {
    return Row(
      children: [
        // 左侧：设定组列表
        Container(
          width: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(
                color: Colors.grey.shade200,
                width: 1.0,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 设定组标题
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '设定组',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      tooltip: '创建设定组',
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      onPressed: () {
                        // TODO: 实现创建设定组功能
                      },
                    ),
                  ],
                ),
              ),
              // 设定组列表
              Expanded(
                child: ListView.builder(
                  itemCount: _settingGroups.length,
                  itemBuilder: (context, index) {
                    final group = _settingGroups[index];
                    final isSelected = _selectedGroupId == group.id;
                    
                    return InkWell(
                      onTap: () {
                        if (group.id != null) {
                          _selectGroup(group.id!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.colorScheme.primary.withOpacity(0.1) 
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected 
                                  ? theme.colorScheme.primary 
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected 
                                          ? FontWeight.bold 
                                          : FontWeight.normal,
                                      color: isSelected 
                                          ? theme.colorScheme.primary 
                                          : Colors.grey.shade800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (group.description != null && group.description!.isNotEmpty)
                                    Text(
                                      group.description!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                ],
                              ),
                            ),
                            // 激活状态图标
                            if (group.isActiveContext == true)
                              Icon(
                                Icons.star,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        // 右侧：设定条目列表
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前组标题
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Text(
                  _selectedGroupId != null
                      ? _settingGroups
                          .firstWhere((g) => g.id == _selectedGroupId)
                          .name
                      : '所有设定',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              
              // 设定条目列表
              Expanded(
                child: _settingItems.isEmpty
                    ? Center(
                        child: Text(
                          '该设定组下暂无条目',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _settingItems.length,
                        itemBuilder: (context, index) {
                          final item = _settingItems[index];
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: item.description != null
                                  ? Text(
                                      item.description!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Text(
                                      item.content,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              leading: item.type != null
                                  ? _buildTypeIcon(item.type!)
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              dense: true,
                              onTap: () {
                                // TODO: 显示设定条目详情
                              },
                              trailing: PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('编辑'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除'),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    // TODO: 实现编辑功能
                                  } else if (value == 'delete') {
                                    // TODO: 实现删除功能
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 根据设定条目类型构建对应图标
  Widget _buildTypeIcon(String type) {
    IconData iconData;
    Color iconColor;
    
    switch (type.toLowerCase()) {
      case '角色':
        iconData = Icons.person;
        iconColor = Colors.blue;
        break;
      case '地点':
        iconData = Icons.place;
        iconColor = Colors.green;
        break;
      case '物品':
        iconData = Icons.inventory_2;
        iconColor = Colors.orange;
        break;
      case '世界观':
        iconData = Icons.public;
        iconColor = Colors.purple;
        break;
      case '事件':
        iconData = Icons.event;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.article;
        iconColor = Colors.grey;
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(
        iconData,
        size: 16,
        color: iconColor,
      ),
    );
  }
} 