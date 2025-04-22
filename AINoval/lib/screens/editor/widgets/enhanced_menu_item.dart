import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 增强版的菜单项组件
/// 
/// 支持快捷键、徽章、自定义颜色等高级功能
class EnhancedMenuItem extends StatelessWidget {
  /// 图标
  final IconData icon;
  
  /// 标签文本
  final String label;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 是否有子菜单
  final bool hasSubmenu;
  
  /// 是否禁用
  final bool disabled;
  
  /// 是否为危险操作
  final bool isDangerous;
  
  /// 是否为暗色主题
  final bool isDarkTheme;
  
  /// 徽章文本
  final String? badge;
  
  /// 快捷键文本
  final String? shortcutText;
  
  /// 快捷键组合
  final List<LogicalKeyboardKey>? shortcutKeys;
  
  /// 子菜单构建器
  final WidgetBuilder? submenuBuilder;
  
  /// 是否显示为选中状态
  final bool isSelected;
  
  /// 自定义图标颜色
  final Color? iconColor;
  
  /// 自定义文本颜色
  final Color? textColor;

  const EnhancedMenuItem({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
    this.hasSubmenu = false,
    this.disabled = false,
    this.isDangerous = false,
    this.isDarkTheme = false,
    this.badge,
    this.shortcutText,
    this.shortcutKeys,
    this.submenuBuilder,
    this.isSelected = false,
    this.iconColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 计算颜色
    final effectiveIconColor = _getEffectiveIconColor(context);
    final effectiveTextColor = _getEffectiveTextColor(context);
    
    return InkWell(
      onTap: disabled ? null : () {
        // 查找并关闭所有打开的overlay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
        
        // 执行点击回调
        if (onTap != null) onTap!();
      },
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDarkTheme ? Colors.white12 : Colors.grey.shade100) 
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // 图标
              Icon(
                icon, 
                size: 20, 
                color: effectiveIconColor,
              ),
              const SizedBox(width: 12),
              
              // 主要文本
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: effectiveTextColor,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              
              // 徽章
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.white24 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkTheme ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                
              // 快捷键文本
              if (shortcutText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    shortcutText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkTheme ? Colors.white38 : Colors.grey.shade600,
                    ),
                  ),
                ),
                
              // 子菜单图标
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
  
  /// 获取有效的图标颜色
  Color _getEffectiveIconColor(BuildContext context) {
    if (disabled) {
      return isDarkTheme ? Colors.white38 : Colors.black38;
    }
    
    if (iconColor != null) {
      return iconColor!;
    }
    
    if (isDangerous) {
      return Colors.red.shade700;
    }
    
    if (isSelected) {
      return isDarkTheme 
          ? Colors.white 
          : Theme.of(context).primaryColor;
    }
    
    return isDarkTheme ? Colors.white70 : Colors.black87;
  }
  
  /// 获取有效的文本颜色
  Color _getEffectiveTextColor(BuildContext context) {
    if (disabled) {
      return isDarkTheme ? Colors.white38 : Colors.black38;
    }
    
    if (textColor != null) {
      return textColor!;
    }
    
    if (isDangerous) {
      return Colors.red.shade700;
    }
    
    if (isSelected) {
      return isDarkTheme 
          ? Colors.white 
          : Theme.of(context).primaryColor;
    }
    
    return isDarkTheme ? Colors.white : Colors.black87;
  }
}

/// 增强版的菜单分区
class EnhancedMenuSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final bool isDarkTheme;
  final bool dividerAtBottom;
  final Color? titleColor;

  const EnhancedMenuSection({
    Key? key,
    this.title,
    required this.children,
    this.isDarkTheme = false,
    this.dividerAtBottom = true,
    this.titleColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTitleColor = titleColor ?? 
        (isDarkTheme ? Colors.white54 : Colors.black54);
        
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
                color: effectiveTitleColor,
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