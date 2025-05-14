/**
 * 添加新卷按钮组件
 * 
 * 用于显示一个可点击的"添加新卷"按钮，用户点击后会触发创建新卷的逻辑。
 * 包含加载状态反馈和防抖功能，避免短时间内重复点击触发多次创建操作。
 */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/screens/editor/controllers/editor_screen_controller.dart';

/// 添加新卷按钮组件
/// 
/// 在编辑器中用于添加新卷时使用的按钮组件，包含点击反馈和加载态。
/// 使用Provider模式调用EditorScreenController中的创建方法。
class AddActButton extends StatefulWidget {
  /// 创建一个添加新卷按钮
  const AddActButton({Key? key}) : super(key: key);

  @override
  State<AddActButton> createState() => _AddActButtonState();
}

class _AddActButtonState extends State<AddActButton> {
  /// 标记是否正在添加中，用于显示加载状态
  bool _isAdding = false;
  
  /// 记录上次点击时间，用于防抖
  DateTime? _lastAddTime;
  
  /// 防抖时间间隔（2秒）
  static const Duration _debounceInterval = Duration(seconds: 2);

  /// 添加新卷的处理方法
  /// 
  /// 包含防抖和错误处理逻辑，避免短时间内多次触发
  void _addNewAct() {
    // 防止频繁点击导致重复添加
    final now = DateTime.now();
    if (_isAdding || (_lastAddTime != null && 
        now.difference(_lastAddTime!) < _debounceInterval)) {
      // 如果正在添加中或最后添加时间在2秒内，忽略此次点击
      AppLogger.i('AddActButton', '忽略重复点击: 正在添加=${_isAdding}, 距上次点击=${_lastAddTime != null ? now.difference(_lastAddTime!).inMilliseconds : "首次点击"}ms');
      
      // 显示提示（仅在UI上）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('操作正在处理中，请稍候...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    
    // 记录当前时间并标记为添加中
    _lastAddTime = now;
    setState(() {
      _isAdding = true;
    });
    
    AppLogger.i('AddActButton', '触发EditorScreenController的createNewAct方法');
    // 使用EditorScreenController创建新卷及章节
    Provider.of<EditorScreenController>(context, listen: false).createNewAct().then((_) {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }).catchError((error) {
       AppLogger.e('AddActButton', '调用createNewAct失败', error);
       if (mounted) {
        setState(() {
          _isAdding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: ${error.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: OutlinedButton.icon(
          onPressed: _isAdding ? null : _addNewAct, // 如果正在添加中，禁用按钮
          icon: _isAdding 
              // 添加中状态显示加载指示器
              ? SizedBox(
                  width: 18, 
                  height: 18, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                )
              // 常规状态显示加号图标
              : const Icon(Icons.add, size: 18),
          label: Text(_isAdding ? '添加中...' : '添加新卷'),
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