import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

/// 日志级别
enum LogLevel {
  verbose,  // 详细信息
  debug,    // 调试信息
  info,     // 普通信息
  warning,  // 警告信息
  error,    // 错误信息
  wtf       // 严重错误
}

/// 应用程序日志管理类
class AppLogger {
  static bool _initialized = false;
  static final Map<String, Logger> _loggers = {};
  
  // 日志级别与Logging包级别的映射
  static final Map<LogLevel, Level> _levelMap = {
    LogLevel.verbose: Level.FINEST,
    LogLevel.debug: Level.FINE,
    LogLevel.info: Level.INFO,
    LogLevel.warning: Level.WARNING,
    LogLevel.error: Level.SEVERE,
    LogLevel.wtf: Level.SHOUT,
  };
  
  /// 初始化日志系统
  static void init() {
    if (_initialized) return;
    
    hierarchicalLoggingEnabled = true;
    
    // 在调试模式下显示所有日志，在生产模式下只显示INFO级别以上
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    
    // 配置日志监听器
    Logger.root.onRecord.listen((record) {
      // 根据环境选择合适的格式
      final emoji = _getLogEmoji(record.level);
      final timestamp = DateTime.now().toString().substring(0, 19);
      final message = '[${record.loggerName}] $emoji ${record.message}';
      
      if (record.error != null) {
        debugPrint('$timestamp $message\n错误: ${record.error}');
        if (record.stackTrace != null) {
          debugPrint('堆栈: ${record.stackTrace}');
        }
      } else {
        debugPrint('$timestamp $message');
      }
    });
    
    _initialized = true;
  }
  
  /// 获取指定模块的日志记录器
  static Logger getLogger(String name) {
    if (!_initialized) init();
    
    return _loggers.putIfAbsent(name, () {
      final logger = Logger(name);
      logger.level = Logger.root.level;
      return logger;
    });
  }
  
  /// 记录详细日志
  static void v(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(tag, LogLevel.verbose, message, error, stackTrace);
  }
  
  /// 记录调试日志
  static void d(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(tag, LogLevel.debug, message, error, stackTrace);
  }
  
  /// 记录信息日志
  static void i(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(tag, LogLevel.info, message, error, stackTrace);
  }
  
  /// 记录警告日志
  static void w(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(tag, LogLevel.warning, message, error, stackTrace);
  }
  
  /// 记录错误日志
  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(tag, LogLevel.error, message, error, stackTrace);
  }
  
  /// 记录严重错误日志
  static void wtf(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(tag, LogLevel.wtf, message, error, stackTrace);
  }
  
  /// 内部日志记录方法
  static void _log(String tag, LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    final logger = getLogger(tag);
    final logLevel = _levelMap[level]!;
    
    logger.log(logLevel, message, error, stackTrace);
  }
  
  /// 获取日志级别对应的emoji
  static String _getLogEmoji(Level level) {
    if (level == Level.FINEST || level == Level.FINER || level == Level.FINE) return '🔍'; // 调试
    if (level == Level.CONFIG || level == Level.INFO) return '📘'; // 信息
    if (level == Level.WARNING) return '⚠️'; // 警告
    if (level == Level.SEVERE) return '❌'; // 错误
    if (level == Level.SHOUT) return '💥'; // 严重错误
    return '📝'; // 默认
  }
} 