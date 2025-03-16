import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/screens/editor/components/act_section.dart';
import 'package:ainoval/screens/editor/components/chapter_section.dart';
import 'package:ainoval/screens/editor/components/scene_editor.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'dart:async';


class EditorMainArea extends StatefulWidget {
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
    // 构建该章节的所有场景
    final sceneWidgets = chapter.scenes.asMap().entries.map((entry) {
      final index = entry.key;
      final scene = entry.value;
      final isFirst = index == 0;

      // 为每个场景创建一个唯一的ID，确保包含scene.id
      final sceneId = '${actId}_${chapter.id}_${scene.id}';

      // 检查控制器是否存在，如果不存在则创建新的
      if (!widget.sceneControllers.containsKey(sceneId)) {
        try {
          // 创建新的控制器
          widget.sceneControllers[sceneId] = QuillController(
            document: _parseDocumentSafely(scene.content),
            selection: const TextSelection.collapsed(offset: 0),
          );

          // 初始化摘要控制器
          widget.sceneSummaryControllers[sceneId] = TextEditingController(
            text: scene.summary.content,
          );
          
          // 将这部分逻辑移到 SceneEditor 组件中
          try {
            final jsonStr = jsonEncode(widget.sceneControllers[sceneId]!.document.toDelta().toJson());
            
            // 直接更新，不使用定时器
            widget.editorBloc.add(UpdateSceneContent(
              novelId: widget.editorBloc.novelId,
              actId: actId,
              chapterId: chapter.id,
              sceneId: scene.id,
              content: jsonStr,
              shouldRebuild: false,
            ));
          } catch (e) {
            AppLogger.e('EditorMainArea', '更新内容失败: $sceneId', e);
          }
        } catch (e) {
          AppLogger.e('EditorMainArea', '创建场景控制器失败: $sceneId', e);
          // 创建默认控制器
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
        isActive: widget.activeActId == actId && widget.activeChapterId == chapter.id,
        actId: actId,
        chapterId: chapter.id,
        sceneId: scene.id,  // 传递完整的sceneId
        isFirst: isFirst,
        controller: widget.sceneControllers[sceneId]!,
        summaryController: widget.sceneSummaryControllers[sceneId]!,
        editorBloc: widget.editorBloc,
      );
    }).toList();

    // 如果没有场景或者场景控制器不存在，则使用默认的场景编辑器
    if (sceneWidgets.isEmpty) {
      final defaultSceneId = '${actId}_${chapter.id}';
      if (!widget.sceneControllers.containsKey(defaultSceneId)) {
        // 创建默认控制器
        widget.sceneControllers[defaultSceneId] = QuillController(
          document: Document.fromJson([
            {'insert': '\n'}
          ]),
          selection: const TextSelection.collapsed(offset: 0),
        );
        widget.sceneSummaryControllers[defaultSceneId] = TextEditingController(text: '');
      }

      // 尝试查找章节的第一个场景ID
      String? firstSceneId;
      if (chapter.scenes.isNotEmpty) {
        firstSceneId = chapter.scenes.first.id;
      }

      sceneWidgets.add(SceneEditor(
        title: '${chapter.title} · Scene 1',
        wordCount: '${chapter.wordCount} Words',
        isActive: widget.activeActId == actId && widget.activeChapterId == chapter.id,
        actId: actId,
        chapterId: chapter.id,
        sceneId: firstSceneId,
        controller: widget.sceneControllers[defaultSceneId]!,
        summaryController: widget.sceneSummaryControllers[defaultSceneId]!,
        editorBloc: widget.editorBloc,
      ));
    }

    return ChapterSection(
      title: chapter.title,
      scenes: sceneWidgets,
      actId: actId,
      chapterId: chapter.id,
      editorBloc: widget.editorBloc,
    );
  }

  // 新增安全解析文档内容的方法
  Document _parseDocumentSafely(String content) {
    try {
      // 尝试解析JSON
      final dynamic deltaJson = jsonDecode(content);
      if (deltaJson is Map<String, dynamic> && deltaJson.containsKey('ops')) {
        final ops = deltaJson['ops'];
        if (ops is List) {
          return Document.fromJson(ops);
        }
      } else if (deltaJson is List) {
        // 直接是ops数组
        return Document.fromJson(deltaJson);
      }
    } catch (e) {
      AppLogger.e('EditorMainArea', '解析文档内容失败: $content', e);
    }
    
    // 解析失败时返回空文档
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
