import 'package:ainoval/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // 引入 intl 包用于日期格式化

import '../../../blocs/chat/chat_bloc.dart';
import '../../../blocs/chat/chat_event.dart';
import '../../../blocs/chat/chat_state.dart';
import '../../../models/chat_models.dart';
import 'chat_message_bubble.dart'; // 引入 ChatMessageBubble
import 'chat_input.dart'; // 引入 ChatInput
import 'typing_indicator.dart'; // 引入 TypingIndicator



/// AI聊天侧边栏组件，用于在编辑器右侧显示聊天功能
class AIChatSidebar extends StatefulWidget {
  const AIChatSidebar({
    Key? key,
    required this.novelId,
    this.chapterId,
    this.onClose,
  }) : super(key: key);
  
  final String novelId;
  final String? chapterId;
  final VoidCallback? onClose;

  @override
  State<AIChatSidebar> createState() => _AIChatSidebarState();
}

class _AIChatSidebarState extends State<AIChatSidebar> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    // --- Add initState Log ---
    AppLogger.i('AIChatSidebar', 'initState called. Widget hash: ${identityHashCode(widget)}, State hash: ${identityHashCode(this)}');
    // Get the Bloc instance WITHOUT triggering a rebuild if already present
    final chatBloc = BlocProvider.of<ChatBloc>(context, listen: false);
    AppLogger.i('AIChatSidebar', 'initState: Associated ChatBloc hash: ${identityHashCode(chatBloc)}');
    // --- End Add Log ---
    // Only add LoadChatSessions if the state isn't already loaded or loading
    if (chatBloc.state is ChatInitial) {
       chatBloc.add(LoadChatSessions(novelId: widget.novelId));
    }
  }
  
  @override
  void dispose() {
    // --- Add dispose Log ---
    AppLogger.w('AIChatSidebar', 'dispose() called. Widget hash: ${identityHashCode(widget)}, State hash: ${identityHashCode(this)}');
    // --- End Add Log ---
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    });
  }
  
  // 发送消息
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      context.read<ChatBloc>().add(SendMessage(content: message));
      _messageController.clear();
    }
  }
  
  // 选择会话
  void _selectSession(String sessionId) {
    context.read<ChatBloc>().add(SelectChatSession(sessionId: sessionId));
  }
  
  // 创建新会话
  void _createNewThread() {
    context.read<ChatBloc>().add(CreateChatSession(
      title: '新对话 ${DateFormat('MM-dd HH:mm').format(DateTime.now())}',
      novelId: widget.novelId,
      chapterId: widget.chapterId,
    ));
  }
  
  @override
  Widget build(BuildContext context) {
    // Log the associated Bloc hash on build too, might be helpful
    final chatBloc = BlocProvider.of<ChatBloc>(context, listen: false);
    AppLogger.d('AIChatSidebar', 'build called. Associated ChatBloc hash: ${identityHashCode(chatBloc)}');
    AppLogger.i('Screens/chat/widgets/ai_chat_sidebar', 'Building AIChatSidebar widget');
    return Material(
      elevation: 8.0,
      child: Container(
        width: 400,
        color: Colors.white,
        child: Column(
          children: [
            // 顶部标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      String title = 'AI 聊天助手';
                      if (state is ChatSessionActive) {
                        title = state.session.title;
                      } else if (state is ChatSessionsLoaded) {
                        title = '聊天列表';
                      }
                      return Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  const Spacer(),
                  BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      if (state is ChatSessionActive) {
                        return IconButton(
                          icon: const Icon(Icons.list),
                          tooltip: '返回列表',
                          onPressed: () {
                            context.read<ChatBloc>().add(LoadChatSessions(novelId: widget.novelId));
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                    tooltip: '关闭侧边栏',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // 聊天内容区域
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  AppLogger.i('Screens/chat/widgets/ai_chat_sidebar', 'ChatBloc state changed: $state');
                  // 显示会话加载错误
                  if (state is ChatSessionsLoaded && state.error != null) {
                     ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
                     );
                  }
                  // 显示活动会话错误（例如加载历史失败或发送失败后）
                  if (state is ChatSessionActive && state.error != null) {
                     ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
                     );
                  }
                  // 滚动到底部逻辑保持不变
                  if (state is ChatSessionActive && !state.isLoadingHistory) { // 仅在历史加载完成后滚动
                      _scrollToBottom();
                  }
                },
                // buildWhen 优化：避免不必要的重建，例如仅在关键状态或错误变化时重建
                buildWhen: (previous, current) {
                    if (previous is ChatSessionsLoading && current is ChatSessionsLoaded) return true;
                    if (previous is ChatSessionsLoaded && current is ChatSessionsLoading) return true; // 从列表返回加载
                    if (previous is ChatSessionLoading && current is ChatSessionActive) return true;
                    if (previous is ChatSessionActive && current is ChatSessionLoading) return true; // 从活动返回加载
                    if (previous is ChatSessionActive && current is ChatSessionsLoaded) return true; // 从活动返回列表
                    if (current is ChatInitial) return true; // 返回初始状态
                    if (current is ChatError) return true; // 显示错误

                    // 如果是 ChatSessionActive 状态更新，检查关键字段是否变化
                    if (previous is ChatSessionActive && current is ChatSessionActive) {
                       return previous.session != current.session ||
                              previous.messages.length != current.messages.length || // 消息数量变化
                              previous.messages != current.messages || // 消息内容或状态变化 (浅比较)
                              previous.isGenerating != current.isGenerating ||
                              previous.isLoadingHistory != current.isLoadingHistory ||
                              previous.error != current.error;
                    }
                    // 如果是 ChatSessionsLoaded 状态更新，检查关键字段是否变化
                     if (previous is ChatSessionsLoaded && current is ChatSessionsLoaded) {
                       return previous.sessions != current.sessions ||
                              previous.error != current.error;
                    }
                    return false; // 默认不重建
                },
                builder: (context, state) {
                  AppLogger.i('Screens/chat/widgets/ai_chat_sidebar', 'Building chat UI for state: ${state.runtimeType}');
                  // --- 加载状态处理 ---
                  if (state is ChatSessionsLoading || state is ChatSessionLoading) {
                    AppLogger.d('AIChatSidebar builder', 'State is Loading, showing indicator.');
                    return const Center(child: CircularProgressIndicator());
                  }
                  // --- 错误状态处理 ---
                  else if (state is ChatError) {
                     AppLogger.d('AIChatSidebar builder', 'State is ChatError, showing error message.');
                    return Center(
                       child: Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Text('错误: ${state.message}', style: TextStyle(color: Colors.red)),
                       ),
                    );
                  }
                  // --- 会话列表状态 ---
                  else if (state is ChatSessionsLoaded) {
                     AppLogger.d('AIChatSidebar builder', 'State is ChatSessionsLoaded with ${state.sessions.length} sessions.');
                    return _buildThreadsList(context, state); // _buildThreadsList 会处理空列表
                  }
                  // --- 活动会话状态 ---
                  else if (state is ChatSessionActive) {
                    AppLogger.d('AIChatSidebar builder', 'State is ChatSessionActive. isLoadingHistory: ${state.isLoadingHistory}, isGenerating: ${state.isGenerating}');
                    return _buildChatView(context, state);
                  }
                  // --- 初始或其他状态 ---
                  else {
                    AppLogger.d('AIChatSidebar builder', 'State is Initial or unexpected, showing empty state.');
                    // 初始状态可以显示空状态或者加载列表
                    // context.read<ChatBloc>().add(LoadChatSessions(novelId: widget.novelId)); // 如果希望初始时自动加载
                    return _buildEmptyState(); // 或者 return const Center(child: CircularProgressIndicator()); 看设计需求
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '开始一个新的对话',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '与AI助手交流，获取写作灵感和建议',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createNewThread,
            icon: const Icon(Icons.add),
            label: const Text('新建对话'),
          ),
        ],
      ),
    );
  }
  
  // 构建会话列表
  Widget _buildThreadsList(BuildContext context, ChatSessionsLoaded state) {
    // 现在接收整个 state 以便访问 error
    final sessions = state.sessions;

    if (sessions.isEmpty) {
      // 即使列表为空，也不显示加载，显示空状态
      return _buildEmptyState();
    }
    return Column(
      children: [
        // 新建对话按钮 (保持不变)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: OutlinedButton.icon(
            onPressed: _createNewThread,
            icon: const Icon(Icons.add),
            label: const Text('新建对话'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            ),
          ),
        ),
        // 列表视图 (保持不变)
        Expanded(
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              // ListTile 内容 和 删除逻辑 保持不变
              return ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                   '更新于: ${DateFormat('MM-dd HH:mm').format(session.lastUpdatedAt)}',
                   style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text('确认删除'),
                            content: Text('确定要删除会话 "${session.title}" 吗？此操作无法撤销。'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('取消'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                              TextButton(
                                child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                onPressed: () {
                                  context.read<ChatBloc>().add(DeleteChatSession(sessionId: session.id));
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    tooltip: '删除会话',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                onTap: () => _selectSession(session.id),
              );
            },
          ),
        ),
      ],
    );
  }
  
  // 构建聊天视图
  Widget _buildChatView(BuildContext context, ChatSessionActive state) {
    return Column(
      children: [
        // 显示历史加载指示器
        if (state.isLoadingHistory)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 8.0),
             child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
           ),
        // 显示加载历史或发送消息时的错误信息（如果需要更持久的提示）
        // if (state.error != null)
        //   Padding(
        //     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        //     child: Text(state.error!, style: TextStyle(color: Colors.red)),
        //   ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            // itemCount 保持不变
            itemCount: state.messages.length + (state.isGenerating && !state.isLoadingHistory ? 1 : 0), // 只有在非加载历史时才显示打字指示器
            itemBuilder: (context, index) {
              // 打字指示器逻辑保持不变，并增加 isLoadingHistory 判断
              if (state.isGenerating && !state.isLoadingHistory && index == state.messages.length) {
                return const TypingIndicator();
              }

              final message = state.messages[index];
              // ChatMessageBubble 逻辑保持不变
              return ChatMessageBubble(
                message: message,
                onActionSelected: (action) {
                  context.read<ChatBloc>().add(ExecuteAction(action: action));
                },
              );
            },
          ),
        ),
        // ChatInput 逻辑保持不变
        ChatInput(
              controller: _messageController,
              onSend: _sendMessage,
              isGenerating: state.isGenerating,
              onCancel: () {
                  context.read<ChatBloc>().add(const CancelOngoingRequest());
              },
        ),
      ],
    );
  }
} 