import 'package:ainoval/blocs/editor_version_bloc.dart';
import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/scene_version.dart';
import 'package:ainoval/ui/common/loading_indicator.dart';
import 'package:ainoval/ui/common/no_data_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// 场景历史对话框
class SceneHistoryDialog extends StatefulWidget {
  final String novelId;
  final String chapterId;
  final String sceneId;
  
  const SceneHistoryDialog({
    Key? key,
    required this.novelId,
    required this.chapterId,
    required this.sceneId,
  }) : super(key: key);

  @override
  State<SceneHistoryDialog> createState() => _SceneHistoryDialogState();
}

class _SceneHistoryDialogState extends State<SceneHistoryDialog> {
  int? _selectedIndex;
  int? _compareIndex;
  bool _isComparing = false;
  
  @override
  void initState() {
    super.initState();
    // 加载历史记录
    context.read<EditorVersionBloc>().add(EditorVersionFetchHistory(
      novelId: widget.novelId,
      chapterId: widget.chapterId,
      sceneId: widget.sceneId,
    ));
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildContent(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }
  
  /// 构建对话框头部
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '场景历史版本',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
  
  /// 构建对话框内容
  Widget _buildContent() {
    return BlocConsumer<EditorVersionBloc, EditorVersionState>(
      listener: (context, state) {
        if (state is EditorVersionDiffLoaded) {
          // 显示差异对话框
          _showDiffDialog(context, state.diff);
        } else if (state is EditorVersionRestored) {
          // 关闭对话框并返回恢复的场景
          Navigator.of(context).pop(state.scene);
        } else if (state is EditorVersionError) {
          // 显示错误信息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is EditorVersionLoading) {
          return const Center(child: LoadingIndicator());
        } else if (state is EditorVersionHistoryEmpty) {
          return const NoDataPlaceholder(
            message: '暂无历史版本',
            icon: Icons.history,
          );
        } else if (state is EditorVersionHistoryLoaded) {
          return _buildHistoryList(state.history);
        } else if (state is EditorVersionError) {
          return Center(child: Text(state.message));
        }
        
        return const SizedBox.shrink();
      },
    );
  }
  
  /// 构建历史版本列表
  Widget _buildHistoryList(List<SceneHistoryEntry> history) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        final isSelected = _selectedIndex == index;
        final isComparing = _compareIndex == index;
        
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : (isComparing ? Colors.amber.withOpacity(0.1) : null),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Row(
              children: [
                Text('版本 ${index + 1}'),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(entry.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('修改人: ${entry.updatedBy}'),
                Text('原因: ${entry.reason}'),
              ],
            ),
            trailing: _isComparing
                ? IconButton(
                    icon: Icon(
                      isComparing ? Icons.check_circle : Icons.circle_outlined,
                      color: isComparing ? Colors.amber : null,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isComparing) {
                          _compareIndex = null;
                        } else {
                          _compareIndex = index;
                        }
                      });
                    },
                  )
                : null,
            onTap: () {
              setState(() {
                if (_isComparing) {
                  // 比较模式下，点击切换选择状态
                  if (_compareIndex == null || _compareIndex == index) {
                    _compareIndex = index;
                  } else {
                    // 已有两个不同的版本，触发比较
                    _triggerCompare(_compareIndex!, index);
                  }
                } else {
                  // 普通模式下，切换选中状态
                  if (_selectedIndex == index) {
                    _selectedIndex = null;
                  } else {
                    _selectedIndex = index;
                  }
                }
              });
            },
          ),
        );
      },
    );
  }
  
  /// 构建对话框底部
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            setState(() {
              _isComparing = !_isComparing;
              if (!_isComparing) {
                _compareIndex = null;
              }
            });
          },
          child: Text(_isComparing ? '取消比较' : '比较版本'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _selectedIndex != null ? _restoreVersion : null,
          child: const Text('恢复此版本'),
        ),
      ],
    );
  }
  
  /// 触发版本比较
  void _triggerCompare(int index1, int index2) {
    // 确保小索引在前
    final versionIndex1 = index1 < index2 ? index1 : index2;
    final versionIndex2 = index1 < index2 ? index2 : index1;
    
    context.read<EditorVersionBloc>().add(EditorVersionCompare(
      novelId: widget.novelId,
      chapterId: widget.chapterId,
      sceneId: widget.sceneId,
      versionIndex1: versionIndex1,
      versionIndex2: versionIndex2,
    ));
  }
  
  /// 恢复到所选版本
  void _restoreVersion() {
    final index = _selectedIndex!;
    
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复版本'),
        content: const Text('确定要恢复到这个历史版本吗？当前版本将被保存到历史记录中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // 触发恢复事件
              context.read<EditorVersionBloc>().add(EditorVersionRestore(
                novelId: widget.novelId,
                chapterId: widget.chapterId,
                sceneId: widget.sceneId,
                historyIndex: index,
                userId: AppConfig.userId ?? 'system',
                reason: '手动恢复到历史版本',
              ));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 显示差异对话框
  void _showDiffDialog(BuildContext context, SceneVersionDiff diff) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '版本差异',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: '并排对比'),
                          Tab(text: '差异格式'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildSideBySideView(diff),
                            _buildDiffView(diff),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建并排对比视图
  Widget _buildSideBySideView(SceneVersionDiff diff) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('原始版本'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(diff.originalContent),
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(),
        Expanded(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('新版本'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(diff.newContent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// 构建差异视图
  Widget _buildDiffView(SceneVersionDiff diff) {
    final lines = diff.diff.split('\n');
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) {
            Color? color;
            if (line.startsWith('+')) {
              color = Colors.green.shade100;
            } else if (line.startsWith('-')) {
              color = Colors.red.shade100;
            } else if (line.startsWith('@')) {
              color = Colors.blue.shade100;
            }
            
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              color: color,
              child: Text(
                line,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: line.startsWith('+')
                      ? Colors.green.shade900
                      : (line.startsWith('-')
                          ? Colors.red.shade900
                          : null),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
} 