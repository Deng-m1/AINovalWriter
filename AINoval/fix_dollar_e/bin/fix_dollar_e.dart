import 'dart:io';

void main(List<String> arguments) async {
  print('开始修复 AppLogger.e 中的 \$e 错误...');
  
  // 获取目录路径
  String projectRoot = Directory.current.parent.path;
  print('项目路径: $projectRoot');
  
  // 扫描lib目录下的所有dart文件
  await _processDirectory(Directory('$projectRoot/lib'));
  
  print('修复完成！');
}

Future<void> _processDirectory(Directory dir) async {
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      await _fixDollarEInFile(entity);
    }
  }
}

Future<void> _fixDollarEInFile(File file) async {
  try {
    String content = await file.readAsString();
    
    // 查找 "AppLogger.e(..., $e)" 模式
    final regex = RegExp(r'AppLogger\.e\(([^,]+),([^,]+),\s*\$e\)');
    
    if (content.contains('\$e')) {
      final matches = regex.allMatches(content);
      if (matches.isNotEmpty) {
        print('在文件 ${file.path} 中找到 ${matches.length} 处错误');
        
        // 替换所有匹配项
        content = content.replaceAllMapped(regex, (match) {
          return 'AppLogger.e(${match.group(1)},${match.group(2)}, e)';
        });
        
        // 写回文件
        await file.writeAsString(content);
        print('  已修复文件: ${file.path}');
      }
    }
  } catch (e) {
    print('处理文件 ${file.path} 时出错: $e');
  }
} 