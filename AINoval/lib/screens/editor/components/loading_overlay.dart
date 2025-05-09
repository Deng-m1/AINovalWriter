/**
 * 加载覆盖层组件
 * 
 * 在内容加载过程中显示的半透明渐变覆盖层，提供直观的加载状态反馈。
 * 显示在屏幕底部，包含加载指示器和自定义加载消息。
 */
import 'package:flutter/material.dart';

/// 加载覆盖层组件
/// 
/// 用于在编辑器中显示内容加载状态。
/// 设计为一个半透明的覆盖层，显示在主界面底部，
/// 具有渐变背景和居中的指示器加消息。
class LoadingOverlay extends StatelessWidget {
  /// 要显示的加载消息文本
  final String loadingMessage;
  
  /// 创建一个加载覆盖层
  /// 
  /// [loadingMessage] 要显示的加载消息
  const LoadingOverlay({
    Key? key,
    required this.loadingMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 80,
        // 渐变背景从透明到白色
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.8),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            // 消息容器的样式，圆角白色卡片带阴影
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 加载指示器
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                // 加载消息文本
                Text(
                  loadingMessage,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 