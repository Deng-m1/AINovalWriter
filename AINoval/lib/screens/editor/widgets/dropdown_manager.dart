import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/screens/editor/widgets/custom_dropdown.dart';
import 'package:ainoval/screens/editor/widgets/menu_definitions.dart';
import 'package:flutter/material.dart';

/// 下拉菜单管理器
/// 
/// 用于统一构建和管理所有下拉菜单，包括Act、Chapter和Scene的菜单
class DropdownManager {
  /// 菜单构建上下文
  final BuildContext context;
  
  /// 编辑器状态管理
  final EditorBloc editorBloc;
  
  /// 菜单显示设置
  final DropdownDisplaySettings displaySettings;

  DropdownManager({
    required this.context,
    required this.editorBloc,
    this.displaySettings = const DropdownDisplaySettings(),
  });

  /// 构建Act菜单
  Widget buildActMenu({
    required String actId,
    Function()? onRenamePressed,
    IconData? icon,
    String? tooltip,
  }) {
    return _buildMenu(
      menuItems: ActMenuDefinitions.getMenuItems(),
      id: actId,
      secondaryId: null,
      tertiaryId: null,
      onRenamePressed: onRenamePressed,
      icon: icon ?? Icons.more_vert,
      tooltip: tooltip ?? 'Act操作',
      width: displaySettings.actMenuWidth,
      align: displaySettings.actMenuAlign,
    );
  }

  /// 构建Chapter菜单
  Widget buildChapterMenu({
    required String actId,
    required String chapterId,
    Function()? onRenamePressed,
    IconData? icon,
    String? tooltip,
  }) {
    return _buildMenu(
      menuItems: ChapterMenuDefinitions.getMenuItems(),
      id: actId,
      secondaryId: chapterId,
      tertiaryId: null,
      onRenamePressed: onRenamePressed,
      icon: icon ?? Icons.more_vert,
      tooltip: tooltip ?? '章节操作',
      width: displaySettings.chapterMenuWidth,
      align: displaySettings.chapterMenuAlign,
    );
  }

  /// 构建Scene菜单
  Widget buildSceneMenu({
    required String actId,
    required String chapterId,
    required String sceneId,
    IconData? icon,
    String? tooltip,
  }) {
    return _buildMenu(
      menuItems: SceneMenuDefinitions.getMenuItems(),
      id: actId,
      secondaryId: chapterId,
      tertiaryId: sceneId,
      icon: icon ?? Icons.more_horiz,
      tooltip: tooltip ?? '场景操作',
      width: displaySettings.sceneMenuWidth,
      align: displaySettings.sceneMenuAlign,
    );
  }

  /// 内部方法：构建通用菜单
  Widget _buildMenu({
    required List<dynamic> menuItems,
    required String id,
    String? secondaryId,
    String? tertiaryId,
    Function()? onRenamePressed,
    required IconData icon,
    required String tooltip,
    double width = 240,
    String align = 'left',
  }) {
    return CustomDropdown(
      width: width,
      align: align,
      trigger: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: null, // 由CustomDropdown处理点击
        tooltip: tooltip,
        color: Colors.grey.shade600,
        splashRadius: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildMenuItemWidgets(
          menuItems,
          id,
          secondaryId,
          tertiaryId,
          onRenamePressed,
        ),
      ),
    );
  }

  /// 构建菜单项列表
  List<Widget> _buildMenuItemWidgets(
    List<dynamic> menuItems,
    String id,
    String? secondaryId,
    String? tertiaryId,
    Function()? onRenamePressed,
  ) {
    final List<Widget> widgets = [];

    for (final item in menuItems) {
      if (item is String && item == "divider") {
        widgets.add(const DropdownDivider());
      } else if (item is MenuSectionData) {
        widgets.add(
          DropdownSection(
            title: item.title,
            children: item.items.map((menuItem) {
              return _buildSingleMenuItem(
                menuItem,
                id,
                secondaryId,
                tertiaryId,
                onRenamePressed,
              );
            }).toList(),
          ),
        );
      } else if (item is MenuItemData) {
        widgets.add(
          _buildSingleMenuItem(
            item,
            id,
            secondaryId,
            tertiaryId,
            onRenamePressed,
          ),
        );
      }
    }

    return widgets;
  }

  /// 构建单个菜单项
  Widget _buildSingleMenuItem(
    MenuItemData item,
    String id,
    String? secondaryId,
    String? tertiaryId,
    Function()? onRenamePressed,
  ) {
    // 特殊处理重命名操作，因为需要直接访问State
    Future<void> Function()? onTapHandler;
    if (item.label == '重命名Act' || item.label == '重命名章节') {
      onTapHandler = null;
    } else if (item.onTap != null) {
      onTapHandler = () async {
        await item.onTap!(context, editorBloc, id, secondaryId, tertiaryId);
      };
    }

    return DropdownItem(
      icon: item.icon,
      label: item.label,
      hasSubmenu: item.hasSubmenu,
      disabled: item.disabled,
      isDangerous: item.isDangerous,
      onTap: onTapHandler,
    );
  }
}

/// 下拉菜单显示设置
class DropdownDisplaySettings {
  final double actMenuWidth;
  final double chapterMenuWidth;
  final double sceneMenuWidth;
  final String actMenuAlign;
  final String chapterMenuAlign;
  final String sceneMenuAlign;

  const DropdownDisplaySettings({
    this.actMenuWidth = 240,
    this.chapterMenuWidth = 240,
    this.sceneMenuWidth = 240,
    this.actMenuAlign = 'left',
    this.chapterMenuAlign = 'right',
    this.sceneMenuAlign = 'right',
  });
} 