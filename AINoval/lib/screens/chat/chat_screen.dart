import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../../models/chat_models.dart';
import '../../models/user_ai_model_config_model.dart';
import '../../utils/logger.dart';
import 'widgets/chat_input.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/context_panel.dart';
import 'widgets/typing_indicator.dart';

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
           // --- SnackBar 错误提示 ---
           if (state is ChatSessionsLoaded && state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
              );
           }
           if (state is ChatSessionActive && state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
              );
            }
           // --- 滚动逻辑 ---
          if (state is ChatSessionActive && !state.isLoadingHistory) {
            // 当新消息添加或流式更新时，滚动到底部
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        },
         // --- buildWhen 优化 ---
         buildWhen: (previous, current) {
           // 允许从加载到加载完成的状态转换
            if (previous is ChatSessionsLoading && current is ChatSessionsLoaded) return true;
            if (previous is ChatSessionsLoaded && current is ChatSessionsLoading) return true;
            if (previous is ChatSessionLoading && current is ChatSessionActive) return true;
            if (previous is ChatSessionActive && current is ChatSessionLoading) return true;
           // 允许在 ChatSessionActive 状态内部更新
            if (previous is ChatSessionActive && current is ChatSessionActive) {
              return previous.session != current.session ||
                     previous.messages.length != current.messages.length ||
                     previous.messages != current.messages || // 浅比较
                     previous.isGenerating != current.isGenerating ||
                     previous.isLoadingHistory != current.isLoadingHistory ||
                     previous.error != current.error;
            }
           // 允许在 ChatSessionsLoaded 状态内部更新
            if (previous is ChatSessionsLoaded && current is ChatSessionsLoaded) {
               return previous.sessions != current.sessions ||
                      previous.error != current.error;
            }
            // 允许错误状态和初始状态
            if (current is ChatError) return true;
            if (current is ChatInitial) return true;

             return previous.runtimeType != current.runtimeType; // 默认状态类型变化时重建
         },
        builder: (context, state) {
           AppLogger.d('ChatScreen builder', 'Building UI for state: ${state.runtimeType}');
           // --- 加载状态 ---
          if (state is ChatSessionsLoading || state is ChatSessionLoading) {
            return const Center(child: CircularProgressIndicator());
          }
           // --- 会话列表 ---
          else if (state is ChatSessionsLoaded) {
            // _buildSessionsList 会处理空列表
            return _buildSessionsList(state); // 传递整个state以便访问error
          }
           // --- 活动会话 ---
          else if (state is ChatSessionActive) {
            return _buildChatView(state);
          }
           // --- 错误状态 ---
          else if (state is ChatError) {
            return Center(
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Text('错误: ${state.message}', style: TextStyle(color: Colors.red)),
               ),
             );
          }
           // --- 初始状态 ---
          else {
            // 可以显示提示或触发加载
            // context.read<ChatBloc>().add(LoadChatSessions(novelId: widget.novelId));
            return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    const Text('选择或创建一个会话开始聊天'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _createNewSession, child: const Text('创建新会话')),
                 ],
               ),
            );
          }
        },
      ),
    );
  }
  
  // 构建会话列表 - 修改为接收 state
  Widget _buildSessionsList(ChatSessionsLoaded state) {
    final sessions = state.sessions;
    if (sessions.isEmpty) {
      // 处理空列表
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('没有聊天会话'),
            const SizedBox(height: 16),
            // 可以显示错误信息
            if (state.error != null) Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(state.error!, style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: _createNewSession,
              child: const Text('创建新会话'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 显示列表加载错误
         if (state.error != null) Padding(
           padding: const EdgeInsets.all(8.0),
           child: Text(state.error!, style: TextStyle(color: Colors.red)),
         ),
        Expanded(
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              // ListTile 内容保持不变
              return ListTile(
                title: Text(session.title),
                subtitle: Text(
                  '消息数: ${session.messageCount ?? 'N/A'} | 更新于: ${DateFormat('yyyy-MM-dd HH:mm').format(session.lastUpdatedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => _selectSession(session.id),
                  // 可以加入选中高亮
                 selected: /* Add logic to check if this session is the active one */ false,
              );
            },
          ),
        ),
      ],
    );
  }
  
  // 构建聊天视图 - 修改以处理 isLoadingHistory
  Widget _buildChatView(ChatSessionActive state) {
    // --- 获取当前会话选择的模型 ---
    // 现在可以直接从 state 获取 selectedModel
    final UserAIModelConfigModel? currentChatModel = state.selectedModel;

    return Row(
      children: [
        // 聊天主界面
        Expanded(
          flex: _isContextPanelExpanded ? 2 : 3,
          child: Column(
            children: [
               // 显示历史加载指示器
               if (state.isLoadingHistory)
                 const Padding(
                   padding: EdgeInsets.symmetric(vertical: 8.0),
                   child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                 ),
               // 显示错误信息 (如果不用SnackBar的话)
               // if (state.error != null && !state.isLoadingHistory)
               //   Padding(...),
              // 消息列表
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length + (state.isGenerating && !state.isLoadingHistory ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (state.isGenerating && !state.isLoadingHistory && index == state.messages.length) {
                      return const TypingIndicator();
                    }

                    final message = state.messages[index];
                    return ChatMessageBubble(
                      message: message,
                      onActionSelected: _executeAction,
                    );
                  },
                ),
              ),

              // --- 修改 ChatInput ---
              ChatInput(
                controller: _messageController,
                onSend: _sendMessage,
                isGenerating: state.isGenerating,
                onCancel: () {
                  context.read<ChatBloc>().add(const CancelOngoingRequest());
                },
                initialModel: currentChatModel, // 将当前会话模型传给 ChatInput
                onModelSelected: (selectedModel) {
                  if (selectedModel != null && selectedModel.id != currentChatModel?.id) {
                     // 使用正确的事件类
                    context.read<ChatBloc>().add(UpdateChatModel(
                        sessionId: state.session.id,
                        modelConfigId: selectedModel.id,
                    ));
                     AppLogger.i('ChatScreen', 'Model selected event dispatched: ${selectedModel.id} for session ${state.session.id}');
                  }
                },
              ),
            ],
          ),
        ),

        // 上下文面板逻辑保持不变
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
          // 仅在 ChatSessionsLoaded 状态下构建列表
          buildWhen: (prev, curr) => curr is ChatSessionsLoaded || curr is ChatSessionsLoading,
          builder: (context, state) {
            if (state is ChatSessionsLoaded) {
              return SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column( // Wrap ListView in Column to show error
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     // 显示错误
                     if (state.error != null) Padding(
                       padding: const EdgeInsets.only(bottom: 8.0),
                       child: Text(state.error!, style: TextStyle(color: Colors.red)),
                     ),
                    Expanded(
                      child: state.sessions.isEmpty
                       ? const Center(child: Text("没有会话")) // 处理空列表
                       : ListView.builder(
                          shrinkWrap: true, // Important inside Column
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
                                Navigator.pop(context); // Close dialog
                              },
                            );
                          },
                        ),
                    ),
                  ],
                ),
              );
            } else { // Handle ChatSessionsLoading or other states
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
              Navigator.pop(context); // Close current dialog first
              // _createNewSession will show another dialog
              _createNewSession();
            },
            child: const Text('新建会话'),
          ),
        ],
      ),
    );
  }
} 