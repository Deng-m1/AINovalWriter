import 'package:ainoval/screens/novel_list/novel_list_screen.dart';
import 'package:ainoval/services/auth_service.dart';
import 'package:flutter/material.dart';

/// 登录页面
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _isLogin = true; // 是否为登录模式
  bool _isLoading = false; // 是否正在加载
  String? _errorMessage; // 错误信息
  
  final AuthService _authService = AuthService();
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }
  
  /// 切换登录/注册模式
  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
  }
  
  /// 提交表单
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        AuthState result;
        
        if (_isLogin) {
          // 登录
          result = await _authService.login(
            _usernameController.text,
            _passwordController.text,
          );
        } else {
          // 注册
          result = await _authService.register(
            _usernameController.text,
            _passwordController.text,
            _emailController.text,
          );
        }
        
        if (result.isAuthenticated) {
          // 登录成功，跳转到小说列表页面
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const NovelListScreen()),
            );
          }
        } else {
          // 登录失败
          setState(() {
            _errorMessage = result.error ?? '认证失败';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 应用标志
                const Icon(
                  Icons.book,
                  size: 80,
                  color: Colors.blue,
                ),
                
                const SizedBox(height: 16),
                
                // 应用名称
                const Text(
                  'AINoval',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 应用描述
                Text(
                  _isLogin ? '登录您的账户' : '创建新账户',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 错误信息
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                
                if (_errorMessage != null)
                  const SizedBox(height: 16),
                
                // 用户名
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 密码
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (!_isLogin && value.length < 6) {
                      return '密码长度至少为6位';
                    }
                    return null;
                  },
                ),
                
                // 注册模式下的额外字段
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  
                  // 邮箱
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入邮箱';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return '请输入有效的邮箱地址';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 显示名称
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: '显示名称',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入显示名称';
                      }
                      return null;
                    },
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // 提交按钮
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLogin ? '登录' : '注册'),
                ),
                
                const SizedBox(height: 16),
                
                // 切换登录/注册模式
                TextButton(
                  onPressed: _toggleMode,
                  child: Text(_isLogin ? '没有账号？点击注册' : '已有账号？点击登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}