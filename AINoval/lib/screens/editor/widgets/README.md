# 文本选中上下文工具栏

## 功能概述

为 AINoval 编辑器添加的文本选中上下文工具栏功能，当用户在编辑器内选中文本时，自动显示一个浮动工具栏，提供常用的文本格式化选项和应用特有的快捷操作。

## 主要特性

- 自动检测文本选择，根据选择状态显示/隐藏工具栏
- 在选区附近显示浮动工具栏（通常位于选区上方）
- 显示选中文本的字数统计
- 提供常用格式化选项：
  - 基本格式：加粗、斜体、下划线、删除线
  - 块级格式：引用、标题级别、列表
- 集成应用特有功能：
  - 片段（Snippet）
  - 知识库条目（Codex Entry）
  - 章节（Section）
- 支持撤销/重做操作
- 工具栏在失去选区或点击外部时自动消失

## 实现文件

- `lib/screens/editor/widgets/selection_toolbar.dart` - 工具栏 UI 组件
- `lib/screens/editor/components/scene_editor.dart` - 集成工具栏的场景编辑器

## 使用方法

工具栏会在用户选中文本时自动出现，无需额外操作。用户可以：

1. 选中文本 → 工具栏自动出现
2. 点击格式化按钮 → 应用相应格式到选中文本
3. 点击自定义操作按钮 → 触发相应功能
4. 取消选中或点击外部区域 → 工具栏自动隐藏

## 技术实现

- 使用 Flutter 的 `LayerLink` 和 `CompositedTransformFollower` 实现工具栏与选区的位置关联
- 监听 `QuillController` 的选择变化事件来控制工具栏的显示/隐藏
- 使用防抖动（Debouncing）机制减少不必要的状态更新
- 使用 `PopupMenuButton` 实现子菜单（如标题级别、列表类型） 