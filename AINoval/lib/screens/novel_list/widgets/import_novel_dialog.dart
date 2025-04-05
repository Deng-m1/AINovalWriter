import 'package:ainoval/blocs/novel_import/novel_import_bloc.dart';
import 'package:ainoval/blocs/novel_list/novel_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 小说导入对话框
class ImportNovelDialog extends StatefulWidget {
  /// 创建小说导入对话框
  const ImportNovelDialog({super.key});

  @override
  State<ImportNovelDialog> createState() => _ImportNovelDialogState();
}

class _ImportNovelDialogState extends State<ImportNovelDialog> {
  // 存储BLoC引用，避免在dispose中访问context
  late final NovelImportBloc _importBloc;
  
  @override
  void initState() {
    super.initState();
    
    // 获取并保存BLoC引用
    _importBloc = context.read<NovelImportBloc>();
    
    // 初始化时延迟检查，确保 context 已经准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 检查状态并在需要时重置
      final state = _importBloc.state;
      if (state is NovelImportSuccess || state is NovelImportFailure) {
        _importBloc.add(ResetImportState());
      }
    });
  }

   @override
   void dispose() {
     // 确保在对话框关闭时只触发一次重置
     final state = _importBloc.state;
     if (state is NovelImportInProgress && state.status != "CANCELLING") {
       _importBloc.add(ResetImportState());
     }
     super.dispose();
   }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NovelImportBloc, NovelImportState>(
      listener: (context, state) {
        if (state is NovelImportSuccess) {
          // 延迟关闭对话框，给用户一个成功的视觉反馈
          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              // 重置导入状态，确保下次打开对话框时状态为初始状态
              _importBloc.add(ResetImportState());
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
          });
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
                      if (state is! NovelImportInProgress && state is! NovelImportSuccess)
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
                : state.progress > 0 ? state.progress : null,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
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
          
          // 二级状态文本
          Text(
            _getStatusDescription(state.status),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          
          // 添加调试信息，在开发环境下显示
          if (state.jobId != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey.shade100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '任务ID: ${state.jobId}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '状态: ${state.status}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (state is NovelImportSuccess) {
      return Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            '导入成功',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '可能的原因:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 文件编码不是UTF-8\n'
                  '• 文件格式不正确\n'
                  '• 文件可能已损坏\n'
                  '• 服务器暂时无法处理',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade900,
                    height: 1.5,
                  ),
                ),
              ],
            ),
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
    
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Icon(
            iconData,
            size: 48,
            color: iconColor,
          ),
          if (status == 'PROCESSING' || status == 'INDEXING')
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            ),
        ],
      ),
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
            onPressed: () => _importBloc.add(ImportNovelFile()),
            icon: const Icon(Icons.upload_file),
            label: const Text('选择文件'),
          ),
        ],
      );
    } else if (state is NovelImportInProgress) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            _importBloc.add(ResetImportState());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已取消导入'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.cancel),
          label: const Text('取消导入'),
        ),
      );
    } else if (state is NovelImportFailure) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              _importBloc.add(ResetImportState());
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close),
            label: const Text('关闭'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () {
              _importBloc.add(ResetImportState());
              _importBloc.add(ImportNovelFile());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      );
    } else if (state is NovelImportSuccess) {
      return FilledButton.icon(
        onPressed: () {
          _importBloc.add(ResetImportState());
          context.read<NovelListBloc>().add(LoadNovels());
          Navigator.of(context).pop();
        },
        icon: const Icon(Icons.check),
        label: const Text('完成'),
      );
    }
    
    return const SizedBox.shrink();
  }
} 