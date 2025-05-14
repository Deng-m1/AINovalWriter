import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用下拉菜单组件，用于替换项目中的三点水下拉菜单
class CustomDropdown extends StatefulWidget {
  /// 触发下拉菜单的小部件
  final Widget trigger;
  
  /// 下拉菜单内容
  final Widget child;
  
  /// 下拉菜单宽度
  final double width;
  
  /// 下拉菜单对齐方式 ('left' 或 'right')
  final String align;
  
  /// 是否为暗色主题
  final bool isDarkTheme;

  /// 菜单出现/消失的动画时长
  final Duration animationDuration;

  const CustomDropdown({
    Key? key,
    required this.trigger,
    required this.child,
    this.width = 240,
    this.align = 'left',
    this.isDarkTheme = false,
    this.animationDuration = const Duration(milliseconds: 150),
  }) : super(key: key);

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  bool isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && isOpen) {
      _closeDropdown();
    }
  }

  void _toggleDropdown() {
    if (isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _closeDropdown() {
    _removeOverlay();
    setState(() {
      isOpen = false;
    });
  }

  void _openDropdown() {
    _showOverlay();
    setState(() {
      isOpen = true;
    });
    _focusNode.requestFocus();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeDropdown,
        child: Stack(
          children: [
            Positioned(
              left: widget.align == 'left' ? offset.dx : null,
              right: widget.align == 'right' ? (MediaQuery.of(context).size.width - offset.dx - size.width) : null,
              top: offset.dy + size.height + 4,
              width: widget.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                followerAnchor: widget.align == 'left' ? Alignment.topLeft : Alignment.topRight,
                targetAnchor: widget.align == 'left' ? Alignment.bottomLeft : Alignment.bottomRight,
                offset: const Offset(0, 4),
                child: TweenAnimationBuilder<double>(
                  duration: widget.animationDuration,
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, value, child) => Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    alignment: widget.align == 'left' 
                      ? Alignment.topLeft 
                      : Alignment.topRight,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  ),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: widget.isDarkTheme ? Colors.grey[850] : Colors.white,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (keyEvent) {
        if (keyEvent is KeyDownEvent && keyEvent.logicalKey == LogicalKeyboardKey.escape) {
          _closeDropdown();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: widget.trigger,
        ),
      ),
    );
  }
}

/// 下拉菜单项
class DropdownItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;
  final bool hasSubmenu;
  final bool disabled;
  final bool isDarkTheme;
  final bool isDangerous;

  const DropdownItem({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
    this.hasSubmenu = false,
    this.disabled = false,
    this.isDarkTheme = false,
    this.isDangerous = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : () async {
        if (onTap != null) {
          await onTap!();
        }

        if (context.mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      },
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon, 
                size: 20, 
                color: isDangerous 
                  ? Colors.red.shade700
                  : (isDarkTheme ? Colors.white70 : Colors.black87)
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDangerous
                      ? Colors.red.shade700
                      : (isDarkTheme ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              if (hasSubmenu)
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDarkTheme ? Colors.white38 : Colors.black45,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 下拉菜单分区
class DropdownSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final bool isDarkTheme;
  final bool dividerAtBottom;

  const DropdownSection({
    Key? key,
    this.title,
    required this.children,
    this.isDarkTheme = false,
    this.dividerAtBottom = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDarkTheme ? Colors.white54 : Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ...children,
        if (dividerAtBottom) 
          Divider(
            height: 8, 
            thickness: 1,
            color: isDarkTheme ? Colors.white12 : Colors.black12,
          ),
      ],
    );
  }
}

/// 下拉菜单分隔线
class DropdownDivider extends StatelessWidget {
  final bool isDarkTheme;
  
  const DropdownDivider({
    Key? key,
    this.isDarkTheme = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 8, 
      thickness: 1,
      color: isDarkTheme ? Colors.white12 : Colors.black12,
    );
  }
} 