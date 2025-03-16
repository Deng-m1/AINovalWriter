import 'package:dio/dio.dart';
import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';

/// API客户端基类
/// 
/// 负责处理与后端API的基础通信，使用Dio包实现HTTP请求
class ApiClient {
  late final Dio _dio;
  
  ApiClient({Dio? dio}) {
    _dio = dio ?? _createDio();
  }
  
  /// 创建并配置Dio实例
  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );
    
    // 添加拦截器
    dio.interceptors.add(_createAuthInterceptor());
    dio.interceptors.add(_createLogInterceptor());
    
    return dio;
  }
  
  /// 创建认证拦截器
  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AppConfig.authToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    );
  }
  
  /// 创建日志拦截器
  Interceptor _createLogInterceptor() {
    final currentLogLevel = AppConfig.logLevel;
    
    return LogInterceptor(
      requestBody: currentLogLevel == LogLevel.debug,
      responseBody: currentLogLevel == LogLevel.debug,
      error: currentLogLevel == LogLevel.debug || currentLogLevel == LogLevel.error,
      requestHeader: currentLogLevel == LogLevel.debug,
      responseHeader: currentLogLevel == LogLevel.debug,
    );
  }
  
  /// 执行GET请求
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  /// 执行POST请求
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  /// 执行PUT请求
  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  /// 执行DELETE请求
  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  /// 处理Dio错误
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(408, '请求超时，请稍后重试');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 500;
        final message = _getErrorMessageFromResponse(error.response);
        return ApiException(statusCode, message);
      case DioExceptionType.cancel:
        return ApiException(499, '请求被取消');
      case DioExceptionType.connectionError:
        return ApiException(0, '网络连接失败，请检查您的网络连接');
      default:
        return ApiException(-1, '请求失败: ${error.message}');
    }
  }
  
  /// 从响应中获取错误信息
  String _getErrorMessageFromResponse(Response? response) {
    if (response == null) return '未知错误';
    
    try {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['message'] ?? data['error'] ?? '未知错误';
      }
      return data.toString();
    } catch (e) {
      return response.statusMessage ?? '未知错误';
    }
  }
  
  /// 关闭客户端
  void dispose() {
    _dio.close();
  }
} 