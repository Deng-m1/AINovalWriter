import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/chat/chat_bloc.dart';
import '../../../blocs/chat/chat_event.dart';
import '../../../blocs/chat/chat_state.dart';
import '../../../models/chat_models.dart';
import 'package:ainoval/utils/logger.dart';


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
  final bool _isContextPanelExpanded = false;
  String? _selectedAIModel;
  
  @override
  void initState() {
    super.initState();
    // 加载聊天会话列表
    context.read<ChatBloc>().add(LoadChatSessions(novelId: widget.novelId));
    // 默认选择通用AI模型
    _selectedAIModel = 'General Purpose';
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
  
  // 选择会话
  void _selectSession(String sessionId) {
    context.read<ChatBloc>().add(SelectChatSession(sessionId: sessionId));
  }
  
  // 创建新会话
  void _createNewThread() {
    context.read<ChatBloc>().add(CreateChatSession(
      title: 'New Thread',
      novelId: widget.novelId,
      chapterId: widget.chapterId,
    ));
  }
  
  // 选择AI模型
  void _selectAIModel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择AI模型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('General Purpose'),
              subtitle: const Text('通用AI助手'),
              selected: _selectedAIModel == 'General Purpose',
              onTap: () {
                setState(() {
                  _selectedAIModel = 'General Purpose';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Creative Writer'),
              subtitle: const Text('创意写作助手'),
              selected: _selectedAIModel == 'Creative Writer',
              onTap: () {
                setState(() {
                  _selectedAIModel = 'Creative Writer';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Plot Developer'),
              subtitle: const Text('情节发展助手'),
              selected: _selectedAIModel == 'Plot Developer',
              onTap: () {
                setState(() {
                  _selectedAIModel = 'Plot Developer';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
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
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'AI聊天助手',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
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
                  if (state is ChatSessionActive) {
                    // 当新消息添加时，滚动到底部
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  }
                },
                builder: (context, state) {
                  AppLogger.i('Screens/chat/widgets/ai_chat_sidebar', 'Building chat UI for state: $state');
                  if (state is ChatSessionsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is ChatSessionsLoaded) {
                    return _buildThreadsList(state.sessions);
                  } else if (state is ChatSessionLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is ChatSessionActive) {
                    return _buildChatView(state);
                  } else if (state is ChatError) {
                    return Center(child: Text('错误: ${state.message}'));
                  } else {
                    return _buildEmptyState();
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
          ElevatedButton(
            onPressed: _createNewThread,
            child: const Text('新建对话'),
          ),
        ],
      ),
    );
  }
  
  // 构建会话列表
  Widget _buildThreadsList(List<ChatSession> sessions) {
    return Column(
      children: [
        // 顶部标题栏
        _buildHeader('聊天'),
        
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search threads...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        
        // 新建会话按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: OutlinedButton.icon(
            onPressed: _createNewThread,
            icon: const Icon(Icons.add),
            label: const Text('New Thread'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ),
        
        // 未固定会话标题
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                'Unpinned',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${sessions.length} threads',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.keyboard_arrow_up,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
        
        // 会话列表
        Expanded(
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                title: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Chapter 1: ${session.chapterId ?? "全局"} - Scene 1',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  _formatDate(session.lastUpdatedAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
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
  Widget _buildChatView(ChatSessionActive state) {
    return Column(
      children: [
        // 顶部标题栏
        _buildChatHeader(state),
        
        // 消息列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.session.messages.length + (state.isGenerating ? 1 : 0),
            itemBuilder: (context, index) {
              // 如果是最后一项且正在生成，显示打字指示器
              if (state.isGenerating && index == state.session.messages.length) {
                return _buildTypingIndicator();
              }
              
              final message = state.session.messages[index];
              return _buildMessageBubble(message);
            },
          ),
        ),
        
        // 底部输入框
        _buildInputArea(state),
      ],
    );
  }
  
  // 构建顶部标题栏
  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  // 构建聊天标题栏
  Widget _buildChatHeader(ChatSessionActive state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<ChatBloc>().add(LoadChatSessions(novelId: widget.novelId));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.session.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _selectAIModel,
                      child: Row(
                        children: [
                          Text(
                            _selectedAIModel ?? 'General Purpose',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.pin),
            onPressed: () {},
            tooltip: 'Pin',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
            tooltip: 'More options',
          ),
        ],
      ),
    );
  }
  
  // 构建消息气泡
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == MessageRole.user;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              radius: 16,
              child: const Icon(Icons.smart_toy, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (message.actions != null && message.actions!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: message.actions!.map((action) {
                        return ActionChip(
                          label: Text(action.label),
                          onPressed: () {},
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade200,
              radius: 16,
              child: const Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
  
  // 构建打字指示器
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            radius: 16,
            child: const Icon(Icons.smart_toy, size: 20),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(1),
                _buildDot(2),
                _buildDot(3),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建打字指示器的点
  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        shape: BoxShape.circle,
      ),
    );
  }
  
  // 构建输入区域
  Widget _buildInputArea(ChatSessionActive state) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: state.isGenerating
                    ? IconButton(
                        icon: const Icon(Icons.stop),
                        onPressed: () {
                          context.read<ChatBloc>().add(const CancelOngoingRequest());
                        },
                      )
                    : null,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (!state.isGenerating) {
                  _sendMessage();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: state.isGenerating ? null : _sendMessage,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
  
  // 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
} 