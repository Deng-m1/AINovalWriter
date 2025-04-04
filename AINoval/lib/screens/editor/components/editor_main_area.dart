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
    final theme = Theme.of(context);
    final veryLightGrey = Colors.grey.shade100; // 使用更浅的灰色或自定义颜色 #F8F9FA
    // 或者 Color(0xFFF8F9FA);

    // 获取当前EditorLoaded状态，检查是否正在加载更多场景
    bool isLoadingMore = false;
    if (widget.editorBloc.state is EditorLoaded) {
      final state = widget.editorBloc.state as EditorLoaded;
      isLoadingMore = state.isLoading;
    }

    return Stack(
      children: [
        Container(
          // 1. 使用更柔和的背景色
          color: veryLightGrey,
          child: SingleChildScrollView(
            controller: widget.scrollController,
            child: Center(
              child: ConstrainedBox(
                // 3. 限制内容最大宽度
                constraints: const BoxConstraints(maxWidth: 1100), // 保持或调整最大宽度
                child: Padding(
                  // 调整内边距，增加呼吸空间
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部加载指示器（向上滚动时加载更多）
                      if (isLoadingMore) _buildLoadingIndicator(),
                      
                      // 动态构建Acts
                      ...widget.novel.acts.map((act) => _buildActSection(act)),

                      // 添加新Act按钮
                      _AddActButton(editorBloc: widget.editorBloc),
                      
                      // 底部加载指示器（向下滚动时加载更多）
                      if (isLoadingMore) _buildLoadingIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActSection(novel_models.Act act) {
    // 在每个 ActSection 外添加垂直间距
    return Padding(
      padding: const EdgeInsets.only(bottom: 48.0), // 增加 Act 之间的间距
      child: ActSection(
        title: act.title,
        chapters: act.chapters
            .map((chapter) => _buildChapterSection(act.id, chapter))
            .toList(),
        actId: act.id,
        editorBloc: widget.editorBloc,
      ),
    );
  }

  Widget _buildChapterSection(String actId, novel_models.Chapter chapter) {
    // 在每个 ChapterSection 外添加垂直间距
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0), // 增加 Chapter 之间的间距
      child: _buildChapterContent(actId, chapter), // 将内容提取到新方法
    );
  }

  // 新方法：构建章节内容，包括空状态或场景列表
  Widget _buildChapterContent(String actId, novel_models.Chapter chapter) {
    if (chapter.scenes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Center(
          child: Column(
            children: [
              Text(
                '章节 "${chapter.title}" 还没有场景。',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16), // 增加间距
              ElevatedButton.icon(
                onPressed: () {
                  final newSceneId = const Uuid().v4();
                  widget.editorBloc.add(AddNewScene(
                    novelId: widget.editorBloc.novelId,
                    actId: actId,
                    chapterId: chapter.id,
                    sceneId: newSceneId,
                  ));
                },
                icon: const Icon(Icons.add, size: 18), // 调整图标大小
                label: const Text('添加第一个场景'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // 添加圆角
                  ),
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
          widget.sceneSummaryControllers[sceneId] =
              TextEditingController(text: '');
        }
      }

      return SceneEditor(
        key: ValueKey('scene_${actId}_${chapter.id}_${scene.id}'), // 使用唯一的 key
        title: 'Scene ${index + 1}', // 简化标题，章节标题在 ChapterSection 显示
        wordCount: '${scene.wordCount} 字', // 本地化或调整显示
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

  // 构建加载指示器
  Widget _buildLoadingIndicator() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
            SizedBox(width: 16),
            Text(
              "加载更多内容...",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
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
        child: OutlinedButton.icon(
          // 改为 OutlinedButton 样式
          onPressed: () {
            editorBloc.add(const AddNewAct(title: '新Act'));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Act'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300), // 更柔和的边框
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
