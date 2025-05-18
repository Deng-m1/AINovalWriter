import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/models/setting_group.dart';
import 'package:ainoval/blocs/setting/setting_bloc.dart';
import 'package:ainoval/screens/editor/widgets/novel_setting_group_dialog.dart';
import 'package:ainoval/utils/logger.dart';

/// 小说设定组选择对话框
/// 
/// 用于选择现有设定组或创建新设定组
class NovelSettingGroupSelectionDialog extends StatefulWidget {
  final String novelId;
  final Function(String groupId, String groupName) onGroupSelected;
  
  const NovelSettingGroupSelectionDialog({
    Key? key,
    required this.novelId,
    required this.onGroupSelected,
  }) : super(key: key);

  @override
  State<NovelSettingGroupSelectionDialog> createState() => _NovelSettingGroupSelectionDialogState();
}

class _NovelSettingGroupSelectionDialogState extends State<NovelSettingGroupSelectionDialog> {
  @override
  void initState() {
    super.initState();
    // 加载设定组列表
    context.read<SettingBloc>().add(LoadSettingGroups(widget.novelId));
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 5,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择设定组',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 设定组列表
            BlocBuilder<SettingBloc, SettingState>(
              builder: (context, state) {
                if (state.groupsStatus == SettingStatus.loading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (state.groupsStatus == SettingStatus.failure) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        '加载设定组失败：${state.error}',
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                
                if (state.groupsStatus == SettingStatus.success && state.groups.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        '没有可用的设定组，请创建新设定组',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                
                if (state.groupsStatus == SettingStatus.success) {
                  return SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: state.groups.length,
                      itemBuilder: (context, index) {
                        final group = state.groups[index];
                        return ListTile(
                          title: Text(group.name),
                          subtitle: group.description != null && group.description!.isNotEmpty
                              ? Text(
                                  group.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          leading: Icon(
                            Icons.folder_outlined,
                            color: group.isActiveContext == true
                                ? theme.colorScheme.primary
                                : Colors.grey,
                          ),
                          onTap: () {
                            widget.onGroupSelected(group.id!, group.name);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  );
                }
                
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text('请加载设定组'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('创建新设定组'),
                  onPressed: () {
                    _showCreateGroupDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, 
                      vertical: 10,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 显示创建设定组对话框
  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return NovelSettingGroupDialog(
          novelId: widget.novelId,
          onSave: (SettingGroup group) {
            AppLogger.i('NovelSettingGroupSelectionDialog', '创建设定组：${group.name}');
            
            // 保存设定组
            context.read<SettingBloc>().add(CreateSettingGroup(
              novelId: widget.novelId,
              group: group,
            ));
            
            // 监听状态变化，找到新创建的设定组
            final settingBloc = context.read<SettingBloc>();
            late final subscription;
            subscription = settingBloc.stream.listen((state) {
              if (state.groupsStatus == SettingStatus.success) {
                // 检查是否有新添加的设定组
                final newGroup = state.groups.where((g) => g.name == group.name).lastOrNull;
                if (newGroup != null && newGroup.id != null) {
                  widget.onGroupSelected(newGroup.id!, newGroup.name);
                  Navigator.of(context).pop(); // 关闭选择对话框
                  subscription.cancel(); // 停止监听
                }
              }
            });
            
            // 一段时间后如果没有成功，取消订阅
            Future.delayed(const Duration(seconds: 5), () {
              subscription.cancel();
            });
          },
        );
      },
    );
  }
} 