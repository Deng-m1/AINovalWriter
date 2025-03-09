import 'package:flutter/material.dart';

/// 聊天边栏组件，用于在编辑器左侧显示聊天功能
class ChatSidebar extends StatefulWidget {
  final String novelId;
  final String? chapterId;
  
  const ChatSidebar({
    Key? key,
    required this.novelId,
    this.chapterId,
  }) : super(key: key);
  
  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  // 模拟聊天会话数据
  final List<Map<String, dynamic>> _mockSessions = [
    {
      'id': '1',
      'title': '关于角色设计的讨论',
      'lastMessage': '我认为主角的动机需要更加明确',
      'lastUpdated': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': '2',
      'title': '情节发展建议',
      'lastMessage': '第二幕的冲突可以更加激烈',
      'lastUpdated': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'id': '3',
      'title': '世界观设定',
      'lastMessage': '魔法系统的规则需要更加一致',
      'lastUpdated': DateTime.now().subtract(const Duration(days: 3)),
    },
  ];
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索对话...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        
        // 会话列表
        Expanded(
          child: ListView.builder(
            itemCount: _mockSessions.length,
            itemBuilder: (context, index) {
              final session = _mockSessions[index];
              return ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  session['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  session['lastMessage'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatDate(session['lastUpdated']),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  // 打开会话
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('打开会话: ${session['title']}')),
                  );
                },
              );
            },
          ),
        ),
        
        // 新建会话按钮
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              // 创建新会话
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('创建新会话')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('新建对话'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ),
      ],
    );
  }
  
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