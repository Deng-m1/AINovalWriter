# 自定义下拉菜单组件使用指南

本文档介绍如何使用新的自定义下拉菜单组件替换现有的三点水下拉菜单。

## 组件概述

自定义下拉菜单由以下几个组件组成：

1. `CustomDropdown`：主容器组件，负责显示下拉菜单
2. `DropdownItem`：菜单项组件，表示单个菜单选项
3. `DropdownSection`：菜单分区组件，用于对相关菜单项进行分组
4. `DropdownDivider`：分隔线组件，用于分隔不同菜单部分

## 使用方法

### 1. 导入组件

```dart
import 'package:ainoval/screens/editor/widgets/custom_dropdown.dart';
```

### 2. 基础用法

```dart
CustomDropdown(
  trigger: IconButton(
    icon: const Icon(Icons.more_vert, size: 20),
    onPressed: null, // 由CustomDropdown处理点击
    color: Colors.grey.shade600,
  ),
  width: 240, // 下拉菜单宽度
  align: 'left', // 对齐方式，可选 'left' 或 'right'
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownItem(
        icon: Icons.edit,
        label: '编辑',
        onTap: () {
          // 处理点击事件
        },
      ),
      DropdownItem(
        icon: Icons.delete,
        label: '删除',
        onTap: () {
          // 处理点击事件
        },
      ),
    ],
  ),
)
```

### 3. 使用分区

```dart
CustomDropdown(
  trigger: IconButton(
    icon: const Icon(Icons.more_vert),
    onPressed: null,
  ),
  width: 280,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownItem(
        icon: Icons.visibility,
        label: '查看详情',
        onTap: () {},
      ),
      const DropdownDivider(), // 添加分隔线
      DropdownSection(
        title: '编辑选项', // 分区标题
        children: [
          DropdownItem(
            icon: Icons.edit,
            label: '编辑信息',
            onTap: () {},
          ),
          DropdownItem(
            icon: Icons.delete_outline,
            label: '删除',
            onTap: () {},
          ),
        ],
      ),
    ],
  ),
)
```

### 4. 暗色主题

对于暗色主题，需要设置 `isDarkTheme` 属性：

```dart
CustomDropdown(
  isDarkTheme: true, // 启用暗色主题
  trigger: IconButton(
    icon: const Icon(Icons.more_vert, color: Colors.white70),
    onPressed: null,
  ),
  width: 240,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownItem(
        icon: Icons.edit,
        label: '编辑',
        isDarkTheme: true, // 同样需要设置菜单项的暗色主题
        onTap: () {},
      ),
      DropdownSection(
        title: '高级选项',
        isDarkTheme: true, // 分区也需要设置暗色主题
        children: [
          DropdownItem(
            icon: Icons.settings,
            label: '设置',
            isDarkTheme: true,
            onTap: () {},
          ),
        ],
      ),
    ],
  ),
)
```

### 5. 子菜单选项

对于需要显示子菜单的选项，可以设置 `hasSubmenu` 属性：

```dart
DropdownItem(
  icon: Icons.share,
  label: '分享',
  hasSubmenu: true, // 显示右侧箭头图标
  onTap: () {
    // 处理子菜单逻辑
  },
)
```

### 6. 禁用菜单项

对于不可用的菜单项，可以设置 `disabled` 属性：

```dart
DropdownItem(
  icon: Icons.delete,
  label: '删除',
  disabled: true, // 禁用此菜单项
  onTap: null,
)
```

## 替换现有下拉菜单

替换现有的 `PopupMenuButton` 为新的自定义下拉菜单，遵循以下步骤：

### 例如，将 Act 菜单从这样：

```dart
IconButton(
  icon: const Icon(Icons.more_vert, size: 20),
  onPressed: () {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.add),
            title: const Text('添加新章节'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () {
              Navigator.pop(context);
              // 触发添加新章节事件
            },
          ),
        ),
        // 更多菜单项...
      ],
    );
  },
)
```

### 替换为这样：

```dart
CustomDropdown(
  width: 240,
  trigger: IconButton(
    icon: const Icon(Icons.more_vert, size: 20),
    onPressed: null, // 由CustomDropdown处理点击
    tooltip: 'Act操作',
    color: Colors.grey.shade600,
    splashRadius: 20,
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownItem(
        icon: Icons.add,
        label: '添加新章节',
        onTap: () {
          // 触发添加新章节事件
        },
      ),
      // 更多菜单项...
    ],
  ),
)
```

## 注意事项

1. 相比于原生的 `PopupMenuButton`，自定义下拉菜单组件可以提供更丰富的视觉效果和更灵活的布局
2. 菜单项的 `onTap` 回调中已经包含了关闭菜单的逻辑，不需要手动调用 `Navigator.pop(context)`
3. 菜单宽度可以通过 `width` 属性灵活调整
4. 菜单对齐方式可以通过 `align` 属性设置为 'left' 或 'right'

## 示例代码

完整的示例代码可以在以下文件中查看：

- `AINoval/lib/screens/editor/widgets/custom_dropdown.dart`：组件定义
- `AINoval/lib/screens/editor/components/dropdown_demo.dart`：使用示例
- `AINoval/lib/screens/editor/widgets/dropdown_demo_screen.dart`：演示页面

## 实施建议

1. 首先替换最简单的菜单（如单层菜单项）
2. 然后替换带分区的复杂菜单
3. 最后替换带有特殊交互的菜单（如带子菜单的项）
4. 保持菜单功能和布局与原有菜单一致，但利用新组件提供的增强功能

## FAQ

**Q: 自定义下拉菜单的层叠顺序 (z-index) 问题如何处理？**

A: 组件内部使用 `Overlay` 来显示下拉菜单，确保菜单总是显示在其他元素之上。

**Q: 如何处理菜单项的错误状态？**

A: 可以使用 `DropdownItem` 的 `disabled` 属性来显示禁用状态，或者通过自定义 `onTap` 回调函数中的逻辑来处理特殊情况。

**Q: 菜单如何响应屏幕大小变化？**

A: 自定义下拉菜单会根据触发器的位置自动调整显示位置，确保菜单不会超出屏幕边界。