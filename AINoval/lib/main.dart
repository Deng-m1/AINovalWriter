import 'dart:io';

import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:ainoval/repositories/novel_repository.dart';
import 'package:ainoval/repositories/editor_repository.dart';
import 'package:ainoval/screens/novel_list/novel_list_screen.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ainoval/l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Hive本地存储
  await Hive.initFlutter();
  
  // 创建必要的资源文件夹 - 仅在非Web平台执行
  if (!kIsWeb) {
    await _createResourceDirectories();
  }
  
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<NovelListBloc>(
          create: (context) => NovelListBloc(
            repository: NovelRepository(
              apiService: ApiService(),
              localStorageService: LocalStorageService(),
            ),
          )..add(LoadNovels()),
        ),
      ],
      child: const MyApp(),
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
    final fontsDir = Directory('${assetsDir.path}/fonts');
    
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
    
    // 创建字体目录
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    
    print('资源文件夹创建成功');
  } catch (e) {
    print('创建资源文件夹失败: $e');
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
      home: const NovelListScreen(),
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