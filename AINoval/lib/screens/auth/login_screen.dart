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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      // 添加一个微妙的背景渐变或颜色
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          // 使用 Container 限制 Card 的最大宽度
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400), // 限制最大宽度为 400
            child: Card(
              elevation: 8.0, // 增加阴影
              shape: RoundedRectangleBorder(
                // 添加圆角
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
                      // 应用标志 - 可以考虑使用更现代的图标或 Logo
                      Icon(
                        Icons.biotech, // 换一个更科技感的图标
                        size: 60, // 调整大小
                        color: theme.colorScheme.primary, // 使用主题色
                      ),

                      const SizedBox(height: 16),

                      // 应用名称 - 保持简洁
                      Text(
                        'AINoval',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          // 使用主题字体样式
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 应用描述
                      Text(
                        _isLogin ? '登录您的创作平台' : '加入AINoval开始创作', // 更新文本
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          // 使用主题字体样式
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 错误信息 - 样式调整
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin:
                              const EdgeInsets.only(bottom: 16), // 和下方元素增加间距
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer, // 使用主题错误色
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            // 添加图标增加提示性
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                      color:
                                          theme.colorScheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 用户名 - 现代输入框样式
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline,
                              color: theme.iconTheme.color?.withOpacity(0.7)),
                          border: OutlineInputBorder(
                            // 圆角边框
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          filled: true, // 填充背景色
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

                      // 密码 - 现代输入框样式
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock_outline,
                              color: theme.iconTheme.color?.withOpacity(0.7)),
                          border: OutlineInputBorder(
                            // 圆角边框
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          filled: true, // 填充背景色
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

                      // 注册模式下的额外字段 - 使用相同样式
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),

                        // 邮箱
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: '邮箱',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: theme.iconTheme.color?.withOpacity(0.7)),
                            border: OutlineInputBorder(
                              // 圆角边框
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            filled: true, // 填充背景色
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

                        const SizedBox(height: 16),

                        // 显示名称 (可选字段，通常注册不需要立刻填)
                        // 如果需要，使用同样的TextFormField样式
                        // TextFormField( ... ),
                      ],

                      const SizedBox(height: 24),

                      // 提交按钮 - 现代按钮样式
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            // 圆角
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          backgroundColor: theme.colorScheme.primary, // 使用主题色
                          foregroundColor: theme.colorScheme.onPrimary, // 文本颜色
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24, // 调整加载指示器大小
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: theme.colorScheme.onPrimary, // 指示器颜色
                                ),
                              )
                            : Text(
                                _isLogin ? '登 录' : '注 册',
                                style: const TextStyle(
                                  // 按钮文本样式
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // 切换登录/注册模式 - 样式调整
                      TextButton(
                        onPressed: _isLoading ? null : _toggleMode, // 加载时禁用
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _isLogin ? '还没有账户？立即注册' : '已有账户？前往登录',
                          style: TextStyle(
                            color: theme.colorScheme.primary, // 使用主题色
                            fontWeight: FontWeight.w600, // 稍微加粗
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
      ),
    );
  }
}
