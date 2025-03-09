import 'package:dio/dio.dart';

class ApiService {
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.ainoval.com/v1',  // 假设的API基础URL
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // 添加拦截器处理错误
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) {
        print('API错误: ${error.message}');
        handler.next(error);
      }
    ));
  }
  late Dio _dio;
  
  // 实际的API方法将在与后端集成时实现
  // 目前在第一迭代中，使用MockData提供数据
} 