import 'package:ainoval/blocs/auth/auth_bloc.dart';
import 'package:ainoval/screens/novel_list/novel_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  bool _isLogin = true; // 是否为登录模式

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// 切换登录/注册模式
  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
    _formKey.currentState?.reset(); // 重置表单验证状态
  }

  /// 提交表单 - 改为向 AuthBloc 发送事件
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // 获取 AuthBloc 实例
      final authBloc = context.read<AuthBloc>();

      if (_isLogin) {
        // --- 发送登录事件 ---
        authBloc.add(AuthLogin(
          username: _usernameController.text,
          password: _passwordController.text,
        ));
      } else {
        // --- 发送注册事件 ---
        authBloc.add(AuthRegister(
          username: _usernameController.text,
          password: _passwordController.text,
          email: _emailController.text,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // --- 处理认证成功后的导航 ---
          if (state is AuthAuthenticated) {
            // 确保在 widget 仍然挂载时执行导航
            if (mounted) {
              // 导航到小说列表页面
              // 使用 pushReplacement 避免用户返回登录页
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const NovelListScreen()),
              );
            }
          }
        },
        builder: (context, state) {
          // 根据 BLoC 状态判断是否显示加载状态
          final bool isLoading = state is AuthLoading;
          // 从 BLoC 状态获取错误信息
          final String? errorMessage = state is AuthError ? state.message : null;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.biotech,
                            size: 60,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AINoval',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin ? '登录您的创作平台' : '加入AINoval开始创作',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 32),

                          if (errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.onErrorContainer,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage,
                                      style: TextStyle(
                                          color: theme.colorScheme.onErrorContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: '用户名',
                              prefixIcon: Icon(Icons.person_outline,
                                  color: theme.iconTheme.color?.withOpacity(0.7)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor:
                                  isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16.0, horizontal: 12.0),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入用户名';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: Icon(Icons.lock_outline,
                                  color: theme.iconTheme.color?.withOpacity(0.7)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor:
                                  isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16.0, horizontal: 12.0),
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

                          if (!_isLogin) ...[
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: '邮箱',
                                prefixIcon: Icon(Icons.email_outlined,
                                    color: theme.iconTheme.color?.withOpacity(0.7)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                filled: true,
                                fillColor: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16.0, horizontal: 12.0),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入邮箱';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  return '请输入有效的邮箱地址';
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                            child: isLoading
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? '登 录' : '注 册',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 16),

                          TextButton(
                            onPressed: isLoading ? null : _toggleMode,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _isLogin ? '还没有账户？立即注册' : '已有账户？前往登录',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
