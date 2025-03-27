import 'package:ainoval/utils/logger.dart';

/// 解析来自后端的多种日期时间格式 (String, List, double, int)
///
/// 支持:
/// - ISO 8601 字符串 (e.g., "2024-07-30T10:00:00Z")
/// - Java LocalDateTime 数组格式 [year, month, day, hour, minute, second, nanoOfSecond]
/// - Unix 时间戳 (秒, double 类型)
/// - Unix 时间戳 (毫秒, int 类型)
DateTime parseBackendDateTime(dynamic dateTimeValue) {
  if (dateTimeValue == null) {
    AppLogger.w('DateTimeParser', '接收到 null 日期时间值，返回当前时间');
    return DateTime.now();
  }

  if (dateTimeValue is String) {
    // 如果是字符串格式，直接解析
    try {
      return DateTime.parse(dateTimeValue);
    } catch (e) {
      AppLogger.e('DateTimeParser', '解析日期时间字符串失败, 值: "$dateTimeValue"', e);
      return DateTime.now(); // 解析失败时返回当前时间
    }
  } else if (dateTimeValue is List) {
    // 如果是Java LocalDateTime数组格式 [year, month, day, hour, minute, second, nanoOfSecond]
    try {
      // 确保列表元素足够，并进行安全转换
      final year = dateTimeValue.isNotEmpty ? (dateTimeValue[0] as num).toInt() : DateTime.now().year;
      final month = dateTimeValue.length > 1 ? (dateTimeValue[1] as num).toInt() : 1;
      final day = dateTimeValue.length > 2 ? (dateTimeValue[2] as num).toInt() : 1;
      final hour = dateTimeValue.length > 3 ? (dateTimeValue[3] as num).toInt() : 0;
      final minute = dateTimeValue.length > 4 ? (dateTimeValue[4] as num).toInt() : 0;
      final second = dateTimeValue.length > 5 ? (dateTimeValue[5] as num).toInt() : 0;
      // 可选：处理纳秒，转换为毫秒和微秒
      final nanoOfSecond = dateTimeValue.length > 6 ? (dateTimeValue[6] as num).toInt() : 0;
      final millisecond = nanoOfSecond ~/ 1000000;
      final microsecond = (nanoOfSecond % 1000000) ~/ 1000;

      return DateTime(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
        microsecond,
      );
    } catch (e) {
      AppLogger.e('DateTimeParser', '解析LocalDateTime数组失败, 值: $dateTimeValue', e);
      return DateTime.now(); // 解析失败时返回当前时间
    }
  } else if (dateTimeValue is double) {
    // 如果是Instant格式的时间戳（秒为单位）
    try {
      // 将秒转换为毫秒
      final milliseconds = (dateTimeValue * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: false); // 假设后端时间戳是本地时间，如果确定是UTC，改为true
    } catch (e) {
      AppLogger.e('DateTimeParser', '解析Instant时间戳(double)失败, 值: $dateTimeValue', e);
      return DateTime.now();
    }
  } else if (dateTimeValue is int) {
    // 假设是毫秒时间戳
    try {
      // 检查时间戳范围，区分秒和毫秒 (一个简单的启发式方法)
      if (dateTimeValue > 3000000000) { // 大约到 2065 年的毫秒数
         return DateTime.fromMillisecondsSinceEpoch(dateTimeValue, isUtc: false); // 假设是毫秒
      } else {
         return DateTime.fromMillisecondsSinceEpoch(dateTimeValue * 1000, isUtc: false); // 假设是秒
      }
    } catch (e) {
      AppLogger.e('DateTimeParser', '解析时间戳(int)失败, 值: $dateTimeValue', e);
      return DateTime.now();
    }
  } else {
    // 其他未知情况返回当前时间
    AppLogger.w('DateTimeParser', '未知的日期时间格式: $dateTimeValue (${dateTimeValue.runtimeType})');
    return DateTime.now();
  }
} 