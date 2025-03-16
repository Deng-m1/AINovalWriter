import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../blocs/chat/chat_bloc.dart';
import '../../../blocs/chat/chat_event.dart';
import '../../../blocs/chat/chat_state.dart';
import '../../../models/chat_models.dart';

/// 聊天边栏组件，用于在编辑器左侧显示聊天功能
class ChatSidebar extends StatefulWidget {
  
  const ChatSidebar({
    Key? key,
    required this.novelId,
    this.chapterId,
  }) : super(key: key);
  final String novelId;
  final String? chapterId;
  
  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadChatSessions(novelId: widget.novelId));
  }

  void _createNewThread() {
    context.read<ChatBloc>().add(CreateChatSession(
      title: '新对话 ${DateFormat('MM-dd HH:mm').format(DateTime.now())}',
      novelId: widget.novelId,
      chapterId: widget.chapterId,
    ));
  }

  void _selectSession(String sessionId) {
    context.read<ChatBloc>().add(SelectChatSession(sessionId: sessionId));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索对话...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none, // 将 borderSide 移到这里
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),

            ),
            onChanged: (value) {
              // TODO: 实现搜索逻辑，可能需要发送新的 Bloc 事件
            },
          ),
        ),
        
        Expanded(
          child: BlocBuilder<ChatBloc, ChatState>(
            buildWhen: (previous, current) {
                 if (previous is ChatSessionsLoading && current is ChatSessionsLoaded) return true;
                 if (previous is ChatSessionsLoaded && current is ChatSessionsLoaded) {
                     return previous.sessions != current.sessions || previous.error != current.error;
                 }
                 if (current is ChatError) return true;
                 if (current is ChatInitial && !(previous is ChatInitial)) return true; // 从其他状态返回初始
                 // 根据需要处理其他状态转换
                 return previous.runtimeType != current.runtimeType; // 默认在状态类型变化时重建
            },
            builder: (context, state) {
              // --- 加载状态 ---
              if (state is ChatSessionsLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              // --- 列表加载完成 ---
              else if (state is ChatSessionsLoaded) {
                final sessions = state.sessions;
                // 正确处理空列表
                if (sessions.isEmpty) {
                  // 显示空列表提示，而不是加载指示器
                  return const Center(child: Text('没有对话记录'));
                }
                // 显示列表
                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    // ListTile 内容保持不变
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '更新于: ${DateFormat('MM-dd HH:mm').format(session.lastUpdatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        _selectSession(session.id);
                      },
                      // 可以考虑添加选中状态高亮
                      selected: /* BlocProvider.of<NavBloc>(context).state.selectedSessionId == session.id */ false, // 这里需要访问表示选中会话的状态
                    );
                  },
                );
              }
              // --- 错误状态 ---
              else if (state is ChatError) {
                return Center(child: Text('加载失败: ${state.message}', style: TextStyle(color: Colors.red)));
              }
              // --- 其他状态 (包括 ChatInitial, ChatSessionActive 等，在这个侧边栏视图中可能不需要特殊处理) ---
              else {
                // 可以显示初始提示或加载状态，取决于设计
                return const Center(child: Text('正在加载或选择会话...'));
                // 或者 return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _createNewThread,
            icon: const Icon(Icons.add),
            label: const Text('新建对话'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
} 