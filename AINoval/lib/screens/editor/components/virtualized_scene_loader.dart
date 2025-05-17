/**
 * 虚拟化场景加载器组件
 * 
 * 优化性能的核心组件，用于按需加载和初始化场景编辑器。
 * 通过可见性检测和性能优化策略，确保只有可见或即将可见的场景才会被加载，
 * 大幅减少内存占用和提高大型文档的编辑性能。
 */
import 'dart:convert';
import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/screens/editor/utils/document_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:ainoval/screens/editor/components/scene_editor.dart';

/// 虚拟化场景加载器组件
/// 
/// 负责高效地加载小说场景内容，使用懒加载和可见性检测技术
/// 实现按需加载场景，包括：
/// - 可见性检测确保只有可见场景被初始化
/// - 活动场景优先加载
/// - 跨卷场景使用延迟加载策略
/// - 占位符显示确保UI布局稳定
class VirtualizedSceneLoader extends StatefulWidget {
  /// 创建一个虚拟化场景加载器
  const VirtualizedSceneLoader({
    Key? key,
    required this.sceneId,
    required this.actId,
    required this.chapterId,
    required this.scene,
    required this.isFirst,
    required this.isActive,
    required this.sceneControllers,
    required this.sceneSummaryControllers,
    required this.sceneKeys,
    required this.editorBloc,
    required this.parseDocumentSafely,
    this.sceneIndex,
    this.onVisibilityChanged,
    // 从 editor_main_area 传递过来的，表示根据其父级滚动位置判断是否"大致"可见
    // 主要用于决定 wantKeepAlive 的初始值，以及是否在不可见时主动销毁控制器
    this.isParentVisuallyNearby = true, 
  }) : super(key: key);

  /// 场景的唯一标识符
  final String sceneId;
  
  /// 场景所属卷的ID
  final String actId;
  
  /// 场景所属章节的ID
  final String chapterId;
  
  /// 场景数据模型
  final novel_models.Scene scene;
  
  /// 是否是章节中的第一个场景
  final bool isFirst;
  
  /// 是否是当前活动场景
  final bool isActive;
  
  /// 存储所有场景编辑器控制器的映射
  final Map<String, QuillController> sceneControllers;
  
  /// 存储所有场景摘要控制器的映射
  final Map<String, TextEditingController> sceneSummaryControllers;
  
  /// 存储所有场景GlobalKey的映射
  final Map<String, GlobalKey> sceneKeys;
  
  /// 编辑器BLoC引用，用于状态管理和事件处理
  final editor_bloc.EditorBloc editorBloc;
  
  /// 文档内容解析函数
  final Function(String) parseDocumentSafely;
  
  /// 场景在章节中的序号，从1开始
  final int? sceneIndex;
  
  /// 场景可见性变化时的回调函数
  final Function(bool)? onVisibilityChanged;

  /// 由父组件（EditorMainArea）根据其视口计算得出，表示该场景是否在父组件的渲染区域内
  final bool isParentVisuallyNearby;

  @override
  State<VirtualizedSceneLoader> createState() => _VirtualizedSceneLoaderState();
}

class _VirtualizedSceneLoaderState extends State<VirtualizedSceneLoader> {
  /// 标记场景是否已初始化（控制器已创建并加载了内容）
  bool _isInitialized = false;
  
  /// 标记场景控制器是否正在初始化过程中
  bool _isControllerInitializing = false; 
  
  /// 由 VisibilityDetector 精确驱动，表示内容是否真实在屏幕上可见
  bool _isContentActuallyVisible = false; 

  @override
  void initState() {
    super.initState();
    // 确保有GlobalKey
    if (!widget.sceneKeys.containsKey(widget.sceneId)) {
      widget.sceneKeys[widget.sceneId] = GlobalKey();
    }

    // 活动场景总是立即尝试初始化
    if (widget.isActive) {
      AppLogger.d('VirtualizedSceneLoader', 'initState: 场景 ${widget.sceneId} 是活动场景，尝试初始化。');
      _tryInitializeControllers();
    } 
    // 如果父级认为它在附近，并且它当前应该显示（通常初始为true），也尝试初始化
    // 这个逻辑会被VisibilityDetector覆盖，但可以用于初始加载
    else if (widget.isParentVisuallyNearby) {
       AppLogger.d('VirtualizedSceneLoader', 'initState: 场景 ${widget.sceneId} 父级认为可见，尝试初始化。');
      _tryInitializeControllers();
    }
  }
  
