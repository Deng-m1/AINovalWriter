import 'dart:ui';
import 'package:flutter/material.dart';

/// 全屏加载动画覆盖层
/// 在应用初始化、卷轴切换等耗时操作时显示
class FullscreenLoadingOverlay extends StatelessWidget {
  final String loadingMessage;
  final bool showProgressIndicator;
  final double progress; // 0.0 - 1.0 的进度值，如果提供将显示进度条而非无限循环指示器
  final Color backgroundColor;
  final Color textColor;
  final bool useBlur; // 是否使用背景模糊效果
  final bool isVisible;

  const FullscreenLoadingOverlay({
    Key? key,
    this.loadingMessage = '正在加载，请稍候...',
    this.showProgressIndicator = true,
    this.progress = -1, // 默认为-1，表示不确定进度
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black87,
    this.useBlur = false,
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          // 使用纯白色背景代替模糊效果
          color: Colors.white,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showProgressIndicator)
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.primaryColor,
                      ),
                    ),
                  ),
                if (showProgressIndicator && (loadingMessage != null || progress > 0))
                  const SizedBox(height: 30),
                if (loadingMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      loadingMessage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (progress > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildProgressIndicator(theme),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建进度指示器
  Widget _buildProgressIndicator(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.primaryColor,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
} 