import 'dart:io';
import 'dart:convert';

/// 此脚本用于自动将项目中的print语句替换为AppLogger调用
/// 
/// 使用方法：
/// 1. 确保已安装Dart SDK
/// 2. 在项目根目录运行：dart scripts/replace_print_with_logger.dart
/// 
/// 注意：此脚本会修改项目文件，请确保在运行前备份重要文件或使用版本控制系统

// 定义需要处理的目录
const List<String> targetDirs = [
  'lib/services',
  'lib/screens',
  'lib/blocs',
  'lib/repositories',
  'lib/ui',
];

// 需要忽略的文件或目录
const List<String> ignoreList = [
  '.g.dart',  // 生成的文件
  '.freezed.dart',  // 生成的文件
  'generated',  // 生成的目录
];

// 定义日志标签映射关系
const Map<String, String> dirToTagMap = {
  'services': 'Service',
  'screens': 'UI',
  'blocs': 'Bloc',
  'repositories': 'Repo',
  'ui': 'UI',
};

void main() async {
  print('开始替换print语句为AppLogger...');
  
  // 检查项目结构
  final projectDir = Directory.current;
  final libDir = Directory('${projectDir.path}/lib');
  
  if (!await libDir.exists()) {
    print('错误: 找不到lib目录，请确保在项目根目录运行此脚本');
    exit(1);
  }
  
  // 确保脚本目录存在
  final scriptsDir = Directory('${projectDir.path}/scripts');
  if (!await scriptsDir.exists()) {
    await scriptsDir.create();
  }
  
  // 确保已经添加了日志工具类
  final loggerFile = File('${libDir.path}/utils/logger.dart');
  if (!await loggerFile.exists()) {
    print('错误: 找不到日志工具类文件 (lib/utils/logger.dart)');
    print('请先创建日志工具类，再运行此脚本');
    exit(1);
  }
  
  // 创建替换统计
  int totalFiles = 0;
  int processedFiles = 0;
  int totalReplaced = 0;
  
  // 处理每个目标目录
  for (var targetDir in targetDirs) {
    final dir = Directory('${libDir.path}/$targetDir');
    if (!await dir.exists()) {
      print('警告: 目录 $targetDir 不存在，跳过');
      continue;
    }
    
    print('处理目录: $targetDir');
    
    // 获取该目录下所有Dart文件
    await processDirectory(dir, (file) async {
      // 检查是否应该忽略该文件
      if (ignoreList.any((ignore) => file.path.contains(ignore))) {
        return;
      }
      
      totalFiles++;
      
      // 读取文件内容
      String content = await file.readAsString();
      
      // 如果文件不包含print语句，跳过
      if (!content.contains('print(')) {
        return;
      }
      
      // 决定使用的标签
      String tag = getTagForFile(file.path);
      
      // 替换import语句
      if (!content.contains("import 'package:ainoval/utils/logger.dart'")) {
        final importRegExp = RegExp("(import ['\"].*['\"];)");
        final matches = importRegExp.allMatches(content);
        
        if (matches.isNotEmpty) {
          final lastImportMatch = matches.last;
          content = content.replaceRange(
            lastImportMatch.end,
            lastImportMatch.end,
            "\nimport 'package:ainoval/utils/logger.dart';\n"
          );
        } else {
          // 如果没有找到import语句，添加到文件顶部
          content = "import 'package:ainoval/utils/logger.dart';\n\n" + content;
        }
      }
      
      // 替换print语句
      final printRegExp = RegExp(r'print\(([^;]+)\);');
      final matches = printRegExp.allMatches(content);
      
      if (matches.isNotEmpty) {
        final buffer = StringBuffer();
        int lastEnd = 0;
        
        for (var match in matches) {
          // 添加匹配前的内容
          buffer.write(content.substring(lastEnd, match.start));
          
          // 获取print参数
          String printArg = match.group(1)!;
          
          // 确定适当的日志级别
          String logLevel = 'i';  // 默认使用info级别
          
          // 根据输出内容确定日志级别
          if (printArg.contains('警告') || 
              printArg.contains('warning') ||
              printArg.toLowerCase().contains('warn')) {
            logLevel = 'w';
          } else if (printArg.contains('错误') || 
                    printArg.contains('失败') || 
                    printArg.toLowerCase().contains('error') ||
                    printArg.toLowerCase().contains('fail')) {
            logLevel = 'e';
          } else if (printArg.toLowerCase().contains('debug')) {
            logLevel = 'd';
          }
          
          // 针对错误日志的特殊处理
          if (logLevel == 'e' && printArg.contains(': \$e')) {
            // 尝试将异常分离出来
            printArg = printArg.replaceFirst(RegExp(r': \$e'), '');
            buffer.write('AppLogger.$logLevel(\'$tag\', $printArg, \$e);');
          } else {
            // 普通日志
            buffer.write('AppLogger.$logLevel(\'$tag\', $printArg);');
          }
          
          lastEnd = match.end;
          totalReplaced++;
        }
        
        // 添加剩余内容
        buffer.write(content.substring(lastEnd));
        content = buffer.toString();
        
        // 写回文件
        await file.writeAsString(content);
        processedFiles++;
        
        print('  已处理: ${file.path.split('/').last} (替换了 ${matches.length} 处)');
      }
    });
  }
  
  // 输出统计结果
  print('\n替换完成!');
  print('总文件数: $totalFiles');
  print('处理文件数: $processedFiles');
  print('替换次数: $totalReplaced');
  print('\n注意: 自动替换可能需要手动检查和优化，特别是对于复杂的print语句。');
  print('建议在IDE中搜索remaining "print(" 以查找可能漏掉的print语句。');
}

// 递归处理目录中的所有Dart文件
Future<void> processDirectory(Directory directory, Future<void> Function(File file) processor) async {
  await for (var entity in directory.list()) {
    if (entity is File && entity.path.endsWith('.dart')) {
      await processor(entity);
    } else if (entity is Directory) {
      // 检查是否应该忽略该目录
      if (!ignoreList.any((ignore) => entity.path.contains(ignore))) {
        await processDirectory(entity, processor);
      }
    }
  }
}

// 根据文件路径确定合适的日志标签
String getTagForFile(String filePath) {
  // 从文件路径提取文件名(不含扩展名)
  final fileName = filePath.split('/').last.replaceAll('.dart', '');
  
  // 首先检查是否可以从目录结构推断标签
  for (var entry in dirToTagMap.entries) {
    if (filePath.contains('/${entry.key}/')) {
      // 寻找可能的具体模块名
      final parts = filePath.split('/');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i] == entry.key && i + 1 < parts.length) {
          // 使用子目录名作为标签的一部分
          return '${parts[i+1].capitalize()}${entry.value}';
        }
      }
      return entry.value;
    }
  }
  
  // 如果无法从目录推断，使用文件名作为标签
  return fileName.capitalize();
}

// 将字符串首字母大写的扩展方法
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
} 