  @override
  void didUpdateWidget(VirtualizedSceneLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果场景从非活动状态变更为活动状态，确保它被初始化
    if (widget.isActive && !oldWidget.isActive) {
      AppLogger.d('VirtualizedSceneLoader', 'didUpdateWidget: 场景 ${widget.sceneId} 变为活动状态，尝试初始化。');
      _tryInitializeControllers(); // 活动场景优先初始化
    }

    // 如果父组件对该场景的"大致可见性"判断发生变化
    if (widget.isParentVisuallyNearby != oldWidget.isParentVisuallyNearby) {
      AppLogger.d('VirtualizedSceneLoader', 'didUpdateWidget: 场景 ${widget.sceneId} isParentVisuallyNearby 变为 ${widget.isParentVisuallyNearby}。');
      if (widget.isParentVisuallyNearby && !_isInitialized && !_isControllerInitializing) {
        // 如果父级认为它应该可见了，并且尚未初始化，尝试初始化
        _tryInitializeControllers();
      } else if (!widget.isParentVisuallyNearby && _isInitialized && !_isContentActuallyVisible && !widget.isActive) {
        // 如果父级认为它不再大致可见，且内容已初始化，且真实不可见，且非活动场景
        // 可以考虑在这里销毁控制器以释放资源，但需要小心处理 SceneEditor 的 wantKeepAlive 逻辑
        // 目前 SceneEditor 的 wantKeepAlive 依赖 isVisuallyNearby (即这里的 _isContentActuallyVisible || widget.isActive)
        // AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 父级认为不可见，考虑卸载控制器。');
        // _disposeControllers(); // 谨慎使用
      }
    }

    // 如果场景变为活动状态，并且已经初始化，触发刷新以确保UI正确显示
    if (widget.isActive && !oldWidget.isActive && _isInitialized && mounted) {
      setState(() {
        AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为活动状态且已初始化，刷新UI。');
      });
    }
  }
  
