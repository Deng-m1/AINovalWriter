import 'package:equatable/equatable.dart';
import '../../models/chat_models.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

// 加载聊天会话列表
class LoadChatSessions extends ChatEvent {
  final String novelId;

  const LoadChatSessions({required this.novelId});

  @override
  List<Object?> get props => [novelId];
}

// 创建新的聊天会话
class CreateChatSession extends ChatEvent {
  final String title;
  final String novelId;
  final String? chapterId;

  const CreateChatSession({
    required this.title,
    required this.novelId,
    this.chapterId,
  });

  @override
  List<Object?> get props => [title, novelId, chapterId];
}

// 选择聊天会话
class SelectChatSession extends ChatEvent {
  final String sessionId;

  const SelectChatSession({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

// 发送消息
class SendMessage extends ChatEvent {
  final String content;

  const SendMessage({required this.content});

  @override
  List<Object?> get props => [content];
}

// 加载更多消息
class LoadMoreMessages extends ChatEvent {
  const LoadMoreMessages();
}

// 更新聊天标题
class UpdateChatTitle extends ChatEvent {
  final String newTitle;

  const UpdateChatTitle({required this.newTitle});

  @override
  List<Object?> get props => [newTitle];
}

// 执行操作
class ExecuteAction extends ChatEvent {
  final MessageAction action;

  const ExecuteAction({required this.action});

  @override
  List<Object?> get props => [action];
}

// 删除聊天会话
class DeleteChatSession extends ChatEvent {
  final String sessionId;

  const DeleteChatSession({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

// 取消正在进行的请求
class CancelOngoingRequest extends ChatEvent {
  const CancelOngoingRequest();
}

// 更新聊天上下文
class UpdateChatContext extends ChatEvent {
  final ChatContext context;

  const UpdateChatContext({required this.context});

  @override
  List<Object?> get props => [context];
} 