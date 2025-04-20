import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/screens/editor/widgets/dropdown_manager.dart';
import 'package:flutter/material.dart';

/// 通用菜单构建器
/// 用于构建Act、Chapter和Scene的下拉菜单
class MenuBuilder {
  /// 构建Act菜单
  static Widget buildActMenu({
    required BuildContext context,
    required EditorBloc editorBloc,
    required String actId,
    required Function()? onRenamePressed,
    double width = 240,
    String align = 'left',
  }) {
    final dropdownManager = DropdownManager(
      context: context,
      editorBloc: editorBloc,
      displaySettings: DropdownDisplaySettings(
        actMenuWidth: width,
        actMenuAlign: align,
      ),
    );
    
    return dropdownManager.buildActMenu(
      actId: actId,
      onRenamePressed: onRenamePressed,
    );
  }

  /// 构建Chapter菜单
  static Widget buildChapterMenu({
    required BuildContext context,
    required EditorBloc editorBloc,
    required String actId,
    required String chapterId,
    required Function()? onRenamePressed,
    double width = 240,
    String align = 'right',
  }) {
    final dropdownManager = DropdownManager(
      context: context,
      editorBloc: editorBloc,
      displaySettings: DropdownDisplaySettings(
        chapterMenuWidth: width,
        chapterMenuAlign: align,
      ),
    );
    
    return dropdownManager.buildChapterMenu(
      actId: actId,
      chapterId: chapterId,
      onRenamePressed: onRenamePressed,
    );
  }

  /// 构建Scene菜单
  static Widget buildSceneMenu({
    required BuildContext context,
    required EditorBloc editorBloc,
    required String actId,
    required String chapterId,
    required String sceneId,
    double width = 240,
    String align = 'right',
  }) {
    final dropdownManager = DropdownManager(
      context: context,
      editorBloc: editorBloc,
      displaySettings: DropdownDisplaySettings(
        sceneMenuWidth: width,
        sceneMenuAlign: align,
      ),
    );
    
    return dropdownManager.buildSceneMenu(
      actId: actId,
      chapterId: chapterId,
      sceneId: sceneId,
    );
  }
} 