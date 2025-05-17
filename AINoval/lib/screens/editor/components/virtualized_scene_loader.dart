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

  @override
  State<VirtualizedSceneLoader> createState() => _VirtualizedSceneLoaderState();
}

class _VirtualizedSceneLoaderState extends State<VirtualizedSceneLoader> {
  /// 标记场景是否已初始化
  bool _isInitialized = false;
  
  /// 标记场景控制器是否正在初始化过程中
  bool _isControllerInitializing = false; // 添加标志避免重复初始化
  bool _isDetectedVisible = false; // 新的状态，由 VisibilityDetector驱动

  @override
  void initState() {
    super.initState();
    
    // 如果是活动场景或已标记为可见，立即初始化
    if (widget.isActive) {
      _tryInitializeControllers();
    }
  }
  
  @override
  void didUpdateWidget(VirtualizedSceneLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当状态发生变化时初始化控制器
    if (!_isInitialized && !_isControllerInitializing) {
      // 优先检查活动状态变化，这是最重要的
      if (widget.isActive && !oldWidget.isActive) {
        AppLogger.i('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为活动状态，立即初始化');
        _tryInitializeControllers();
      } 
      // 其次检查可见性变化
      else if (widget.isActive && !oldWidget.isActive && _isDetectedVisible && _isInitialized && mounted) {
        setState(() {
          AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 激活且可见，刷新');
        });
      }
    }
    
    // 当可见性状态变化时，通知父组件
    if (widget.isActive != oldWidget.isActive) {
      widget.onVisibilityChanged?.call(widget.isActive);
    }
    
    // 如果场景变为活动状态，但之前不是活动状态，强制刷新UI
    if (widget.isActive && !oldWidget.isActive && _isInitialized) {
      setState(() {
        AppLogger.i('VirtualizedSceneLoader', '场景 ${widget.sceneId} 变为活动状态，刷新UI');
      });
    }
  }
  
