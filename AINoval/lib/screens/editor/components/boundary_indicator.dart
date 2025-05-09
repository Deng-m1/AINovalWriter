/**
 * 边界指示器组件
 * 
 * 用于在内容的顶部或底部显示边界提示信息，
 * 告知用户已经到达内容的边界，没有更多内容可以加载。
 */
import 'package:flutter/material.dart';

/// 内容边界指示器组件
/// 
/// 在列表或滚动视图的顶部或底部显示一个提示文本，
/// 用于告知用户已达到内容边界（顶部或底部），没有更多内容可加载。
class BoundaryIndicator extends StatelessWidget {
  /// 是否显示在顶部边界
  /// 
  /// 如果为true，则显示顶部边界提示；
  /// 如果为false，则显示底部边界提示。
  final bool isTop;
  
  /// 创建一个边界指示器
  /// 
  /// [isTop] 指定是顶部边界还是底部边界
  const BoundaryIndicator({
    Key? key,
    required this.isTop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: Text(
          // 根据位置显示不同的提示文本
          isTop ? '已到达顶部，没有更多内容' : '已到达底部，没有更多内容',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
} 