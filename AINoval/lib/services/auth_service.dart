import 'dart:async';
import 'dart:convert';

import 'package:ainoval/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ainoval/utils/logger.dart';


/// 用户认证服务
/// 
/// 负责用户登录、注册、令牌管理等认证相关功能
class AuthService {
  
  AuthService({
    String? baseUrl,
    http.Client? client,
  }) : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _client = client ?? http.Client();
  
  final String _baseUrl;
  final http.Client _client;
  
  // 存储令牌的键
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  
  // 认证状态流
  final _authStateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateStream => _authStateController.stream;
  
  // 当前认证状态
  AuthState _currentState = AuthState.unauthenticated();
  AuthState get currentState => _currentState;
  
  /// 初始化认证服务
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    
    if (token != null) {
      final userId = prefs.getString(_userIdKey);
      final username = prefs.getString(_usernameKey);
      
      // 设置认证状态
      _currentState = AuthState.authenticated(
        token: token,
        userId: userId ?? '',
        username: username ?? '',
      );
      
      // 设置全局认证令牌、用户ID和用户名
      AppConfig.setAuthToken(token);
      AppConfig.setUserId(userId);
      AppConfig.setUsername(username);
      
      // 发送认证状态更新
      _authStateController.add(_currentState);
    }
  }
  
  /// 用户登录
  Future<AuthState> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final refreshToken = data['refreshToken'];
        final userId = data['userId'];
        
        // 保存令牌到本地存储
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_refreshTokenKey, refreshToken);
        await prefs.setString(_userIdKey, userId);
        await prefs.setString(_usernameKey, username);
        
        // 设置全局认证令牌、用户ID和用户名
        AppConfig.setAuthToken(token);
        AppConfig.setUserId(userId);
        AppConfig.setUsername(username);
        
        // 更新认证状态
        _currentState = AuthState.authenticated(
          token: token,
          userId: userId,
          username: username,
        );
        
        // 发送认证状态更新
        _authStateController.add(_currentState);
        
        return _currentState;
      } else {
        final error = _parseErrorMessage(response);
        throw AuthException(error);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('登录失败: $e');
    }
  }
  
  /// 用户注册
  Future<AuthState> register(String username, String password, String email, {String? displayName}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': email,
          'displayName': displayName ?? username,
        }),
      );
      
      if (response.statusCode == 201) {
        // 注册成功后自动登录
        return login(username, password);
      } else {
        final error = _parseErrorMessage(response);
        throw AuthException(error);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('注册失败: $e');
    }
  }
  
  /// 用户登出
  Future<void> logout() async {
    try {
      // 清除本地存储的令牌
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_usernameKey);
      
      // 清除全局认证令牌、用户ID和用户名
      AppConfig.setAuthToken(null);
      AppConfig.setUserId(null);
      AppConfig.setUsername(null);
      
      // 更新认证状态
      _currentState = AuthState.unauthenticated();
      
      // 发送认证状态更新
      _authStateController.add(_currentState);
    } catch (e) {
      AppLogger.e('Services/auth_service', '登出失败', e);
    }
  }
  
  /// 刷新令牌
  Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);
      
      if (refreshToken == null) {
        return false;
      }
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'];
        final newRefreshToken = data['refreshToken'];
        
        // 保存新令牌到本地存储
        await prefs.setString(_tokenKey, newToken);
        await prefs.setString(_refreshTokenKey, newRefreshToken);
        
        // 设置全局认证令牌
        AppConfig.setAuthToken(newToken);
        
        // 更新认证状态
        final userId = prefs.getString(_userIdKey) ?? '';
        final username = prefs.getString(_usernameKey) ?? '';
        
        // 设置用户ID和用户名
        AppConfig.setUserId(userId);
        AppConfig.setUsername(username);
        
        _currentState = AuthState.authenticated(
          token: newToken,
          userId: userId,
          username: username,
        );
        
        // 发送认证状态更新
        _authStateController.add(_currentState);
        
        return true;
      } else {
        // 刷新令牌失败，清除认证状态
        await logout();
        return false;
      }
    } catch (e) {
      AppLogger.e('Services/auth_service', '刷新令牌失败', e);
      // 刷新令牌失败，清除认证状态
      await logout();
      return false;
    }
  }
  
  /// 获取当前用户信息
  Future<Map<String, dynamic>> getCurrentUser() async {
    if (!_currentState.isAuthenticated) {
      throw AuthException('用户未登录');
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/users/${_currentState.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_currentState.token}',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // 令牌过期，尝试刷新
        final refreshed = await refreshToken();
        if (refreshed) {
          // 刷新成功，重试
          return getCurrentUser();
        } else {
          throw AuthException('认证已过期，请重新登录');
        }
      } else {
        final error = _parseErrorMessage(response);
        throw AuthException(error);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('获取用户信息失败: $e');
    }
  }
  
  /// 更新用户信息
  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
    if (!_currentState.isAuthenticated) {
      throw AuthException('用户未登录');
    }
    
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/users/${_currentState.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_currentState.token}',
        },
        body: jsonEncode(profileData),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // 令牌过期，尝试刷新
        final refreshed = await refreshToken();
        if (refreshed) {
          // 刷新成功，重试
          return updateUserProfile(profileData);
        } else {
          throw AuthException('认证已过期，请重新登录');
        }
      } else {
        final error = _parseErrorMessage(response);
        throw AuthException(error);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('更新用户信息失败: $e');
    }
  }
  
  /// 修改密码
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (!_currentState.isAuthenticated) {
      throw AuthException('用户未登录');
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_currentState.token}',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      
      if (response.statusCode == 200) {
        // 密码修改成功
        return;
      } else if (response.statusCode == 401) {
        // 令牌过期，尝试刷新
        final refreshed = await refreshToken();
        if (refreshed) {
          // 刷新成功，重试
          return changePassword(currentPassword, newPassword);
        } else {
          throw AuthException('认证已过期，请重新登录');
        }
      } else {
        final error = _parseErrorMessage(response);
        throw AuthException(error);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('修改密码失败: $e');
    }
  }
  
  /// 解析错误消息
  String _parseErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? data['error'] ?? '未知错误';
    } catch (e) {
      return response.body.isNotEmpty ? response.body : '未知错误';
    }
  }
  
  /// 关闭服务
  void dispose() {
    _authStateController.close();
    _client.close();
  }
}

/// 认证状态类
class AuthState {
  
  AuthState({
    required this.isAuthenticated,
    this.token = '',
    this.userId = '',
    this.username = '',
    this.error,
  });
  
  /// 已认证状态
  factory AuthState.authenticated({
    required String token,
    required String userId,
    required String username,
  }) {
    return AuthState(
      isAuthenticated: true,
      token: token,
      userId: userId,
      username: username,
    );
  }
  
  /// 未认证状态
  factory AuthState.unauthenticated() {
    return AuthState(isAuthenticated: false);
  }
  
  /// 认证错误状态
  factory AuthState.error(String errorMessage) {
    return AuthState(
      isAuthenticated: false,
      error: errorMessage,
    );
  }
  final bool isAuthenticated;
  final String token;
  final String userId;
  final String username;
  final String? error;
}

/// 认证异常类
class AuthException implements Exception {
  
  AuthException(this.message);
  final String message;
  
  @override
  String toString() => 'AuthException: $message';
} 