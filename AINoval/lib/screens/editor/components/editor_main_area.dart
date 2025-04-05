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
                      
                      // 动态构建Acts - 显示所有Act，不再过滤
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
    // 统计该Act的章节加载情况
    final totalChapters = act.chapters.length;
    final loadedChapters = act.chapters.where((chapter) => chapter.scenes.isNotEmpty).length;
    
    // 在每个 ActSection 外添加垂直间距
    return Padding(
      padding: const EdgeInsets.only(bottom: 48.0), // 增加 Act 之间的间距
      child: ActSection(
        title: act.title,
        chapters: act.chapters
            .where((chapter) => chapter.scenes.isNotEmpty) // 只显示有场景的章节
            .map((chapter) => _buildChapterSection(act.id, chapter))
            .toList(),
        actId: act.id,
        editorBloc: widget.editorBloc,
        totalChaptersCount: totalChapters,
        loadedChaptersCount: loadedChapters,
      ),
    );
  }

  Widget _buildChapterSection(String actId, novel_models.Chapter chapter) {
    // 如果章节没有场景，不显示
    if (chapter.scenes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 在每个 ChapterSection 外添加垂直间距
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0), // 增加 Chapter 之间的间距
      child: _buildChapterContent(actId, chapter), // 将内容提取到新方法
    );
  }

  // 新方法：构建章节内容，包括空状态或场景列表
  Widget _buildChapterContent(String actId, novel_models.Chapter chapter) {
    // 由于前面已经过滤过，这里的chapter.scenes肯定不为空，但为了代码安全，仍然保留检查
    if (chapter.scenes.isEmpty) {
      return const SizedBox.shrink();
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // 构建场景小部件 - 修改为成员方法
  Widget _buildSceneWidget(novel_models.Scene scene, String chapterId) {
    // 查找对应的actId
    final actId = _findActIdForChapter(chapterId);
    
    // 生成唯一ID
    final sceneId = '${actId}_${chapterId}_${scene.id}';
    
    // 检查当前场景是否处于活动状态
    bool isActive = false;
    String? activeActId;
    String? activeChapterId;
    String? activeSceneId;
    
    if (widget.editorBloc.state is EditorLoaded) {
      final state = widget.editorBloc.state as EditorLoaded;
      activeActId = state.activeActId;
      activeChapterId = state.activeChapterId;
      activeSceneId = state.activeSceneId;
      
      isActive = activeActId == actId && 
                activeChapterId == chapterId && 
                activeSceneId == scene.id;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? Colors.blue.shade300 : Colors.grey.shade200,
            width: isActive ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: isActive 
            ? [BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )]
            : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '场景 ${scene.id.substring(0, 4)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${scene.wordCount}字',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 显示场景内容预览
              Text(
                scene.content.length > 100
                    ? '${scene.content.substring(0, 100)}...'
                    : scene.content,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 编辑按钮
                  OutlinedButton(
                    onPressed: () {
                      // 设置当前场景为活动场景
                      widget.editorBloc.add(SetActiveScene(
                        actId: actId,
                        chapterId: chapterId,
                        sceneId: scene.id,
                      ));
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('编辑'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 辅助方法：根据章节ID查找所属Act ID
  String _findActIdForChapter(String chapterId) {
    for (final act in widget.novel.acts) {
      for (final chapter in act.chapters) {
        if (chapter.id == chapterId) {
          return act.id;
        }
      }
    }
    // 如果找不到，返回第一个Act的ID或空字符串
    return widget.novel.acts.isNotEmpty ? widget.novel.acts.first.id : '';
  }
}

class _AddActButton extends StatelessWidget {
  const _AddActButton({required this.editorBloc});
  final EditorBloc editorBloc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: OutlinedButton.icon(
          onPressed: () {
            editorBloc.add(const AddNewAct(title: '新Act'));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加新Act'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            backgroundColor: Colors.white,
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 1,
          ).copyWith(
            overlayColor: MaterialStateProperty.resolveWith<Color?>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) {
                  return theme.colorScheme.primary.withOpacity(0.1);
                }
                return null;
              },
            ),
          ),
        ),
      ),
    );
  }
}
