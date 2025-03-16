import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/screens/editor/components/act_section.dart';
import 'package:ainoval/screens/editor/components/chapter_section.dart';
import 'package:ainoval/screens/editor/components/scene_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class EditorMainArea extends StatelessWidget {
  const EditorMainArea({
    super.key,
    required this.novel,
    required this.editorBloc,
    required this.sceneControllers,
    required this.sceneSummaryControllers,
    this.activeActId,
    this.activeChapterId,
    required this.scrollController,
  });
  final novel_models.Novel novel;
  final EditorBloc editorBloc;
  final Map<String, QuillController> sceneControllers;
  final Map<String, TextEditingController> sceneSummaryControllers;
  final String? activeActId;
  final String? activeChapterId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50, // 更改背景色为浅灰色，增强对比度
      child: SingleChildScrollView(
        controller: scrollController,
        child: Center(
          child: Container(
            width: 1100, // 增加宽度以容纳内容和摘要
            padding: const EdgeInsets.symmetric(
                horizontal: 40, vertical: 20), // 添加垂直内边距
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 动态构建Acts
                ...novel.acts.map((act) => _buildActSection(act)),

                // 添加新Act按钮
                _AddActButton(editorBloc: editorBloc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActSection(novel_models.Act act) {
    return ActSection(
      title: act.title,
      chapters: act.chapters
          .map((chapter) => _buildChapterSection(act.id, chapter))
          .toList(),
      actId: act.id,
      editorBloc: editorBloc,
    );
  }

  Widget _buildChapterSection(String actId, novel_models.Chapter chapter) {
    // 构建该章节的所有场景
    final sceneWidgets = chapter.scenes.asMap().entries.map((entry) {
      final index = entry.key;
      final scene = entry.value;
      final isFirst = index == 0;

      // 为每个场景创建一个唯一的ID
      final sceneId = '${actId}_${chapter.id}_${scene.id}';

      // 检查控制器是否存在，如果不存在则跳过
      if (!sceneControllers.containsKey(sceneId)) {
        // 创建默认控制器
        sceneControllers[sceneId] = QuillController(
          document: Document.fromJson([
            {"insert": "\n"}
          ]),
          selection: const TextSelection.collapsed(offset: 0),
        );
        // 其他控制器初始化...
      }

      return SceneEditor(
        title: '${chapter.title} · Scene ${index + 1}',
        wordCount: '${scene.wordCount} Words',
        isActive: activeActId == actId && activeChapterId == chapter.id,
        actId: actId,
        chapterId: chapter.id,
        sceneId: scene.id,
        isFirst: isFirst,
        controller: sceneControllers[sceneId]!,
        summaryController: sceneSummaryControllers[sceneId]!,
        editorBloc: editorBloc,
      );
    }).toList();

    // 如果没有场景或者场景控制器不存在，则使用默认的场景编辑器
    if (sceneWidgets.isEmpty) {
      final defaultSceneId = '${actId}_${chapter.id}';
      if (sceneControllers.containsKey(defaultSceneId)) {
        // 尝试查找章节的第一个场景ID
        String? firstSceneId;
        if (chapter.scenes.isNotEmpty) {
          firstSceneId = chapter.scenes.first.id;
        }

        sceneWidgets.add(SceneEditor(
          title: '${chapter.title} · Scene 1',
          wordCount: '${chapter.wordCount} Words',
          isActive: activeActId == actId && activeChapterId == chapter.id,
          actId: actId,
          chapterId: chapter.id,
          sceneId: firstSceneId,
          controller: sceneControllers[defaultSceneId]!,
          summaryController: sceneSummaryControllers[defaultSceneId]!,
          editorBloc: editorBloc,
        ));
      }
    }

    return ChapterSection(
      title: chapter.title,
      scenes: sceneWidgets,
      actId: actId,
      chapterId: chapter.id,
      editorBloc: editorBloc,
    );
  }
}

class _AddActButton extends StatelessWidget {
  const _AddActButton({required this.editorBloc});
  final EditorBloc editorBloc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: TextButton.icon(
          onPressed: () {
            // 触发添加新Act事件
            editorBloc.add(const AddNewAct(title: '新Act'));
          },
          icon: const Icon(Icons.add),
          label: const Text('New Act'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
