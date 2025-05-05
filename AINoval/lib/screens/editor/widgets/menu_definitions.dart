import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/screens/editor/widgets/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';

/// 通用菜单项数据模型
class MenuItemData {
  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext, EditorBloc, String, String?, String?)? onTap;
  final bool hasSubmenu;
  final bool disabled;
  final bool isDangerous;

  const MenuItemData({
    required this.icon,
    required this.label,
    this.onTap,
    this.hasSubmenu = false,
    this.disabled = false,
    this.isDangerous = false,
  });
}

/// 菜单分区数据模型
class MenuSectionData {
  final String title;
  final List<MenuItemData> items;

  const MenuSectionData({
    required this.title,
    required this.items,
  });
}

/// Act菜单定义
class ActMenuDefinitions {
  static List<dynamic> getMenuItems() {
    return [
      // 基本操作
      MenuItemData(
        icon: Icons.add,
        label: '添加新章节',
        onTap: (context, editorBloc, actId, _, __) async {
          editorBloc.add(AddNewChapter(
            novelId: editorBloc.novelId,
            actId: actId,
            title: '新章节 ${DateTime.now().millisecondsSinceEpoch % 100}',
          ));
        },
      ),
      MenuItemData(
        icon: Icons.refresh,
        label: '加载所有章节场景',
        onTap: (context, editorBloc, actId, _, __) async {
          _loadAllScenesForAct(context, editorBloc, actId);
        },
      ),
      MenuItemData(
        icon: Icons.edit,
        label: '重命名Act',
        onTap: null,
      ),
      
      // 导出选项
      MenuSectionData(
        title: '导出选项',
        items: [
          MenuItemData(
            icon: Icons.file_download,
            label: '导出为PDF',
            onTap: (context, editorBloc, actId, _, __) async {
              // 实现导出为PDF功能
            },
          ),
          MenuItemData(
            icon: Icons.file_download,
            label: '导出为Word',
            onTap: (context, editorBloc, actId, _, __) async {
              // 实现导出为Word功能
            },
          ),
        ],
      ),
      
      // 危险操作
      MenuItemData(
        icon: Icons.delete_outline,
        label: '删除Act',
        isDangerous: true,
        onTap: (context, editorBloc, actId, _, __) async {
          final confirmed = await _confirmAndDelete(
            context, 
            '删除Act', 
            '确定要删除这个Act吗？此操作不可撤销。',
          );
          if (confirmed) {
            // 实现删除Act功能
            // editorBloc.add(DeleteAct(
            //   novelId: editorBloc.novelId,
            //   actId: actId,
            // ));
          }
        },
      ),
    ];
  }

  /// 加载Act下所有章节的场景
  static void _loadAllScenesForAct(BuildContext context, EditorBloc editorBloc, String actId) {
    if (editorBloc.state is EditorLoaded) {
      final state = editorBloc.state as EditorLoaded;
      final novel = state.novel;
      
      // 查找当前Act的所有章节
      for (final act in novel.acts) {
        if (act.id == actId) {
          // 找到每个未加载场景的章节，触发加载
          for (final chapter in act.chapters) {
            if (chapter.scenes.isEmpty) {
              // 加载这个章节的场景
              editorBloc.add(LoadMoreScenes(
                fromChapterId: chapter.id,
                direction: 'center',
                chaptersLimit: 1,
              ));
            }
          }
          break;
        }
      }
    }
  }
}

