import 'dart:async';
import 'dart:convert';

import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/screens/editor/components/act_section.dart';
import 'package:ainoval/screens/editor/components/chapter_section.dart';
import 'package:ainoval/screens/editor/components/scene_editor.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';


class EditorMainArea extends StatefulWidget {
  const EditorMainArea({
    super.key,
    required this.novel,
    required this.editorBloc,
    required this.sceneControllers,
    required this.sceneSummaryControllers,
    this.activeActId,
    this.activeChapterId,
    this.activeSceneId,
    required this.scrollController,
  });
  final novel_models.Novel novel;
  final EditorBloc editorBloc;
  final Map<String, QuillController> sceneControllers;
  final Map<String, TextEditingController> sceneSummaryControllers;
  final String? activeActId;
  final String? activeChapterId;
  final String? activeSceneId;
  final ScrollController scrollController;

  @override
  State<EditorMainArea> createState() => _EditorMainAreaState();
}

class _EditorMainAreaState extends State<EditorMainArea> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50, // 更改背景色为浅灰色，增强对比度
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Center(
          child: Container(
            width: 1100, // 增加宽度以容纳内容和摘要
            padding: const EdgeInsets.symmetric(
                horizontal: 40, vertical: 20), // 添加垂直内边距
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 动态构建Acts
                ...widget.novel.acts.map((act) => _buildActSection(act)),

                // 添加新Act按钮
                _AddActButton(editorBloc: widget.editorBloc),
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
      editorBloc: widget.editorBloc,
    );
  }

  Widget _buildChapterSection(String actId, novel_models.Chapter chapter) {
    if (chapter.scenes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Center(
          child: Column(
            children: [
              Text('章节 "${chapter.title}" 还没有场景。'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // 生成一个新的唯一 ID
                  final newSceneId = const Uuid().v4(); 
                  widget.editorBloc.add(AddNewScene(
                    novelId: widget.editorBloc.novelId,
                    actId: actId,
                    chapterId: chapter.id,
                    sceneId: newSceneId, // 传递新生成的 ID
                  ));
                },
                icon: const Icon(Icons.add),
                label: const Text('添加第一个场景'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sceneWidgets = chapter.scenes.asMap().entries.map((entry) {
      final index = entry.key;
      final scene = entry.value;
      final isFirst = index == 0;

      final sceneId = '${actId}_${chapter.id}_${scene.id}';

      if (!widget.sceneControllers.containsKey(sceneId)) {
        try {
          widget.sceneControllers[sceneId] = QuillController(
            document: _parseDocumentSafely(scene.content),
            selection: const TextSelection.collapsed(offset: 0),
          );

          widget.sceneSummaryControllers[sceneId] = TextEditingController(
            text: scene.summary.content,
          );
        } catch (e) {
          AppLogger.e('EditorMainArea', '创建场景控制器失败: $sceneId', e);
          widget.sceneControllers[sceneId] = QuillController(
            document: Document.fromJson([
              {'insert': '\n'}
            ]),
            selection: const TextSelection.collapsed(offset: 0),
          );
          widget.sceneSummaryControllers[sceneId] = TextEditingController(text: '');
        }
      }

      return SceneEditor(
        title: '${chapter.title} · Scene ${index + 1}',
        wordCount: '${scene.wordCount} Words',
        isActive: widget.activeActId == actId &&
                  widget.activeChapterId == chapter.id &&
                  widget.activeSceneId == scene.id,
        actId: actId,
        chapterId: chapter.id,
        sceneId: scene.id,
        isFirst: isFirst,
        controller: widget.sceneControllers[sceneId]!,
        summaryController: widget.sceneSummaryControllers[sceneId]!,
        editorBloc: widget.editorBloc,
      );
    }).toList();

    return ChapterSection(
      title: chapter.title,
      scenes: sceneWidgets,
      actId: actId,
      chapterId: chapter.id,
      editorBloc: widget.editorBloc,
    );
  }

  Document _parseDocumentSafely(String content) {
    try {
      final dynamic deltaJson = jsonDecode(content);
      if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
        final ops = deltaJson['ops'];
        if (ops is List) {
          return Document.fromJson(ops);
        }
      } else if (deltaJson is List) {
        return Document.fromJson(deltaJson);
      }
    } catch (e) {
      AppLogger.e('EditorMainArea', '解析文档内容失败: $content', e);
    }
    
    return Document.fromJson([
      {'insert': '\n'}
    ]);
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