  void _tryInitializeControllers() {
    if (!mounted || _isInitialized || _isControllerInitializing) return;
    
    _isControllerInitializing = true; 
    // AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 开始初始化控制器。');

    // 确保在setState之前检查mounted
    if (mounted) {
      setState(() {}); // 触发一次构建，让占位符先显示或更新状态
    }

    try {
      compute<String, Document>(DocumentParser.parseDocumentInIsolate, widget.scene.content)
        .then((document) {
          if (!mounted) {
            _isControllerInitializing = false;
            return;
          }
          widget.sceneControllers[widget.sceneId] = QuillController(
            document: document,
            selection: const TextSelection.collapsed(offset: 0),
          );
          widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
            text: widget.scene.summary.content,
          );
          
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _isControllerInitializing = false;
              AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 控制器异步初始化完成。');
            });
          } else {
             _isControllerInitializing = false;
          }
        })
        .catchError((e, stackTrace) {
          AppLogger.e('VirtualizedSceneLoader', '通过隔离初始化文档失败: ${widget.sceneId}', e, stackTrace);
          if (!mounted) {
            _isControllerInitializing = false;
            return;
          }
          // 回退到同步初始化
          try {
            widget.sceneControllers[widget.sceneId] = QuillController(
              document: widget.parseDocumentSafely(widget.scene.content),
              selection: const TextSelection.collapsed(offset: 0),
            );
            widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
              text: widget.scene.summary.content,
            );
            if (mounted) {
              setState(() {
                _isInitialized = true;
                _isControllerInitializing = false;
                AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 控制器同步回退初始化完成。');
              });
            } else {
              _isControllerInitializing = false;
            }
          } catch (syncError, syncStackTrace) {
            AppLogger.e('VirtualizedSceneLoader', '同步回退初始化文档也失败: ${widget.sceneId}', syncError, syncStackTrace);
            if (!mounted) {
              _isControllerInitializing = false;
              return;
            }
            widget.sceneControllers[widget.sceneId] = QuillController(
              document: Document.fromJson([{'insert': '错误：无法加载内容\n'}]), // 显示错误信息
              selection: const TextSelection.collapsed(offset: 0),
            );
            widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(text: widget.scene.summary.content); // 摘要可能仍然可用
             if (mounted) {
              setState(() {
                _isInitialized = true; // 标记为已初始化，即使是错误状态，避免无限重试
                _isControllerInitializing = false;
              });
            } else {
              _isControllerInitializing = false;
            }
          }
        });
    } catch (e, stackTrace) {
      AppLogger.e('VirtualizedSceneLoader', '创建场景控制器时捕获到顶层错误: ${widget.sceneId}', e, stackTrace);
      if (!mounted) {
        _isControllerInitializing = false;
        return;
      }
      widget.sceneControllers[widget.sceneId] = QuillController(
        document: Document.fromJson([{'insert': '错误：无法加载内容\n'}]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(text: widget.scene.summary.content);
      if (mounted) {
        setState(() {
          _isInitialized = true; 
          _isControllerInitializing = false;
        });
      } else {
        _isControllerInitializing = false;
      }
    }
  }

  // 考虑添加一个销毁控制器的方法，在场景长时间不可见时调用
  // void _disposeControllers() {
  //   if (_isInitialized) {
  //     AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 销毁控制器。');
  //     widget.sceneControllers.remove(widget.sceneId)?.dispose();
  //     widget.sceneSummaryControllers.remove(widget.sceneId)?.dispose();
  //     if (mounted) {
  //       setState(() {
  //         _isInitialized = false;
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final sceneKey = widget.sceneKeys[widget.sceneId] ?? GlobalKey();
    if (!widget.sceneKeys.containsKey(widget.sceneId)) {
      widget.sceneKeys[widget.sceneId] = sceneKey;
    }
    
    // 这里的逻辑是：
    // 1. 如果场景是活动的，或者VisibilityDetector报告它是可见的，那么它就是"视觉上临近"的。
    //    这个值会传递给SceneEditor的wantKeepAlive。
    // 2. 只有当内容实际可见时（_isContentActuallyVisible 为 true），并且控制器已初始化，
    //    或者它是活动场景（活动场景即使暂时移出屏幕也应保持渲染），才完整构建SceneEditor。
    // 3. 否则，如果未初始化且VisibilityDetector报告不可见，则显示占位符。

    return VisibilityDetector(
      key: ValueKey('vis_det_${widget.sceneId}'), 
      onVisibilityChanged: (visibilityInfo) {
        if (!mounted) return;
        
        // 使用一个较小的阈值，例如5%的可见区域，就认为它是可见的
        final bool newActualVisibility = visibilityInfo.visibleFraction > 0.05;
        
        if (_isContentActuallyVisible != newActualVisibility) {
          if (mounted) {
            setState(() {
              _isContentActuallyVisible = newActualVisibility;
            });
          }
          widget.onVisibilityChanged?.call(_isContentActuallyVisible); 
          AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} [${widget.scene.title}] VisibilityDetector 报告可见性: $_isContentActuallyVisible (Fraction: ${visibilityInfo.visibleFraction.toStringAsFixed(2)})');

          if (_isContentActuallyVisible && !_isInitialized && !_isControllerInitializing) {
            AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 因 VisibilityDetector 变为可见，尝试初始化。');
            _tryInitializeControllers();
          }
          // 如果场景从可见变为不可见，并且父级也认为它不大致可见，并且它不是活动场景，
          // 并且已经初始化，可以考虑在这里执行 _disposeControllers() 释放资源。
          // else if (!_isContentActuallyVisible && !_isParentVisuallyNearby && !widget.isActive && _isInitialized) {
          //   AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 完全不可见，考虑卸载');
          //   _disposeControllers(); // 谨慎：确保 SceneEditor 正确处理 wantKeepAlive = false
          // }
        }
      },
      child: LayoutBuilder( // 使用LayoutBuilder获取约束，可能用于更精细的占位符
        builder: (context, constraints) {
          // 决定是否渲染真实内容或占位符
          // 渲染条件：
          // 1. 控制器已初始化完毕。
          // 2. 或者，场景是当前活动场景（活动场景应始终尝试渲染，即使其控制器仍在初始化）。
          // 3. 或者，VisibilityDetector报告内容实际可见，并且父组件也认为它大致可见（允许在初始化期间显示加载中的SceneEditor）。
          bool shouldRenderSceneEditor = _isInitialized || 
                                         widget.isActive || 
                                         (_isContentActuallyVisible && widget.isParentVisuallyNearby);

          if (shouldRenderSceneEditor) {
            // AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 构建 SceneEditor. isInitialized: $_isInitialized, isActive: ${widget.isActive}, isContentActuallyVisible: $_isContentActuallyVisible, isParentVisuallyNearby: ${widget.isParentVisuallyNearby}');
            String? currentNovelId;
            if (widget.editorBloc.state is editor_bloc.EditorLoaded) {
              currentNovelId = (widget.editorBloc.state as editor_bloc.EditorLoaded).novel.id;
            }

            return SceneEditor(
              key: sceneKey,
              title: widget.scene.title.isNotEmpty ? widget.scene.title : '场景 ${widget.sceneIndex ?? widget.sceneId.hashCode % 100}',
              wordCount: widget.scene.wordCount,
              isActive: widget.isActive,
              actId: widget.actId,
              chapterId: widget.chapterId,
              sceneId: widget.scene.id,
              isFirst: widget.isFirst,
              sceneIndex: widget.sceneIndex,
              controller: _getOrCreateSceneController(), 
              summaryController: _getOrCreateSummaryController(),
              editorBloc: widget.editorBloc,
              // isVisuallyNearby 传递给 SceneEditor 的 wantKeepAlive
              // 如果场景是活动的，或者内容当前在屏幕上，则 SceneEditor 应该尝试保持活动状态。
              isVisuallyNearby: widget.isActive || _isContentActuallyVisible, 
              onContentChanged: (newContent, newWordCount, {syncToServer = false}) {
                if (currentNovelId != null) {
                  widget.editorBloc.add(editor_bloc.UpdateSceneContent(
                    novelId: currentNovelId,
                    actId: widget.actId,
                    chapterId: widget.chapterId,
                    sceneId: widget.sceneId,
                    content: newContent,
                    wordCount: newWordCount.toString(),
                  ));
                } else {
                  AppLogger.w('VirtualizedSceneLoader', '无法更新场景 ${widget.sceneId} 内容，因为 novelId 未知');
                }
              },
            );
          } else {
            // AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 构建占位符.');
            return _buildPlaceholder(
              // 可以根据场景预估高度，或使用固定高度
              // estimatedHeight: widget.scene.content.length / 10, // 粗略估计
            ); 
          }
        },
      ),
    );
  }
  
  Widget _buildPlaceholder({double? estimatedHeight}) {
    // 使用一个更轻量级的占位符，或者基于预估内容高度的占位符
    return Container(
      // height: estimatedHeight?.clamp(50, 300) ?? 100, // 最小50，最大300，默认100
      constraints: const BoxConstraints(minHeight: 50), // 保证一个最小高度
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // color: Colors.grey[200], // 淡色背景
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!)
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.scene.title.isNotEmpty 
                ? widget.scene.title 
                : '场景 ${widget.sceneIndex ?? widget.sceneId.hashCode % 100}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Icon(Icons.hourglass_empty, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }


  /// 获取或创建场景控制器
  QuillController _getOrCreateSceneController() {
    if (widget.sceneControllers.containsKey(widget.sceneId)) {
      return widget.sceneControllers[widget.sceneId]!;
    } else {
      return QuillController(
        document: Document.fromJson([{'insert': '\n'}]),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  /// 获取或创建场景摘要控制器
  TextEditingController _getOrCreateSummaryController() {
    if (widget.sceneSummaryControllers.containsKey(widget.sceneId)) {
      return widget.sceneSummaryControllers[widget.sceneId]!;
    } else {
      return TextEditingController(
        text: '',
      );
    }
  }
} 