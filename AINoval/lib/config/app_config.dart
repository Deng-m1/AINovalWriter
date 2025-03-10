import 'package:flutter/foundation.dart';

/// 应用环境枚举
enum Environment {
  development,
  production,
}

/// 应用配置类
/// 
/// 用于管理应用的环境配置和模拟数据设置
class AppConfig {
  /// 私有构造函数，防止实例化
  AppConfig._();
  
  /// 当前环境
  static Environment _environment = kDebugMode ? Environment.development : Environment.production;
  
  /// 是否强制使用模拟数据（无论环境如何）
  static bool _forceMockData = false;
  
  /// 获取当前环境
  static Environment get environment => _environment;
  
  /// 设置当前环境
  static void setEnvironment(Environment env) {
    _environment = env;
  }
  
  /// 是否应该使用模拟数据
  static bool get shouldUseMockData => _forceMockData || _environment == Environment.development;
  
  /// 强制使用/不使用模拟数据
  static void setUseMockData(bool useMock) {
    _forceMockData = useMock;
  }
  
  /// API基础URL
  static String get apiBaseUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://localhost:8080/api';
      case Environment.production:
        return 'https://api.ainoval.com/api';
    }
  }
  
  /// 日志级别
  static LogLevel get logLevel {
    switch (_environment) {
      case Environment.development:
        return LogLevel.debug;
      case Environment.production:
        return LogLevel.error;
    }
  }
}

/// 日志级别枚举
enum LogLevel {
  debug,   // 调试信息
  info,    // 一般信息
  warning, // 警告信息
  error,   // 错误信息
} 