import 'package:ainoval/utils/logger.dart';

/// 本文件提供了如何使用AppLogger替换print语句的示例
/// 在项目中替换print语句时，可参考本文件中的示例

class LoggerUsageExamples {
  // 简单的信息日志
  void simpleInfoLog() {
    // 旧方式: 
    // print('这是一个信息');
    
    // 新方式:
    AppLogger.i('TagName', '这是一个信息');
  }
  
  // 带异常的错误日志
  void errorWithException() {
    try {
      // 一些可能引发异常的代码
      throw Exception('测试异常');
    } catch (e, stackTrace) {
      // 旧方式:
      // print('操作失败: $e');
      
      // 新方式:
      AppLogger.e('TagName', '操作失败', e, stackTrace);
    }
  }
  
  // 不同级别的日志示例
  void differentLogLevels() {
    // 详细级别(开发调试)
    AppLogger.v('TagName', '详细信息，仅用于调试');
    
    // 调试级别
    AppLogger.d('TagName', '调试信息');
    
    // 信息级别(一般日志)
    AppLogger.i('TagName', '普通信息');
    
    // 警告级别
    AppLogger.w('TagName', '警告信息');
    
    // 错误级别
    AppLogger.e('TagName', '错误信息');
    
    // 严重错误级别
    AppLogger.wtf('TagName', '严重错误信息');
  }
  
  // 特定业务模块的日志示例
  void businessModuleLogs() {
    // 用户行为日志
    AppLogger.i('UserAction', '用户点击了登录按钮');
    
    // 网络请求日志
    AppLogger.d('Network', '开始发送请求: GET /api/novels');
    AppLogger.i('Network', '请求完成，接收到200状态码');
    
    // 同步服务日志
    try {
      // 同步操作
      throw Exception('网络连接中断');
    } catch (e) {
      // 旧方式:
      // print('同步失败: $e');
      
      // 新方式:
      AppLogger.e('SyncService', '同步失败', e);
    }
    
    // 性能跟踪日志
    AppLogger.d('Performance', '加载首屏耗时: 350ms');
  }
  
  // 日志中添加结构化数据
  void structuredDataLog() {
    final userData = {'id': 12345, 'username': 'example_user'};
    
    // 旧方式:
    // print('用户数据: $userData');
    
    // 新方式:
    AppLogger.i('UserManager', '用户数据: $userData');
    
    // 处理较大的数据结构
    final novelData = {'id': 'novel-123', 'title': '示例小说', 'chapters': 15};
    AppLogger.d('NovelManager', '加载小说数据: $novelData');
  }
  
  // 在异步方法中使用
  Future<void> asyncLogging() async {
    AppLogger.d('AsyncTask', '开始异步任务');
    
    try {
      // 异步操作
      await Future.delayed(const Duration(seconds: 1));
      AppLogger.i('AsyncTask', '异步任务完成');
    } catch (e) {
      AppLogger.e('AsyncTask', '异步任务失败', e);
    }
  }
} 