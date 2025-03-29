import 'dart:math' show sin;

import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // 与消息气泡垂直间距一致
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 头像占位符
          Icon(
            Icons.smart_toy_outlined,
            color: colorScheme.secondary,
            size: 28,
          ),
          const SizedBox(width: 8),

          // 指示器气泡
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14.0, vertical: 12.0), // 内边距调整
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer, // 与 AI 气泡背景一致
              // 圆角与 AI 气泡一致
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
                bottomLeft: Radius.circular(4.0), // 左下小圆角
                bottomRight: Radius.circular(16.0), // 右下圆角
              ),
              border: Border.all(
                // 细微边框
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // 使用 List.generate
                    // 调整动画，使其更平滑
                    final double value =
                        _controller.value * 2.0 * 3.14159; // 完整周期
                    final double offset = i * 3.14159 / 3.0; // 相位偏移
                    // 使用正弦函数创建上下浮动效果
                    final double yOffset = sin(value - offset) * 2.0; // 调整浮动幅度

                    return Transform.translate(
                      offset: Offset(0, yOffset),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 3), // 点间距
                        child: CircleAvatar(
                          radius: 4, // 点大小
                          // 使用更柔和的颜色
                          backgroundColor:
                              colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