/// Chapter菜单定义
class ChapterMenuDefinitions {
  static List<dynamic> getMenuItems() {
    return [
      // 基本操作
      MenuItemData(
        icon: Icons.add,
        label: '添加新场景',
        onTap: (context, editorBloc, actId, chapterId, _) async {
          _addNewScene(context, editorBloc, actId, chapterId!);
        },
      ),
      MenuItemData(
        icon: Icons.download,
        label: '加载场景内容',
        onTap: (context, editorBloc, actId, chapterId, _) async {
          _loadScenes(context, editorBloc, chapterId!);
        },
      ),
      MenuItemData(
        icon: Icons.edit,
        label: '重命名章节',
        onTap: null,
      ),
      
      // 分隔线
      "divider",
      
      // 额外功能
      MenuItemData(
        icon: Icons.tag,
        label: '禁用编号',
        onTap: (context, editorBloc, actId, chapterId, _) async {
          // 实现禁用编号功能
        },
      ),
      MenuItemData(
        icon: Icons.content_copy,
        label: '复制所有场景内容',
        onTap: (context, editorBloc, actId, chapterId, _) async {
          // 实现复制场景内容功能
        },
      ),
      
      // 分隔线
      "divider",
      
      // 危险操作
      MenuItemData(
        icon: Icons.delete_outline,
        label: '删除章节',
        isDangerous: true,
        onTap: (context, editorBloc, actId, chapterId, _) async {
          final confirmed = await _confirmAndDelete(
            context, 
            '删除章节', 
            '确定要删除这个章节吗？此操作不可撤销，章节内的所有场景都将被删除。',
          );
          if (confirmed) {
            // 实现删除章节功能
            editorBloc.add(DeleteChapter(
              novelId: editorBloc.novelId,
              actId: actId,
              chapterId: chapterId!,
            ));

            // 显示操作反馈
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('正在删除章节...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    ];
  }

  /// 添加新场景
  static void _addNewScene(BuildContext context, EditorBloc editorBloc, String actId, String chapterId) {
    final newSceneId = DateTime.now().millisecondsSinceEpoch.toString();
    AppLogger.i('Chapter', '添加新场景：actId=$actId, chapterId=$chapterId, sceneId=$newSceneId');
    
    editorBloc.add(AddNewScene(
      novelId: editorBloc.novelId,
      actId: actId,
      chapterId: chapterId,
      sceneId: newSceneId,
    ));
  }

  /// 加载场景内容
  static void _loadScenes(BuildContext context, EditorBloc editorBloc, String chapterId) {
    AppLogger.i('ChapterSection', '手动触发加载章节场景: $chapterId');
    
    try {
      // 尝试使用控制器加载场景
      final controller = Provider.of<EditorScreenController>(context, listen: false);
      controller.loadScenesForChapter(chapterId);
    } catch (e) {
      // 如果无法获取控制器，直接使用EditorBloc
      editorBloc.add(LoadMoreScenes(
        fromChapterId: chapterId,
        direction: 'center',
        chaptersLimit: 2,
        preventFocusChange: true,
      ));
    }
  }
}

/// Scene菜单定义
class SceneMenuDefinitions {
  static List<dynamic> getMenuItems() {
    return [
      MenuItemData(
        icon: Icons.copy_outlined,
        label: '复制场景',
        onTap: (context, editorBloc, actId, chapterId, sceneId) async {
          // 实现复制场景功能
          // editorBloc.add(DuplicateScene(
          //   novelId: editorBloc.novelId,
          //   actId: actId,
          //   chapterId: chapterId!,
          //   sceneId: sceneId!,
          // ));
        },
      ),
      MenuItemData(
        icon: Icons.splitscreen_outlined,
        label: '拆分场景',
        onTap: (context, editorBloc, actId, chapterId, sceneId) async {
          // 实现拆分场景功能
        },
      ),
      
      MenuSectionData(
        title: 'AI功能',
        items: [
          MenuItemData(
            icon: Icons.auto_awesome,
            label: '生成摘要',
            onTap: (context, editorBloc, actId, chapterId, sceneId) async {
              editorBloc.add(GenerateSceneSummaryRequested(
                sceneId: sceneId!,
              ));
            },
          ),
          MenuItemData(
            icon: Icons.psychology,
            label: '改进内容',
            onTap: (context, editorBloc, actId, chapterId, sceneId) async {
              // 实现AI改进内容功能
            },
          ),
        ],
      ),
      
      // 分隔线
      "divider",
      
      // 危险操作
      MenuItemData(
        icon: Icons.delete_outline,
        label: '删除场景',
        isDangerous: true,
        onTap: (context, editorBloc, actId, chapterId, sceneId) async {
          final confirmed = await _confirmAndDelete(
            context, 
            '删除场景', 
            '确定要删除这个场景吗？此操作不可撤销。',
          );
          if (confirmed) {
            editorBloc.add(DeleteScene(
              novelId: editorBloc.novelId,
              actId: actId,
              chapterId: chapterId!,
              sceneId: sceneId!,
            ));
          }
        },
      ),
    ];
  }
}

/// 通用确认删除对话框
Future<bool> _confirmAndDelete(BuildContext context, String title, String message) async {
  final confirmed = await DialogUtils.showDangerousConfirmDialog(
    context: context,
    title: title,
    message: message,
  );
  return confirmed;
} 