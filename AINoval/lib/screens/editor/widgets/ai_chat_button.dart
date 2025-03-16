import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/chat/chat_bloc.dart';
import '../../../blocs/chat/chat_event.dart';
import '../../../blocs/chat/chat_state.dart';

/// AI聊天按钮，用于在编辑器中打开AI聊天侧边栏
class AIChatButton extends StatelessWidget {
  const AIChatButton({
    Key? key,
    required this.novelId,
    this.chapterId,
    required this.onPressed,
    this.isActive = false,
  }) : super(key: key);

  final String novelId;
  final String? chapterId;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return IconButton(
          icon: Stack(
            children: [
              Icon(
                Icons.chat_outlined,
                color: isActive ? Colors.blue : Colors.black54,
              ),
              if (state is ChatSessionActive && state.isGenerating)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: '打开AI聊天',
          onPressed: () {
            // 如果没有活动会话，创建一个新会话
            if (state is! ChatSessionActive) {
              context.read<ChatBloc>().add(CreateChatSession(
                title: 'New Chat',
                novelId: novelId,
                chapterId: chapterId,
              ));
            }
            onPressed();
          },
        );
      },
    );
  }
} 