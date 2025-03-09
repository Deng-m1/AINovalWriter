import 'package:equatable/equatable.dart';
import '../../models/chat_models.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

// 初始状态
class ChatInitial extends ChatState {}

// 加载会话列表中
class ChatSessionsLoading extends ChatState {}

// 会话列表加载完成
class ChatSessionsLoaded extends ChatState {

  const ChatSessionsLoaded({required this.sessions});
  final List<ChatSession> sessions;

  @override
  List<Object?> get props => [sessions];
}

// 加载单个会话中
class ChatSessionLoading extends ChatState {}

// 会话激活状态
class ChatSessionActive extends ChatState {

  const ChatSessionActive({
    required this.session,
    required this.context,
    this.isGenerating = false,
    this.error,
  });
  final ChatSession session;
  final ChatContext context;
  final bool isGenerating;
  final String? error;

  @override
  List<Object?> get props => [session, context, isGenerating, error];

  // 复制方法
  ChatSessionActive copyWith({
    ChatSession? session,
    ChatContext? context,
    bool? isGenerating,
    String? error,
  }) {
    return ChatSessionActive(
      session: session ?? this.session,
      context: context ?? this.context,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error ?? this.error,
    );
  }
}

// 错误状态
class ChatError extends ChatState {

  const ChatError({required this.message});
  final String message;

  @override
  List<Object?> get props => [message];
} 