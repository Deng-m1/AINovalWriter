import 'package:ainoval/blocs/editor/editor_bloc.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/novel_summary.dart';

import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';
import 'package:ainoval/blocs/sidebar/sidebar_bloc.dart';
import 'dart:async'; // Import for StreamSubscription
import 'package:ainoval/utils/event_bus.dart'; // Import EventBus and the event

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

  // New state for managing expanded acts
  final Map<String, bool> _expandedActs = {};
  StreamSubscription<EditorState>? _editorBlocSubscription;
  StreamSubscription<NovelStructureUpdatedEvent>? _novelStructureUpdatedSubscription; // Added subscription

  @override
  void initState() {
    super.initState();
    _editorController = Provider.of<EditorScreenController>(context, listen: false);

    // 监听搜索文本变化
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text;
        });
      }
    });
    
    // 加载 SidebarBloc 数据
    final sidebarBloc = context.read<SidebarBloc>();
    final editorBloc = context.read<EditorBloc>(); // Get EditorBloc

    // Sync with current editor state for initial act expansion
    _syncActiveActExpansion(editorBloc.state, sidebarBloc.state);

    _editorBlocSubscription = editorBloc.stream.listen((editorState) {
      _syncActiveActExpansion(editorState, context.read<SidebarBloc>().state);
      if (mounted) {
        setState(() {}); // Rebuild to reflect active act/chapter highlighting
      }
    });

    // Listen for novel structure updates from the EventBus
    _novelStructureUpdatedSubscription = EventBus.instance.on<NovelStructureUpdatedEvent>().listen((event) {
      if (mounted && event.novelId == widget.novel.id) {
        AppLogger.i('ChapterDirectoryTab', 
          'Received NovelStructureUpdatedEvent for current novel (ID: ${widget.novel.id}, Type: ${event.updateType}). Reloading sidebar structure.');
        // To avoid potential race conditions or build errors if SidebarBloc is already processing,
        // add a small delay or check its state before adding the event.
        // For simplicity now, just add the event.
        sidebarBloc.add(LoadNovelStructure(widget.novel.id));
      }
    });
    
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
    _editorBlocSubscription?.cancel(); // Cancel subscription
    _novelStructureUpdatedSubscription?.cancel(); // Cancel new subscription
    super.dispose();
  }

  void _syncActiveActExpansion(EditorState editorState, SidebarState sidebarState) {
    if (editorState is EditorLoaded && editorState.activeActId != null) {
      final activeActId = editorState.activeActId!;
      if (sidebarState is SidebarLoaded) {
        bool actExists = sidebarState.novelStructure.acts.any((act) => act.id == activeActId);
        if (actExists) {
          if (!(_expandedActs[activeActId] ?? false)) {
            if (mounted) {
              setState(() {
                _expandedActs[activeActId] = true;
              });
            } else {
              _expandedActs[activeActId] = true;
            }
          }
        }
      }
    }
  }
  
  // Toggle Act expansion state
  void _toggleAct(String actId) {
    if (mounted) {
      setState(() {
        _expandedActs[actId] = !(_expandedActs[actId] ?? false);
      });
    }
  }

  // 切换章节展开状态
  void _toggleChapter(String chapterId) async {
    final isCurrentlyExpanded = _expandedChapters[chapterId] ?? false;
    
    setState(() {
      _expandedChapters[chapterId] = !isCurrentlyExpanded;
    });

    if (!isCurrentlyExpanded) {
      AppLogger.i('ChapterDirectoryTab', '展开章节: $chapterId');
      // 场景预加载逻辑已移除
    } else {
      AppLogger.i('ChapterDirectoryTab', '收起章节: $chapterId');
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
        String? targetActId;
        novel_models.Chapter? targetChapter;

        int currentChapterOrder = 0;
        for (final act in sidebarState.novelStructure.acts) {
          for (final chapter_ in act.chapters) {
            currentChapterOrder++;
            allChapters.add(chapter_); // Keep this for total count
            if (currentChapterOrder == chapterNumber) {
              targetChapter = chapter_;
              targetActId = act.id;
              break;
            }
          }
          if (targetChapter != null) break;
        }
        
        if (targetChapter == null || chapterNumber > allChapters.length) {
          _showErrorSnackbar('章节号超出范围');
          return;
        }
        
        // 由于章节序号是从1开始，所以需要减1来获取索引
        // final chapter = allChapters[chapterNumber - 1]; // This logic changes
        final chapter = targetChapter; // Use the found chapter
        
        // 确保章节和父卷展开
        if (mounted) {
          setState(() {
            if (targetActId != null) {
              _expandedActs[targetActId] = true; // Expand parent act
            }
            _expandedChapters[chapter.id] = true;
            _selectedChapterNumber = chapterNumber;
          });
        }
        
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
  
  void _navigateToChapter(String actId, String chapterId) {
    final editorBloc = context.read<EditorBloc>();
    AppLogger.i('ChapterDirectoryTab', '准备跳转到章节: ActID=$actId, ChapterID=$chapterId');

    // 1. 设置活动章节和卷（这将触发EditorBloc状态更新）
    // 同时也将这个章节设置为焦点章节
    editorBloc.add(SetActiveChapter(
      actId: actId,
      chapterId: chapterId,
    ));
    editorBloc.add(SetFocusChapter(chapterId: chapterId));


    // 2. 确保目标章节在视图中
    // 延迟执行，等待Bloc状态更新和UI重建
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return; // Check if the widget is still in the tree
      if (_editorController.editorMainAreaKey.currentState != null) {
        AppLogger.i('ChapterDirectoryTab', '通过EditorMainArea滚动到章节: $chapterId');
        _editorController.editorMainAreaKey.currentState!.scrollToChapter(chapterId); 
      } else {
        AppLogger.w('ChapterDirectoryTab', 'EditorMainAreaKey.currentState为空，无法滚动到章节');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 使用 BlocBuilder 构建UI，基于 SidebarBloc 的状态
    return BlocBuilder<SidebarBloc, SidebarState>(
      builder: (context, sidebarState) {
        if (sidebarState is SidebarLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (sidebarState is SidebarLoaded) {
          // Sync active act expansion when data is loaded, if not already handled by listener
           _syncActiveActExpansion(context.read<EditorBloc>().state, sidebarState);
          return Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // 跳转和搜索区域
                _buildSearchAndJumpSection(theme),
                
                // 章节列表
                Expanded(
                  child: sidebarState.novelStructure.acts.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildActList(sidebarState.novelStructure, theme),
                ),
              ],
            ),
          );
        } else if (sidebarState is SidebarError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                const SizedBox(height: 16),
                Text('加载目录失败: ${sidebarState.message}', 
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
            '暂无章节或卷',
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
  
  Widget _buildActList(novel_models.Novel novel, ThemeData theme) {
    List<Widget> actItems = [];
    int globalChapterCounter = 0;

    final editorState = context.read<EditorBloc>().state;
    String? activeActId;
    String? activeChapterId;

    if (editorState is EditorLoaded) {
      activeActId = editorState.activeActId;
      activeChapterId = editorState.activeChapterId;
    }

    for (int actIndex = 0; actIndex < novel.acts.length; actIndex++) {
      final act = novel.acts[actIndex];
      bool isActExpanded = _expandedActs[act.id] ?? false;
      bool isActActive = activeActId == act.id;

      List<novel_models.Chapter> chaptersToShowInAct = act.chapters;
      bool actMatchesSearch = true; // Assume true if no search text

      if (_searchText.isNotEmpty) {
        // Filter chapters within this act
        chaptersToShowInAct = act.chapters.where((chapter) {
          bool chapterTitleMatches = chapter.title.toLowerCase().contains(_searchText.toLowerCase());
          bool sceneMatches = chapter.scenes.any((scene) => scene.summary.content.toLowerCase().contains(_searchText.toLowerCase()));
          return chapterTitleMatches || sceneMatches;
        }).toList();

        bool actTitleMatches = act.title.toLowerCase().contains(_searchText.toLowerCase());
        // Act is shown if its title matches OR it has chapters that match
        if (!actTitleMatches && chaptersToShowInAct.isEmpty) {
          continue; // Skip this act if neither title nor children match
        }
        actMatchesSearch = true; // Act is relevant to search
      }
      
      if (actMatchesSearch) {
         actItems.add(_buildActItem(
          act,
          actIndex,
          theme,
          isActExpanded,
          isActActive,
          chaptersToShowInAct,
          activeChapterId,
          // globalChapterCounter, // Removed global counter from here
          // (int count) => globalChapterCounter = count, 
        ));
      }
    }
    
    if (actItems.isEmpty && _searchText.isNotEmpty) {
       return _buildNoSearchResults(theme);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: actItems,
    );
  }

  Widget _buildActItem(
    novel_models.Act act,
    int actIndex,
    ThemeData theme,
    bool isExpanded,
    bool isActive,
    List<novel_models.Chapter> chaptersToDisplay,
    String? activeChapterId,
    // int currentGlobalChapterStartNum, // Removed global counter from here
    // Function(int) updateGlobalChapterCountCallback, // Removed global callback
  ) {
    final primaryColorLight = theme.colorScheme.primary.withOpacity(0.1);
    // int chapterCounterForThisAct = currentGlobalChapterStartNum; // Removed global logic here

    // Main column children for the Act item
    List<Widget> mainColumnChildren = [];

    // Act Title Widget
    Widget actTitleWidget = Material(
      color: Colors.transparent,
      borderRadius: isExpanded 
          ? const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            )
          : BorderRadius.circular(12), // Fully round if not expanded
      child: InkWell(
        borderRadius: isExpanded 
            ? const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              )
            : BorderRadius.circular(11), // slightly smaller for better visual
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
        onTap: () => _toggleAct(act.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Transform.rotate(
                  angle: isExpanded ? 0.0 : -1.5708, // 0 or -90 degrees
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: isActive ? theme.colorScheme.primary : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isActive) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          blurRadius: 3,
                        )
                      ]),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  act.title.isNotEmpty ? '第${actIndex + 1}卷: ${act.title}' : '第${actIndex + 1}卷',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isActive ? theme.colorScheme.primary : Colors.grey.shade800,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${act.chapters.length}章', // Display total chapters in this act
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? theme.colorScheme.primary : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    mainColumnChildren.add(actTitleWidget);

    int finalChapterCountForThisAct = 0; // Local count for this act

    if (isExpanded) {
      List<Widget> chapterItems = [];
      if (chaptersToDisplay.isNotEmpty) {
        for (int chapterIndex = 0; chapterIndex < chaptersToDisplay.length; chapterIndex++) {
          final chapter = chaptersToDisplay[chapterIndex];
          finalChapterCountForThisAct++; 
          final chapterNumberInAct = chapterIndex + 1; // Chapter number within this act
          
          // bool isChapterHighlightedByJump = _selectedChapterNumber == globalChapterNumber; // Needs re-evaluation if jump highlight is critical
          bool isChapterActive = activeChapterId == chapter.id;
          
          List<novel_models.Scene> scenesToDisplayForChapter = chapter.scenes;
          if (_searchText.isNotEmpty) {
            scenesToDisplayForChapter = chapter.scenes.where((scene) => 
              scene.summary.content.toLowerCase().contains(_searchText.toLowerCase())
            ).toList();
          }

          chapterItems.add(_buildChapterItem(
            act, 
            chapter, 
            chapterNumberInAct, // Pass chapterNumberInAct
            theme, 
            isChapterActive, 
            // isChapterHighlightedByJump, // Temporarily remove jump highlight or rethink its mechanism
            false, // Placeholder for isChapterHighlightedByJump
            scenesToDisplayForChapter
          ));
        }
      }

      Widget chaptersSectionWidget;
      if (chapterItems.isNotEmpty) {
        chaptersSectionWidget = ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(11),
            bottomRight: Radius.circular(11),
          ),
          child: Container(
            color: Colors.white.withOpacity(0.5),
            padding: const EdgeInsets.only(top: 4.0, bottom:4.0, left: 8.0, right: 8.0),
            child: Column(children: chapterItems),
          ),
        );
      } else if (_searchText.isNotEmpty && chaptersToDisplay.isEmpty) {
        // If searching and this act has no matching chapters to display
        chaptersSectionWidget = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            '此卷内无匹配章节',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        );
      } else if (act.chapters.isEmpty) {
         // If the act originally has no chapters
        chaptersSectionWidget = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            '此卷下暂无章节',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        );
      } else {
        // Fallback for other cases, e.g. chapters exist but all filtered out by a non-chapter-title search
         chaptersSectionWidget = const SizedBox.shrink(); // Or a more specific message
      }
      
      mainColumnChildren.add(chaptersSectionWidget);
      // Update the global chapter count *after* processing all chapters for this act
      // updateGlobalChapterCountCallback(finalChapterCountForThisAct); // Removed global callback
    }


    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? primaryColorLight.withOpacity(0.15) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: isActive ? 5 : 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: isActive
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.4), width: 1.5)
            : Border.all(color: Colors.grey.shade200, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mainColumnChildren, // Use the prepared list of widgets
      ),
    );
  }
  
  Widget _buildChapterItem(
    novel_models.Act parentAct,
    novel_models.Chapter chapter, 
    int chapterNumberInAct, // Changed from globalChapterNumber
    ThemeData theme,
    bool isActiveChapter, 
    bool isHighlightedByJump, // Kept for now, but its calculation might need adjustment
    List<novel_models.Scene> scenesToDisplay, 
  ) {
    final chapterKey = GlobalObjectKey('chapter_${chapter.id}');
    final isChapterExpandedForScenes = _expandedChapters[chapter.id] ?? false;
    final primaryColorLight = theme.colorScheme.primary.withOpacity(0.1);
    
    // Determine actual highlight state
    final bool isHighlighted = isHighlightedByJump || isActiveChapter;

    return AnimatedContainer(
      key: chapterKey,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4), // Reduced horizontal margin
      decoration: BoxDecoration(
        color: isHighlighted 
            ? primaryColorLight.withOpacity(0.2) // Adjusted opacity for active/jumped chapter
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? theme.colorScheme.primary.withOpacity(0.15)
                : Colors.black.withOpacity(0.03),
            blurRadius: isHighlighted ? 4 : 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: isActiveChapter // More prominent border for truly active chapter
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5)
            : Border.all(color: Colors.grey.shade200.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              splashColor: theme.colorScheme.primary.withOpacity(0.1),
              highlightColor: theme.colorScheme.primary.withOpacity(0.05),
              onTap: () => _toggleChapter(chapter.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    // Expand/Collapse Icon for toggling scenes list
                     AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Transform.rotate(
                          angle: isChapterExpandedForScenes ? 0.0 : -1.5708, // 0 or -90度
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: isHighlighted
                              ? theme.colorScheme.primary
                              : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    
                    if (isActiveChapter) ...[ // Indicator for strictly active chapter
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
                        '第$chapterNumberInAct章：${chapter.title}',
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                          color: isHighlighted
                              ? theme.colorScheme.primary
                              : Colors.grey.shade800,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Jump to Chapter Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _navigateToChapter(parentAct.id, chapter.id),
                        borderRadius: BorderRadius.circular(20),
                        splashColor: theme.colorScheme.primary.withOpacity(0.2),
                        highlightColor: theme.colorScheme.primary.withOpacity(0.1),
                        child: Tooltip(
                          message: '跳转到此章节',
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.shortcut_rounded, 
                              size: 18,
                              color: isHighlighted ? theme.colorScheme.primary : Colors.blueGrey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isHighlighted
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notes_outlined, // Changed icon
                            size: 10,
                            color: isHighlighted ? theme.colorScheme.primary : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${chapter.scenes.length}场景', // Use original scene count for display
                            style: TextStyle(
                              fontSize: 10,
                              color: isHighlighted ? theme.colorScheme.primary : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Word count can be added back if needed
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            child: AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: _buildScenesList(
                parentAct.id, 
                chapter, 
                _searchText, // Pass search text to filter scenes if necessary
                theme,
                scenesToDisplay // Pass the filtered list of scenes
              ),
              crossFadeState: isChapterExpandedForScenes ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '没有匹配的卷、章节或场景',
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
              if (mounted) {
                setState(() {
                  _searchText = '';
                });
              }
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
  
  Widget _buildScenesList(
    String actId, 
    novel_models.Chapter chapter, 
    String searchText, // Keep for potential direct scene filtering if needed later
    ThemeData theme,
    List<novel_models.Scene> scenesToDisplay, // Use this list
  ) {
    final scenesWidgets = <Widget>[]; // Renamed to avoid conflict
    
    String? activeSceneId;
    final editorState = context.read<EditorBloc>().state;
    if (editorState is EditorLoaded) {
      activeSceneId = editorState.activeSceneId;
    }
    
    AppLogger.i('ChapterDirectoryTab', '构建章节 ${chapter.id} 的场景列表，显示 ${scenesToDisplay.length} 个场景 (可能已过滤)');
    
    if (chapter.scenes.isEmpty) { // Check original scenes list for "loading"
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


    if (scenesToDisplay.isEmpty && _searchText.isNotEmpty) {
      // This case indicates that scenes were filtered out by search,
      // but chapter itself might have matched or parent Act matched.
      // No need to show "本章节暂无场景" if it's due to search filtering.
      // If original chapter.scenes was empty, the above block handles it.
      // If scenesToDisplay is empty because of search, this list will just be empty.
    } else if (scenesToDisplay.isEmpty && _searchText.isEmpty && chapter.scenes.isNotEmpty) {
      // This should not happen if chapter.scenes is not empty.
      // This case is for when originally there are scenes, but somehow scenesToDisplay is empty without search.
      // This is more like a fallback or error.
       AppLogger.w('ChapterDirectoryTab', '场景列表为空，但章节(${chapter.id})有场景且无搜索词。');
    }


    for (int i = 0; i < scenesToDisplay.length; i++) {
      final scene = scenesToDisplay[i];
      // Scene filtering logic is now handled before calling _buildScenesList for search context.
      // We are iterating over `scenesToDisplay` which is already filtered if `_searchText` is active.
      
      final summaryText = scene.summary.content.isEmpty 
          ? '(无摘要)' 
          : scene.summary.content;
      final truncatedSummary = summaryText.length > 100 
          ? '${summaryText.substring(0, 100)}...' 
          : summaryText;
          
      // 检查是否为活跃场景
      final isActiveScene = scene.id == activeSceneId;
      
      scenesWidgets.add(
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
              onTap: () => _navigateToChapter(actId, chapter.id),
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
    
    // If scenesWidgets list is empty (and original chapter had scenes but they were filtered out)
    if (scenesWidgets.isEmpty && chapter.scenes.isNotEmpty && _searchText.isNotEmpty) {
        // Don't show "本章节暂无场景" if it's due to search filtering out all scenes.
        // The list will just be empty.
    } else if (scenesWidgets.isEmpty && chapter.scenes.isEmpty) {
        // This is the original "本章节暂无场景" for chapters that genuinely have no scenes.
         scenesWidgets.add(
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
    } else if (scenesWidgets.isEmpty && scenesToDisplay.isEmpty && _searchText.isEmpty && chapter.scenes.isNotEmpty) {
      // This implies an issue or the chapter's scenes are pending load, but the initial check for chapter.scenes.isEmpty handles loading.
      // This case might not be hit if the above logic is correct.
      // For safety, if no scenes rendered and original had scenes and no search, show "no scenes"
       scenesWidgets.add(
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
    
    AppLogger.i('ChapterDirectoryTab', '构建场景列表完成: ${scenesWidgets.length}个场景挂件');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8), // Added horizontal padding for scenes
      child: Column(children: scenesWidgets),
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
