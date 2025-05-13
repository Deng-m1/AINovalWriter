import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';

import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/blocs/sidebar/sidebar_bloc.dart';

/// 章节目录标签页组件
class ChapterDirectoryTab extends StatefulWidget {
  const ChapterDirectoryTab({super.key, required this.novel});
  final NovelSummary novel;

  @override
  State<ChapterDirectoryTab> createState() => _ChapterDirectoryTabState();
}

class _ChapterDirectoryTabState extends State<ChapterDirectoryTab> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _jumpController = TextEditingController();
  final Map<String, bool> _expandedChapters = {};
  String _searchText = '';
  int? _selectedChapterNumber;
  late final EditorScreenController _editorController;

  @override
  void initState() {
    super.initState();
    _editorController = Provider.of<EditorScreenController>(context, listen: false);

    // 监听搜索文本变化
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
    
    // 加载 SidebarBloc 数据
    final sidebarBloc = context.read<SidebarBloc>();
    
    // 使用日志记录当前状态
    if (sidebarBloc.state is SidebarInitial) {
      AppLogger.i('ChapterDirectoryTab', 'SidebarBloc 处于初始状态，开始加载小说结构');
      // 首次加载
      sidebarBloc.add(LoadNovelStructure(widget.novel.id));
    } else if (sidebarBloc.state is SidebarLoaded) {
      AppLogger.i('ChapterDirectoryTab', 'SidebarBloc 已加载，使用已有数据');
      // 如果已经加载，检查一下是否是当前小说的数据
      final state = sidebarBloc.state as SidebarLoaded;
      if (state.novelStructure.id != widget.novel.id) {
        AppLogger.w('ChapterDirectoryTab', 
          '当前加载的小说(${state.novelStructure.id})与目标小说(${widget.novel.id})不同，重新加载');
        sidebarBloc.add(LoadNovelStructure(widget.novel.id));
      } else {
        // 如果已经是当前小说，检查每个章节是否有场景
        int chaptersWithoutScenes = 0;
        for (final act in state.novelStructure.acts) {
          for (final chapter in act.chapters) {
            if (chapter.scenes.isEmpty) {
              chaptersWithoutScenes++;
            }
          }
        }
        
        if (chaptersWithoutScenes > 0) {
          AppLogger.i('ChapterDirectoryTab', 
            '发现 $chaptersWithoutScenes 个章节没有场景数据，重新加载小说结构');
          sidebarBloc.add(LoadNovelStructure(widget.novel.id));
        }
      }
    } else if (sidebarBloc.state is SidebarError) {
      AppLogger.e('ChapterDirectoryTab', 
        '之前加载小说结构失败，重试: ${(sidebarBloc.state as SidebarError).message}');
      // 之前加载失败，重试
      sidebarBloc.add(LoadNovelStructure(widget.novel.id));
    } else {
      AppLogger.w('ChapterDirectoryTab', '未知的SidebarBloc状态，重新加载');
      sidebarBloc.add(LoadNovelStructure(widget.novel.id));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  // 切换章节展开状态
  void _toggleChapter(String chapterId) async {
    final isCurrentlyExpanded = _expandedChapters[chapterId] ?? false;
    
    if (!isCurrentlyExpanded) {
      // 在UI立即展开章节，不等待加载完成
      setState(() {
        _expandedChapters[chapterId] = true;
      });
      
      AppLogger.i('ChapterDirectoryTab', '展开章节: $chapterId');
      
      // 获取当前状态，检查章节是否有场景摘要
      bool needsPreload = false;
      String? actId;
      
      // 查找章节所属的 Act ID
      final sidebarState = context.read<SidebarBloc>().state;
      if (sidebarState is SidebarLoaded) {
        for (final act in sidebarState.novelStructure.acts) {
          for (final chapter in act.chapters) {
            if (chapter.id == chapterId) {
              actId = act.id;
              needsPreload = chapter.scenes.isEmpty; // 如果没有场景，需要预加载
              break;
            }
          }
          if (actId != null) break;
        }
      }
      
      // 如果章节已有场景摘要数据，不需要额外加载
      if (!needsPreload) {
        AppLogger.i('ChapterDirectoryTab', '章节 $chapterId 已有场景摘要数据，无需预加载');
        return;
      }
      
      // 如果需要预加载，进行异步预加载
      if (actId != null) {
        AppLogger.i('ChapterDirectoryTab', '章节 $chapterId 需要预加载场景数据');
        
        try {
          // 异步预加载场景并在完成后更新UI
          await _editorController.preloadChapterScenes(chapterId, actId: actId);
          
          // 如果组件还在树中，更新UI
          if (mounted) {
            setState(() {
              // 更新完成后的状态刷新
              AppLogger.i('ChapterDirectoryTab', '章节 $chapterId 场景预加载完成，刷新UI');
            });
          }
        } catch (e) {
          AppLogger.e('ChapterDirectoryTab', '预加载章节场景失败', e);
          
          // 即使失败也保持章节展开状态
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        AppLogger.w('ChapterDirectoryTab', '无法确定章节 $chapterId 所属的卷ID，无法预加载场景');
      }
    } else {
      // 收起章节
      setState(() {
        _expandedChapters[chapterId] = false;
      });
    }
  }

  void _jumpToChapter() {
    try {
      final chapterNumber = int.parse(_jumpController.text.trim());
      if (chapterNumber < 1) {
        _showErrorSnackbar('章节号必须大于0');
        return;
      }

      // 使用 SidebarBloc 中的数据
      final sidebarState = context.read<SidebarBloc>().state;
      if (sidebarState is SidebarLoaded) {
        // 扁平化所有章节以便按序号查找
        final allChapters = <novel_models.Chapter>[];
        for (final act in sidebarState.novelStructure.acts) {
          allChapters.addAll(act.chapters);
        }
        
        // 按order排序
        allChapters.sort((a, b) => a.order.compareTo(b.order));
        
        if (chapterNumber > allChapters.length) {
          _showErrorSnackbar('章节号超出范围');
          return;
        }
        
        // 由于章节序号是从1开始，所以需要减1来获取索引
        final chapter = allChapters[chapterNumber - 1];
        
        // 确保章节展开
        setState(() {
          _expandedChapters[chapter.id] = true;
          _selectedChapterNumber = chapterNumber;
        });
        
        // 滚动到对应章节
        Future.delayed(const Duration(milliseconds: 300), () {
          final context = _getChapterContext(chapter.id);
          if (context != null) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.3, // 滚动位置：0表示顶部，0.5表示中间，1表示底部
              duration: const Duration(milliseconds: 500),
            );
          }
          
          // 5秒后清除高亮
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _selectedChapterNumber = null;
              });
            }
          });
        });
        
        // 清空输入框
        _jumpController.clear();
      }
    } catch (e) {
      _showErrorSnackbar('请输入有效的章节号');
    }
  }
  
  // 获取章节的BuildContext，用于滚动定位
  BuildContext? _getChapterContext(String chapterId) {
    final chapterKey = GlobalObjectKey('chapter_$chapterId');
    return chapterKey.currentContext;
  }
  
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _navigateToScene(String actId, String chapterId, String sceneId) {
    final editorBloc = context.read<EditorBloc>();
    
    // 先加载当前章节的场景（确保内容已加载）
    AppLogger.i('ChapterDirectoryTab', '开始加载章节场景: $actId - $chapterId - $sceneId');
    editorBloc.add(LoadMoreScenes(
      fromChapterId: chapterId,
      direction: 'center',
      chaptersLimit: 5, // 增加加载章节数量，确保足够加载所有内容
      actId: actId,
      targetChapterId: chapterId,
      targetSceneId: sceneId,
      preventFocusChange: false // 确保设置为false，允许改变焦点
    ));
    
    // 关键修改：先尝试通过EditorMainArea实例设置活动章节
    if (_editorController.editorMainAreaKey.currentState != null) {
      // 如果能获取到EditorMainArea实例，通过它设置活动章节
      AppLogger.i('ChapterDirectoryTab', '通过EditorMainArea明确设置活动章节: $actId - $chapterId');
      _editorController.editorMainAreaKey.currentState!.setActiveChapter(actId, chapterId);
    }
    
    // 然后设置活动场景
    editorBloc.add(SetActiveScene(
      actId: actId,
      chapterId: chapterId,
      sceneId: sceneId,
    ));
    
    // 主动滚动到活动场景
    _scrollToActiveScene(actId, chapterId, sceneId);
    
    AppLogger.i('ChapterDirectoryTab', '已发送场景跳转请求: $actId - $chapterId - $sceneId');
  }
  
  // 滚动到活动场景的辅助方法
  void _scrollToActiveScene(String actId, String chapterId, String sceneId) {
    // 延迟500ms确保UI已经更新
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_editorController.editorMainAreaKey.currentState != null) {
        _editorController.editorMainAreaKey.currentState!.scrollToActiveScene();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 使用 BlocBuilder 构建UI，基于 SidebarBloc 的状态
    return BlocBuilder<SidebarBloc, SidebarState>(
      builder: (context, state) {
        if (state is SidebarLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is SidebarLoaded) {
          return Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // 跳转和搜索区域
                _buildSearchAndJumpSection(theme),
                
                // 章节列表
                Expanded(
                  child: state.novelStructure.acts.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildChapterList(state.novelStructure, theme),
                ),
              ],
            ),
          );
        } else if (state is SidebarError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                const SizedBox(height: 16),
                Text('加载目录失败: ${state.message}', 
                  style: TextStyle(color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // 重新加载
                    context.read<SidebarBloc>().add(LoadNovelStructure(widget.novel.id));
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        } else {
          // 初始状态或未知状态
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('正在初始化目录...', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ),
          );
        }
      },
    );
  }
  
  Widget _buildSearchAndJumpSection(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 跳转区域
          Row(
            children: [
              Text('跳转至:', style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              )),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _jumpController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    decoration: InputDecoration(
                      hintText: '章节号',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _jumpToChapter(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _jumpToChapter,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 搜索区域
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              decoration: InputDecoration(
                hintText: '搜索章节和场景...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search, size: 16, color: Colors.grey.shade600),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            '暂无章节',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w600, 
              color: Colors.grey.shade800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '小说结构创建中，请稍后再试',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChapterList(novel_models.Novel novel, ThemeData theme) {
    final chapters = <Widget>[];
    int chapterCounter = 0; // 记录总章节序号，用于显示
    final primaryColorLight = theme.colorScheme.primary.withOpacity(0.1);
    
    // 将章节和场景平铺为一个列表
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        chapterCounter++;
        
        // 这是当前循环章节的序号
        final chapterNumber = chapterCounter;
        
        // 如果有搜索文本，判断是否此章节应该显示
        bool shouldShowChapter = true;
        bool hasMatchingScene = false;
        
        if (_searchText.isNotEmpty) {
          // 检查章节标题是否匹配
          shouldShowChapter = chapter.title.toLowerCase().contains(_searchText.toLowerCase());
          
          // 检查是否有匹配的场景
          for (final scene in chapter.scenes) {
            if (scene.summary.content.toLowerCase().contains(_searchText.toLowerCase())) {
              hasMatchingScene = true;
              break;
            }
          }
          
          // 如果章节标题不匹配且没有匹配的场景，则不显示该章节
          if (!shouldShowChapter && !hasMatchingScene) {
            continue;
          }
        }
        
        // 构建章节组件
        final chapterKey = GlobalObjectKey('chapter_${chapter.id}');
        final isExpanded = _expandedChapters[chapter.id] ?? false;
        final isHighlighted = _selectedChapterNumber == chapterNumber;
        
        // 尝试获取EditorBloc状态判断当前章节是否活跃
        bool isActiveChapter = false;
        final editorState = context.read<EditorBloc>().state;
        if (editorState is EditorLoaded) {
          isActiveChapter = editorState.activeChapterId == chapter.id;
        }
        
        chapters.add(
          AnimatedContainer(
            key: chapterKey,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isHighlighted 
                  ? theme.colorScheme.primary.withOpacity(0.08) 
                  : isActiveChapter 
                      ? primaryColorLight 
                      : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isHighlighted || isActiveChapter
                      ? theme.colorScheme.primary.withOpacity(0.15)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: isHighlighted || isActiveChapter ? 4 : 2,
                  offset: const Offset(0, 1),
                ),
              ],
              border: isActiveChapter
                  ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 章节标题行
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: theme.colorScheme.primary.withOpacity(0.1),
                    highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                    onTap: () => _toggleChapter(chapter.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          // 箭头图标
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: Transform.rotate(
                              angle: isExpanded ? 0.0 : -1.5708, // 0 或 -90度
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: isHighlighted || isActiveChapter
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          
                          // 章节状态指示器（活跃章节有颜色）
                          if (isActiveChapter) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          
                          Expanded(
                            child: Text(
                              '第$chapterNumber章：${chapter.title}',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: isHighlighted || isActiveChapter
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade800,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // 章节场景数量和字数
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHighlighted || isActiveChapter 
                                ? theme.colorScheme.primary.withOpacity(0.15)
                                : theme.colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 10,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${chapter.scenes.length}场景',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Container(
                                  width: 1,
                                  height: 8,
                                  color: theme.colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${chapter.wordCount}字',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 场景列表（如果章节展开）
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: AnimatedCrossFade(
                    firstChild: const SizedBox(height: 0),
                    secondChild: _buildScenesList(act.id, chapter, _searchText, theme),
                    crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                    sizeCurve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    if (chapters.isEmpty && _searchText.isNotEmpty) {
      // 没有搜索结果
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '没有匹配的章节或场景',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试其他关键词重新搜索',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('清除搜索'),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchText = '';
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: chapters,
    );
  }
  
  Widget _buildScenesList(
    String actId, 
    novel_models.Chapter chapter, 
    String searchText, 
    ThemeData theme
  ) {
    final scenes = <Widget>[];
    
    // 尝试获取EditorBloc状态判断当前场景是否活跃
    String? activeSceneId;
    final editorState = context.read<EditorBloc>().state;
    if (editorState is EditorLoaded) {
      activeSceneId = editorState.activeSceneId;
    }
    
    AppLogger.i('ChapterDirectoryTab', '构建章节 ${chapter.id} 的场景列表，章节有 ${chapter.scenes.length} 个场景');
    
    // 如果章节没有场景，但已经展开，显示加载指示器
    if (chapter.scenes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 12),
              Text('加载场景信息...', 
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    for (int i = 0; i < chapter.scenes.length; i++) {
      final scene = chapter.scenes[i];
      
      // 如果有搜索文本，过滤场景
      if (searchText.isNotEmpty) {
        final matchesTitle = 'Scene ${i + 1}'.toLowerCase().contains(searchText.toLowerCase());
        final matchesSummary = scene.summary.content.toLowerCase().contains(searchText.toLowerCase());
        
        if (!matchesTitle && !matchesSummary) {
          continue;
        }
      }
      
      // 获取摘要，截取一定长度
      final summaryText = scene.summary.content.isEmpty 
          ? '(无摘要)' 
          : scene.summary.content;
      final truncatedSummary = summaryText.length > 100 
          ? '${summaryText.substring(0, 100)}...' 
          : summaryText;
          
      // 检查是否为活跃场景
      final isActiveScene = scene.id == activeSceneId;
      
      scenes.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActiveScene 
                ? theme.colorScheme.primary.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActiveScene 
                ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              splashColor: theme.colorScheme.primary.withOpacity(0.1),
              highlightColor: theme.colorScheme.primary.withOpacity(0.05),
              onTap: () => _navigateToScene(actId, chapter.id, scene.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 场景图标指示器
                        Icon(
                          isActiveScene 
                              ? Icons.article
                              : Icons.article_outlined, 
                          size: 14, 
                          color: isActiveScene
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 8),
                        
                        // 场景标题
                        Text(
                          scene.title.isNotEmpty ? scene.title : 'Scene ${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActiveScene ? FontWeight.w600 : FontWeight.w500,
                            color: isActiveScene
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withOpacity(0.85),
                          ),
                        ),
                        
                        // 最后编辑时间
                        const Spacer(),
                        Text(
                          _formatTimestamp(scene.lastEdited),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        
                        // 字数显示
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isActiveScene
                                ? theme.colorScheme.primary.withOpacity(0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${scene.wordCount}字',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActiveScene
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // 场景摘要
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isActiveScene
                            ? theme.colorScheme.primary.withOpacity(0.03)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActiveScene
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        truncatedSummary,
                        style: TextStyle(
                          fontSize: 12,
                          color: isActiveScene
                              ? Colors.grey.shade800
                              : Colors.grey.shade700,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // 如果场景列表为空，添加一个提示
    if (scenes.isEmpty) {
      scenes.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              '本章节暂无场景',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    
    AppLogger.i('ChapterDirectoryTab', '构建场景列表完成: ${chapter.scenes.length}个场景');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: scenes),
    );
  }
  
  // 格式化时间戳为友好格式
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      // 超过一周，显示日期
      return '${timestamp.month}/${timestamp.day}';
    } else if (difference.inDays > 0) {
      // 显示几天前
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      // 显示几小时前
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      // 显示几分钟前
      return '${difference.inMinutes}分钟前';
    } else {
      // 刚刚
      return '刚刚';
    }
  }
}
