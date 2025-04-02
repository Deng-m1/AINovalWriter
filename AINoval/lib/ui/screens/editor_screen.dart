import 'package:ainoval/blocs/editor_version_bloc.dart';
import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/ui/dialogs/scene_history_dialog.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


/// 编辑器工具栏中添加版本历史按钮
Widget buildToolbarVersionHistoryButton(BuildContext context) {
  // 获取当前编辑器的场景信息
  final novelId = getCurrentNovelId(context);
  final chapterId = getCurrentChapterId(context);
  final sceneId = getCurrentSceneId(context);
  
  // 如果没有有效的场景ID，则禁用按钮
  final bool isEnabled = novelId.isNotEmpty && 
                        chapterId.isNotEmpty && 
                        sceneId.isNotEmpty;
  
  return IconButton(
    icon: const Icon(Icons.history),
    tooltip: '版本历史',
    onPressed: isEnabled ? () => _showHistoryDialog(
      context, 
      novelId, 
      chapterId, 
      sceneId
    ) : null,
  );
}

/// 添加版本保存功能
Future<void> saveVersionWithHistory(
  BuildContext context, 
  String content,
  {String reason = '手动保存'}
) async {
  // 获取当前编辑器的场景信息
  final novelId = getCurrentNovelId(context);
  final chapterId = getCurrentChapterId(context);
  final sceneId = getCurrentSceneId(context);
  
  if (novelId.isEmpty || chapterId.isEmpty || sceneId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法识别当前编辑的场景'))
    );
    return;
  }
  
  // 使用版本控制Bloc保存版本
  context.read<EditorVersionBloc>().add(EditorVersionSave(
    novelId: novelId,
    chapterId: chapterId,
    sceneId: sceneId,
    content: content,
    userId: AppConfig.userId ?? 'system',
    reason: reason,
  ));
  
  // 显示保存提示
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已保存当前版本'))
  );
}

/// 显示历史版本对话框
void _showHistoryDialog(
  BuildContext context, 
  String novelId, 
  String chapterId, 
  String sceneId
) {
  showDialog(
    context: context,
    builder: (context) => SceneHistoryDialog(
      novelId: novelId,
      chapterId: chapterId,
      sceneId: sceneId,
    ),
  ).then((restoredScene) {
    // 如果恢复了历史版本，更新编辑器内容
    if (restoredScene != null) {
      updateEditorContent(context, restoredScene.content);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复到历史版本'))
      );
    }
  });
}

/// 获取当前编辑的小说ID
String getCurrentNovelId(BuildContext context) {
  // 从编辑器状态中获取当前小说ID
  // 实际应用中需要替换为真实实现
  return '1'; // 使用样例ID，方便测试
}

/// 获取当前编辑的章节ID
String getCurrentChapterId(BuildContext context) {
  // 从编辑器状态中获取当前章节ID
  // 实际应用中需要替换为真实实现
  return 'chapter_1'; // 使用样例ID，方便测试
}

/// 获取当前编辑的场景ID
String getCurrentSceneId(BuildContext context) {
  // 从编辑器状态中获取当前场景ID
  // 实际应用中需要替换为真实实现
  return '1234567890'; // 使用样例ID，方便测试
}

/// 更新编辑器内容
void updateEditorContent(BuildContext context, String content) {
  // 更新编辑器内容的实现
  AppLogger.i('Ui/screens/editor_screen', '更新编辑器内容: $content');
  // 实际应用中需要调用编辑器的更新方法
  // TODO: 实现真实的编辑器内容更新逻辑
} 