import 'dart:io';

// <<< 导入 AiConfigBloc >>>
import 'package:ainoval/blocs/ai_config/ai_config_bloc.dart';
// 导入聊天相关的类
import 'package:ainoval/blocs/auth/auth_bloc.dart';
import 'package:ainoval/blocs/chat/chat_bloc.dart';
import 'package:ainoval/blocs/editor_version_bloc.dart';
import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/config/app_config.dart'; // 引入 AppConfig
import 'package:ainoval/l10n/l10n.dart';
import 'package:ainoval/screens/auth/login_screen.dart';
import 'package:ainoval/screens/novel_list/novel_list_screen.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
// <<< 移除未使用的 Codex Impl 引用 >>>
// import 'package:ainoval/services/api_service/repositories/impl/codex_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart'; // <<< 导入接口
// ApiService import might not be needed directly in main unless provided
// import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/api_service/repositories/impl/chat_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/novel_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/storage_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/impl/user_ai_model_config_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart'; // <<< 导入接口
import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
// <<< 导入 AI Config 仓库 >>>
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/services/auth_service.dart' as auth_service;
import 'package:ainoval/services/context_provider.dart';
import 'package:ainoval/services/local_storage_service.dart';
// import 'package:ainoval/services/websocket_service.dart';
import 'package:ainoval/utils/app_theme.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ainoval/blocs/prompt/prompt_bloc.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/prompt_repository_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  AppLogger.init();

  // 初始化Hive本地存储
  await Hive.initFlutter();

  // 创建必要的资源文件夹 - 仅在非Web平台执行
  if (!kIsWeb) {
    await _createResourceDirectories();
  }

  // 初始化LocalStorageService
  final localStorageService = LocalStorageService();
  await localStorageService.init();

  // 直接创建 ApiClient 实例
  final apiClient = ApiClient();
/* 
  // 创建ApiService (如果 ApiService 需要 ApiClient, 则传入)
  // 假设 ApiService 构造函数接受 apiClient (如果不需要则忽略)
  final apiService = ApiService(/* apiClient: apiClient */); 
  
  // 创建WebSocketService
  final webSocketService = WebSocketService(); */

  // 创建AuthService
  final authServiceInstance = auth_service.AuthService();
  await authServiceInstance.init();

  // 创建NovelRepository (它不再需要MockDataService)
  final novelRepository = NovelRepositoryImpl(/* apiClient: apiClient */);

  // 创建ChatRepository，并传入 ApiClient
  final chatRepository = ChatRepositoryImpl(
    apiClient: apiClient, // 使用直接创建的 apiClient
  );

  // 创建StorageRepository实例
  final storageRepository = StorageRepositoryImpl(apiClient);

  // 创建UserAIModelConfigRepository
  final userAIModelConfigRepository =
      UserAIModelConfigRepositoryImpl(apiClient: apiClient);

  // 创建ContextProvider，移除 codexRepository 依赖
  final codexRepository = CodexRepository();
  final contextProvider = ContextProvider(
      novelRepository: novelRepository, codexRepository: codexRepository);

  // 创建PromptRepository
  final promptRepository = PromptRepositoryImpl(apiClient);

  AppLogger.i('Main', '应用程序初始化完成，准备启动界面');

  AppLogger.i('Main', '应用程序初始化完成，准备启动界面');

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<auth_service.AuthService>.value(
            value: authServiceInstance),
        RepositoryProvider<ApiClient>.value(value: apiClient),
        RepositoryProvider<NovelRepository>.value(value: novelRepository),
        RepositoryProvider<CodexRepository>.value(value: codexRepository),
        RepositoryProvider<ChatRepository>.value(value: chatRepository),
        RepositoryProvider<StorageRepository>.value(value: storageRepository),
        RepositoryProvider<UserAIModelConfigRepository>.value(
            value: userAIModelConfigRepository),
        RepositoryProvider<ContextProvider>.value(value: contextProvider),
        RepositoryProvider<LocalStorageService>.value(
            value: localStorageService),
        RepositoryProvider<PromptRepository>(
          create: (context) => promptRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authService: context.read<auth_service.AuthService>(),
            )..add(AuthInitialize()),
          ),
          BlocProvider<NovelListBloc>(
            create: (context) => NovelListBloc(
              repository: context.read<NovelRepository>(),
            )..add(LoadNovels()),
          ),
          BlocProvider<AiConfigBloc>(
            create: (context) => AiConfigBloc(
              repository: context.read<UserAIModelConfigRepository>(),
            ),
          ),
          BlocProvider<ChatBloc>(
            create: (context) => ChatBloc(
              repository: context.read<ChatRepository>(),
              contextProvider: context.read<ContextProvider>(),
              authService: context.read<auth_service.AuthService>(),
              aiConfigBloc: context.read<AiConfigBloc>(),
            ),
          ),
          BlocProvider<EditorVersionBloc>(
            create: (context) => EditorVersionBloc(
              novelRepository: context.read<NovelRepository>(),
            ),
          ),
          BlocProvider<PromptBloc>(
            create: (context) => PromptBloc(
              promptRepository: context.read<PromptRepository>(),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

// 创建资源文件夹
Future<void> _createResourceDirectories() async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final assetsDir = Directory('${appDir.path}/assets');
    final imagesDir = Directory('${assetsDir.path}/images');
    final iconsDir = Directory('${assetsDir.path}/icons');

    // 创建资源目录
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }

    // 创建图像目录
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // 创建图标目录
    if (!await iconsDir.exists()) {
      await iconsDir.create(recursive: true);
    }

    AppLogger.i('ResourceDir', '资源文件夹创建成功');
  } catch (e) {
    AppLogger.e('ResourceDir', '创建资源文件夹失败', e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AINoval',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            final userId = AppConfig.userId;
            if (userId != null) {
              AppLogger.i('MyApp',
                  'User authenticated, loading AiConfigs for user $userId');
              context.read<AiConfigBloc>().add(LoadAiConfigs(userId: userId));
            } else {
              AppLogger.e('MyApp',
                  'User authenticated but userId is null in AppConfig!');
            }
          }
        },
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            AppLogger.i(
                'MyApp', 'User Authenticated, showing NovelListScreen.');
            return const NovelListScreen();
          }
          AppLogger.i('MyApp',
              'User Not Authenticated or Initial, showing LoginScreen.');
          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,

      // 添加完整的本地化支持
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.all,
      locale: const Locale('zh', 'CN'), // 设置默认语言为中文
    );
  }
}