  /// 初始化场景编辑器控制器
  /// 
  /// 使用计算隔离或同步初始化文档，
  /// 确保不会阻塞UI线程并处理可能的错误情况
  void _tryInitializeControllers() {
    if (_isInitialized || _isControllerInitializing) return;
    
    _isControllerInitializing = true; // 设置标志防止重复初始化
    
    try {
      // 使用隔离初始化以避免主线程阻塞
      compute<String, Document>(DocumentParser.parseDocumentInIsolate, widget.scene.content)
        .then((document) {
          if (mounted) {
            widget.sceneControllers[widget.sceneId] = QuillController(
              document: document,
              selection: const TextSelection.collapsed(offset: 0),
            );
            
            widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
              text: widget.scene.summary.content,
            );
            
            // 确保更新状态以反映控制器已初始化
            setState(() {
              _isInitialized = true;
              _isControllerInitializing = false;
              AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 控制器初始化完成');
            });
          } else {
            _isControllerInitializing = false;
          }
        })
        .catchError((e) {
          AppLogger.e('VirtualizedSceneLoader', 
              '通过隔离初始化文档失败: ${widget.sceneId}', e);
          
          // 回退到同步初始化
          if (mounted) {
            widget.sceneControllers[widget.sceneId] = QuillController(
              document: widget.parseDocumentSafely(widget.scene.content),
              selection: const TextSelection.collapsed(offset: 0),
            );
            
            widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
              text: widget.scene.summary.content,
            );
            
            setState(() {
              _isInitialized = true;
              _isControllerInitializing = false;
              AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 控制器同步初始化完成');
            });
          } else {
            _isControllerInitializing = false;
          }
        });
    } catch (e) {
      AppLogger.e('VirtualizedSceneLoader', 
          '创建场景控制器失败: ${widget.sceneId}', e);
      
      if (mounted) {
        widget.sceneControllers[widget.sceneId] = QuillController(
          document: Document.fromJson([{'insert': '\n'}]),
          selection: const TextSelection.collapsed(offset: 0),
        );
        
        widget.sceneSummaryControllers[widget.sceneId] = TextEditingController(
          text: '',
        );
        
        setState(() {
          _isInitialized = true;
          _isControllerInitializing = false;
        });
      } else {
        _isControllerInitializing = false;
      }
    }
    
    // 确保有GlobalKey
    if (!widget.sceneKeys.containsKey(widget.sceneId)) {
      widget.sceneKeys[widget.sceneId] = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取控制器，如果尚未初始化，这些可能是临时的空控制器
    // _tryInitializeControllers 会在后台更新 Map 中的实例
    final sceneController = _getOrCreateSceneController();
    final summaryController = _getOrCreateSummaryController();

    return VisibilityDetector(
      key: ValueKey('vis_det_${widget.sceneId}'), // 确保key唯一
      onVisibilityChanged: (visibilityInfo) {
        if (!mounted) return;
        final newVisibility = visibilityInfo.visibleFraction > 0.05; // 可见百分比阈值
        
        if (_isDetectedVisible != newVisibility) {
          setState(() {
            _isDetectedVisible = newVisibility;
          });
          widget.onVisibilityChanged?.call(_isDetectedVisible); // 通知父组件
          
          AppLogger.d('VirtualizedSceneLoader', '场景 ${widget.sceneId} 可见性改变: $_isDetectedVisible');

          if (_isDetectedVisible && !_isInitialized && !_isControllerInitializing) {
            _tryInitializeControllers(); // 当场景变得可见时，尝试初始化
          }
        }
      },
      child: Builder( // 使用Builder确保在VisibilityDetector回调之后访问状态
        builder: (context) {
          // 基于 _isDetectedVisible 和 _isInitialized 来决定渲染真实内容还是占位符
          if (!_isInitialized && !_isDetectedVisible && !widget.isActive) {
            // 如果未初始化，且探测器认为不可见，且非活动场景，则显示占位符或SizedBox.shrink()
            // 保持一个最小高度的占位符可能对滚动平滑性更好
            return _buildPlaceholder(); // 或者 SizedBox.shrink();
          }

          // 如果已初始化，或者虽然未初始化但探测器认为是可见的（即将初始化），或者场景是活动的
          // 则构建SceneEditor
          // 传递 _isDetectedVisible 给 SceneEditor 的 isVisuallyNearby
          return SceneEditor(
            key: widget.sceneKeys[widget.sceneId] ?? GlobalKey(), // 确保key存在
            title: widget.scene.title.isNotEmpty ? widget.scene.title : '场景',
            wordCount: widget.scene.wordCount,
            isActive: widget.isActive,
            actId: widget.actId,
            chapterId: widget.chapterId,
            sceneId: widget.scene.id,
            isFirst: widget.isFirst,
            sceneIndex: widget.sceneIndex,
            controller: sceneController, // 这些控制器会被后台的 _tryInitializeControllers 更新
            summaryController: summaryController,
            editorBloc: widget.editorBloc,
            isVisuallyNearby: _isDetectedVisible || widget.isActive, // 或者仅 _isDetectedVisible
            onContentChanged: (content, wordCount, {syncToServer = false}) {
              // ...
            },
          );
        },
      ),
    );
  }
  
  /// 构建场景占位符
  /// 
  /// 在场景控制器初始化前显示，保持布局稳定性
  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scene ${widget.scene.id.hashCode % 100 + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.scene.wordCount} 字',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 判断场景是否属于跨卷（与当前活动场景不在同一卷）
  /// 
  /// 跨卷场景使用延迟加载策略，减轻一次性加载大量场景的压力
  bool _isCrossActFromActiveScene() {
    // 提取当前场景的Act ID
    final parts = widget.sceneId.split('_');
    if (parts.length < 3) return false;
    final currentActId = parts[0];
    
    // 获取活动场景信息
    final state = widget.editorBloc.state;
    if (state is editor_bloc.EditorLoaded && state.activeActId != null) {
      // 如果活动Act ID与当前场景Act ID不同，则是跨卷场景
      return state.activeActId != currentActId;
    }
    
    return false;
  }
  
  /// 为跨卷场景计算延迟时间，避免同时初始化太多控制器
  /// 
  /// 使用场景ID计算一个伪随机的延迟时间，确保加载分散
  Duration _calculateDelayForCrossActScene() {
    // 提取场景ID中的相关信息，用于计算随机延迟
    final parts = widget.sceneId.split('_');
    if (parts.length < 3) return const Duration(milliseconds: 100);
    
    // 使用场景ID的哈希值计算一个伪随机的延迟时间
    final hash = widget.sceneId.hashCode.abs();
    final baseDelay = 200; // 基础延迟200毫秒
    final randomAddition = hash % 800; // 0-800毫秒的随机附加延迟
    
    return Duration(milliseconds: baseDelay + randomAddition);
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