import 'package:intl/intl.dart';

class DateFormatter {
  // 格式化为相对时间（如：昨天、2小时前等）
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (date.year == now.year) {
      return DateFormat('MM月dd日').format(date);
    } else {
      return DateFormat('yyyy年MM月dd日').format(date);
    }
  }
  
  // 格式化为月份字符串（用于分组显示）
  static String formatMonth(DateTime date) {
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month) {
      return '本月';
    } else if (date.year == now.year && date.month == now.month - 1) {
      return '上个月';
    } else if (date.year == now.year) {
      return DateFormat('MM月').format(date);
    } else {
      return DateFormat('yyyy年MM月').format(date);
    }
  }
  
  // 格式化为完整日期时间
  static String formatFull(DateTime date) {
    return DateFormat('yyyy年MM月dd日 HH:mm').format(date);
  }
} 