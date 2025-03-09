import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../../models/chat_models.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/context_panel.dart';

class ChatScreen extends StatefulWidget {
  
  const ChatScreen({
    Key? key,
    required this.novelId,
    this.chapterId,
  }) : super(key: key);
  final String novelId;
  final String? chapterId;
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isContextPanelExpanded = false;
  
  @override
  void initState() {
    super.initState();
    // 加载聊天会话列表
    context.read<ChatBloc>().add(LoadChatSessions(novelId: widget.novelId));
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  // 发送消息
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      context.read<ChatBloc>().add(SendMessage(content: message));
      _messageController.clear();
      
      // 延迟滚动到底部，等待消息添加到列表
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }
  
  // 切换上下文面板
  void _toggleContextPanel() {
    setState(() {
      _isContextPanelExpanded = !_isContextPanelExpanded;
    });
  }
  
  // 创建新会话
  void _createNewSession() {
    final TextEditingController titleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新会话'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入会话标题',
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              context.read<ChatBloc>().add(CreateChatSession(
                title: value,
                novelId: widget.novelId,
                chapterId: widget.chapterId,
              ));
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              
              if (title.isNotEmpty) {
                context.read<ChatBloc>().add(CreateChatSession(
                  title: title,
                  novelId: widget.novelId,
                  chapterId: widget.chapterId,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
  
  // 选择会话
  void _selectSession(String sessionId) {
    context.read<ChatBloc>().add(SelectChatSession(sessionId: sessionId));
  }
  
  // 执行操作
  void _executeAction(MessageAction action) {
    context.read<ChatBloc>().add(ExecuteAction(action: action));
    
    // 显示操作执行提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('执行操作: ${action.label}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state is ChatSessionActive) {
              return Text(state.session.title);
            }
            return const Text('AI聊天助手');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建会话',
            onPressed: _createNewSession,
          ),
          IconButton(
            icon: Icon(_isContextPanelExpanded ? Icons.info_outline : Icons.info),
            tooltip: '上下文面板',
            onPressed: _toggleContextPanel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'sessions') {
                _showSessionsDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sessions',
                child: Text('会话列表'),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state is ChatSessionActive) {
            // 当新消息添加时，滚动到底部
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        },
        builder: (context, state) {
          if (state is ChatSessionsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ChatSessionsLoaded) {
            return _buildSessionsList(state.sessions);
          } else if (state is ChatSessionLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ChatSessionActive) {
            return _buildChatView(state);
          } else if (state is ChatError) {
            return Center(child: Text('错误: ${state.message}'));
          } else {
            return const Center(child: Text('选择或创建一个会话开始聊天'));
          }
        },
      ),
    );
  }
  
  // 构建会话列表
  Widget _buildSessionsList(List<ChatSession> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('没有聊天会话'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createNewSession,
              child: const Text('创建新会话'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return ListTile(
          title: Text(session.title),
          subtitle: Text(
            session.messages.isNotEmpty
                ? session.messages.last.content.length > 50
                    ? '${session.messages.last.content.substring(0, 50)}...'
                    : session.messages.last.content
                : '无消息',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            DateFormat('MM-dd HH:mm').format(session.lastUpdatedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () => _selectSession(session.id),
        );
      },
    );
  }
  
  // 构建聊天视图
  Widget _buildChatView(ChatSessionActive state) {
    return Row(
      children: [
        // 聊天主界面
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // 消息列表
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.session.messages.length + (state.isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 如果是最后一项且正在生成，显示打字指示器
                    if (state.isGenerating && index == state.session.messages.length) {
                      return const TypingIndicator();
                    }
                    
                    final message = state.session.messages[index];
                    return ChatMessageBubble(
                      message: message,
                      onActionSelected: _executeAction,
                    );
                  },
                ),
              ),
              
              // 输入框
              ChatInput(
                controller: _messageController,
                onSend: _sendMessage,
                isGenerating: state.isGenerating,
                onCancel: () {
                  context.read<ChatBloc>().add(const CancelOngoingRequest());
                },
              ),
            ],
          ),
        ),
        
        // 上下文面板
        if (_isContextPanelExpanded)
          Expanded(
            flex: 1,
            child: ContextPanel(
              context: state.context,
              onClose: _toggleContextPanel,
            ),
          ),
      ],
    );
  }
  
  // 显示会话列表对话框
  void _showSessionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会话列表'),
        content: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state is ChatSessionsLoaded) {
              return SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: state.sessions.length,
                  itemBuilder: (context, index) {
                    final session = state.sessions[index];
                    return ListTile(
                      title: Text(session.title),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(session.lastUpdatedAt),
                      ),
                      onTap: () {
                        _selectSession(session.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              );
            } else {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              _createNewSession();
              Navigator.pop(context);
            },
            child: const Text('新建会话'),
          ),
        ],
      ),
    );
  }
} 