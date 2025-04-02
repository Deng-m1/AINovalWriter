import 'package:ainoval/blocs/novel_import/novel_import_bloc.dart';
import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 小说导入对话框
class ImportNovelDialog extends StatelessWidget {
  /// 创建小说导入对话框
  const ImportNovelDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NovelImportBloc, NovelImportState>(
      listener: (context, state) {
        if (state is NovelImportSuccess) {
          context.read<NovelListBloc>().add(LoadNovels());
          Navigator.of(context).pop();
          // 显示成功消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导入成功: ${state.message}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minHeight: 200,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Row(
                    children: [
                      const Icon(Icons.upload_file, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        '导入小说',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (state is! NovelImportInProgress)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: '关闭',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 状态和内容
                  _buildDialogContent(context, state),
                  
                  const SizedBox(height: 16),
                  
                  // 按钮
                  _buildDialogActions(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 构建对话框内容
  Widget _buildDialogContent(BuildContext context, NovelImportState state) {
    if (state is NovelImportInitial) {
      return Column(
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            '导入TXT格式的小说文件，系统将自动识别章节结构。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '支持的文件格式: TXT (UTF-8编码)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      );
    } else if (state is NovelImportInProgress) {
      return Column(
        children: [
          const SizedBox(height: 16),
          
          // 进度指示器
          LinearProgressIndicator(
            value: state.status == 'PREPARING' || state.status == 'UPLOADING' 
                ? null  // 不确定进度时使用不确定进度条
                : state.progress,
          ),
          
          const SizedBox(height: 24),
          
          // 状态图标
          _buildStatusIcon(context, state.status),
          
          const SizedBox(height: 16),
          
          // 状态文本
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          
          const SizedBox(height: 8),
          
          // 二级状态文本 (可选)
          Text(
            _getStatusDescription(state.status),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    } else if (state is NovelImportFailure) {
      return Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '导入失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }
  
  /// 构建状态图标
  Widget _buildStatusIcon(BuildContext context, String status) {
    final theme = Theme.of(context);
    
    IconData iconData;
    Color iconColor;
    
    switch (status) {
      case 'PREPARING':
        iconData = Icons.file_present;
        iconColor = Colors.blue;
        break;
      case 'UPLOADING':
        iconData = Icons.cloud_upload;
        iconColor = Colors.blue;
        break;
      case 'PROCESSING':
        iconData = Icons.auto_stories;
        iconColor = theme.colorScheme.primary;
        break;
      case 'SAVING':
        iconData = Icons.save;
        iconColor = theme.colorScheme.primary;
        break;
      case 'INDEXING':
        iconData = Icons.search;
        iconColor = theme.colorScheme.secondary;
        break;
      default:
        iconData = Icons.sync;
        iconColor = theme.colorScheme.primary;
    }
    
    return Icon(
      iconData,
      size: 48,
      color: iconColor,
    );
  }
  
  /// 获取状态描述
  String _getStatusDescription(String status) {
    switch (status) {
      case 'PREPARING':
        return '正在准备文件数据...';
      case 'UPLOADING':
        return '正在上传文件到服务器...';
      case 'PROCESSING':
        return '正在分析文件内容，识别章节结构...';
      case 'SAVING':
        return '正在保存小说结构和章节内容...';
      case 'INDEXING':
        return '正在为小说内容创建索引，以便AI更好地理解...';
      default:
        return '处理中...';
    }
  }
  
  /// 构建对话框按钮
  Widget _buildDialogActions(BuildContext context, NovelImportState state) {
    if (state is NovelImportInitial) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.cancel),
            label: const Text('取消'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () => context.read<NovelImportBloc>().add(ImportNovelFile()),
            icon: const Icon(Icons.upload_file),
            label: const Text('选择文件'),
          ),
        ],
      );
    } else if (state is NovelImportInProgress) {
      return Center(
        child: TextButton.icon(
          onPressed: state.status == 'UPLOADING' || state.status == 'PREPARING'
              ? () {
                  context.read<NovelImportBloc>().add(ResetImportState());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已取消导入'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              : null, // 其他状态不允许取消
          icon: const Icon(Icons.cancel),
          label: const Text('取消导入'),
        ),
      );
    } else if (state is NovelImportFailure) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('关闭'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () => context.read<NovelImportBloc>().add(ImportNovelFile()),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }
} 