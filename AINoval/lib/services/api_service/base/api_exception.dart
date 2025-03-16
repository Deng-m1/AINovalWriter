/// API异常类
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  
  @override
  String toString() => 'ApiException: $statusCode - $message';
} 