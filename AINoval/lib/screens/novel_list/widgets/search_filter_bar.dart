import 'package:flutter/material.dart';

/// 搜索和过滤工具栏组件
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.searchController,
    required this.isGridView,
    required this.onSearchChanged,
    required this.onViewTypeChanged,
    required this.onFilterPressed,
    required this.onSortPressed,
    required this.onGroupPressed,
  });

  final TextEditingController searchController;
  final bool isGridView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onViewTypeChanged;
  final VoidCallback onFilterPressed;
  final VoidCallback onSortPressed;
  final VoidCallback onGroupPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: SearchBox(
              controller: searchController,
              onChanged: onSearchChanged,
            ),
          ),

          const SizedBox(width: 12),

          // 过滤器按钮组
          Row(
            children: [
              FilterButton(
                label: '过滤',
                icon: Icons.filter_list,
                onPressed: onFilterPressed,
              ),
              const SizedBox(width: 8),
              FilterButton(
                label: '排序',
                icon: Icons.sort,
                onPressed: onSortPressed,
              ),
              const SizedBox(width: 8),
              FilterButton(
                label: '分组',
                icon: Icons.group_work,
                onPressed: onGroupPressed,
              ),
              const SizedBox(width: 8),

              // 视图切换按钮
              ViewToggleButtons(
                isGridView: isGridView,
                onViewTypeChanged: onViewTypeChanged,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 搜索框组件
class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: '搜索名称/系列...',
          prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// 过滤器按钮组件
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 视图切换按钮组
class ViewToggleButtons extends StatelessWidget {
  const ViewToggleButtons({
    super.key,
    required this.isGridView,
    required this.onViewTypeChanged,
    required this.theme,
  });

  final bool isGridView;
  final ValueChanged<bool> onViewTypeChanged;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => onViewTypeChanged(true),
            child: Container(
              padding: const EdgeInsets.all(6),
              color: isGridView ? Colors.grey.shade200 : Colors.transparent,
              child: Icon(
                Icons.grid_view,
                size: 18,
                color: isGridView ? theme.colorScheme.primary : Colors.grey,
              ),
            ),
          ),
          InkWell(
            onTap: () => onViewTypeChanged(false),
            child: Container(
              padding: const EdgeInsets.all(6),
              color: !isGridView ? Colors.grey.shade200 : Colors.transparent,
              child: Icon(
                Icons.view_list,
                size: 18,
                color: !isGridView ? theme.colorScheme.primary : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
