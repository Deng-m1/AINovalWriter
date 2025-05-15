import 'package:flutter/material.dart';
import 'package:ainoval/blocs/editor/editor_bloc.dart' as editor_bloc;
import 'package:ainoval/utils/logger.dart';

/// 卷轴导航按钮组件
/// 显示上一卷/下一卷/添加新卷按钮
class VolumeNavigationButtons extends StatelessWidget {
  // 位置控制
  final bool isTop;
  
  // 卷状态控制
  final bool isFirstAct;
  final bool isLastAct;
  final String? previousActTitle;
  final String? nextActTitle;
  
  // 滚动状态
  final bool hasReachedStart;
  final bool hasReachedEnd;
  
  // 加载状态
  final bool isLoadingMore;
  
  // 回调
  final VoidCallback? onPreviousAct;
  final VoidCallback? onNextAct;
  final VoidCallback? onAddNewAct;
  
  const VolumeNavigationButtons({
    Key? key,
    required this.isTop,
    required this.isFirstAct,
    required this.isLastAct,
    this.previousActTitle,
    this.nextActTitle,
    required this.hasReachedStart,
    required this.hasReachedEnd,
    this.isLoadingMore = false,
    this.onPreviousAct,
    this.onNextAct,
    this.onAddNewAct,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 始终记录底部按钮显示条件，方便调试
    if (!isTop) {
      AppLogger.i('VolumeNavigationButtons', '底部按钮条件: isLastAct=$isLastAct, hasReachedEnd=$hasReachedEnd');
    }
    
    // 上方按钮显示条件：
    // 1. 是顶部按钮位置 (isTop)
    // 2. 不能是第一卷 (isFirstAct == false)
    final bool shouldShowTopButton = isTop && !isFirstAct;
    
    // 下方按钮显示条件：
    // 1. 是底部按钮位置
    final bool shouldShowBottomButton = !isTop;
    
    // 确定按钮类型
    // 顶部按钮永远是"上一卷"
    // 底部按钮在最后一卷时是"添加新卷"，否则是"下一卷"
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, isTop ? -0.5 : 0.5),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: (shouldShowTopButton || shouldShowBottomButton)
          ? _buildButton(
              context,
              isTop: isTop,
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required bool isTop,
  }) {
    final themeData = Theme.of(context);
    
    // 安全地获取前一个和下一个卷的信息
    final String? prevVolumeName = isFirstAct ? null : previousActTitle;
    final String? nextVolumeName = this.isLastAct ? null : this.nextActTitle;
    
    // 按钮文本
    late final String buttonText;
    late final IconData buttonIcon;
    late final VoidCallback? onPressed;
    
    if (isTop) {
      // 顶部按钮：上一卷
      if (prevVolumeName == null) {
        buttonText = '返回首卷';
      } else {
        String displayName = prevVolumeName;
        if (displayName.length > 10) {
          displayName = displayName.substring(0, 10) + '...';
        }
        buttonText = '上一卷：$displayName';
      }
      buttonIcon = Icons.arrow_upward_rounded;
      onPressed = onPreviousAct;
    } else {
      if (this.isLastAct) {
        // 底部按钮：如果是最后一卷，则为"添加新卷"
        buttonText = '添加新卷';
        buttonIcon = Icons.add_rounded;
        onPressed = onAddNewAct;
      } else {
        // 底部按钮：如果不是最后一卷，则为"下一卷"
        if (nextVolumeName == null) {
          buttonText = '下一卷';
        } else {
          String displayName = nextVolumeName;
          if (displayName.length > 10) {
            displayName = displayName.substring(0, 10) + '...';
          }
          buttonText = '下一卷：$displayName';
        }
        buttonIcon = Icons.arrow_downward_rounded;
        onPressed = onNextAct;
      }
    }
    
    // 构建按钮
    return Padding(
      padding: EdgeInsets.only(
        top: isTop ? 16.0 : 0.0,
        bottom: isTop ? 0.0 : 16.0,
      ),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: themeData.cardColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: isLoadingMore ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isLoadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          buttonIcon,
                          color: themeData.colorScheme.primary,
                        ),
                  const SizedBox(width: 8),
                  Text(
                    isLoadingMore ? '加载中...' : buttonText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: themeData.colorScheme.onSurface,
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

  // 构建加载指示器
  Widget _buildLoadingIndicator(ThemeData theme, String loadingText) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          loadingText,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 