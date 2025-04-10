import 'package:flutter/material.dart';

/// 可拖拽的分隔条组件
class DraggableDivider extends StatefulWidget {
  const DraggableDivider({
    super.key,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;

  @override
  State<DraggableDivider> createState() => _DraggableDividerState();
}

class _DraggableDividerState extends State<DraggableDivider> {
  bool _isDragging = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (details) {
          setState(() {
            _isDragging = false;
          });
          widget.onDragEnd(details);
        },
        child: Container(
          width: 8,
          height: double.infinity,
          color: _isDragging
              ? theme.colorScheme.primary.withOpacity(0.1)
              : _isHovering
                  ? Colors.grey.shade200
                  : Colors.grey.shade100,
          child: Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: _isDragging
                  ? theme.colorScheme.primary
                  : _isHovering
                      ? Colors.grey.shade400
                      : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }
}
