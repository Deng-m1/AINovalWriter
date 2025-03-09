import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_models.dart';
import '../../repositories/chat_repository.dart';
import '../../services/context_provider.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;
  final ContextProvider contextProvider;
  
  ChatBloc({
    required this.repository, 
    required this.contextProvider,
  }) : super(ChatInitial()) {
    on<LoadChatSessions>(_onLoadChatSessions);
    on<CreateChatSession>(_onCreateChatSession);
    on<SelectChatSession>(_onSelectChatSession);
    on<SendMessage>(_onSendMessage);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<UpdateChatTitle>(_onUpdateChatTitle);
    on<ExecuteAction>(_onExecuteAction);
    on<DeleteChatSession>(_onDeleteChatSession);
    on<CancelOngoingRequest>(_onCancelRequest);
    on<UpdateChatContext>(_onUpdateChatContext);
  }
  
  Future<void> _onLoadChatSessions(LoadChatSessions event, Emitter<ChatState> emit) async {
    emit(ChatSessionsLoading());
    
    try {
      final sessions = await repository.getChatSessions(event.novelId);
      emit(ChatSessionsLoaded(sessions: sessions));
    } catch (e) {
      emit(ChatError(message: '加载聊天会话失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onCreateChatSession(CreateChatSession event, Emitter<ChatState> emit) async {
    try {
      // 创建新会话
      final newSession = await repository.createChatSession(
        title: event.title,
        novelId: event.novelId,
        chapterId: event.chapterId,
      );
      
      // 如果当前状态是已加载会话列表，更新列表
      if (state is ChatSessionsLoaded) {
        final currentState = state as ChatSessionsLoaded;
        emit(ChatSessionsLoaded(
          sessions: [...currentState.sessions, newSession],
        ));
      }
      
      // 选择新创建的会话
      add(SelectChatSession(sessionId: newSession.id));
    } catch (e) {
      emit(ChatError(message: '创建聊天会话失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onSelectChatSession(SelectChatSession event, Emitter<ChatState> emit) async {
    emit(ChatSessionLoading());
    
    try {
      final session = await repository.getChatSession(event.sessionId);
      final context = await contextProvider.getContextForSession(session);
      
      emit(ChatSessionActive(
        session: session,
        context: context,
        isGenerating: false,
      ));
    } catch (e) {
      emit(ChatError(message: '加载会话失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    if (state is ChatSessionActive) {
      final currentState = state as ChatSessionActive;
      
      // 创建用户消息
      final userMessage = ChatMessage(
        id: const Uuid().v4(),
        role: MessageRole.user,
        content: event.content,
        timestamp: DateTime.now(),
      );
      
      // 更新状态，添加用户消息并标记为生成中
      emit(currentState.copyWith(
        session: currentState.session.copyWith(
          messages: [...currentState.session.messages, userMessage],
          lastUpdatedAt: DateTime.now(),
        ),
        isGenerating: true,
      ));
      
      try {
        // 创建占位符AI消息
        final placeholderMessage = ChatMessage(
          id: const Uuid().v4(),
          role: MessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
        );
        
        // 更新状态，添加占位符消息
        final updatedState = currentState.copyWith(
          session: currentState.session.copyWith(
            messages: [...currentState.session.messages, userMessage, placeholderMessage],
            lastUpdatedAt: DateTime.now(),
          ),
          isGenerating: true,
        );
        emit(updatedState);
        
        // 发送API请求
        final response = await repository.sendMessage(
          sessionId: currentState.session.id,
          message: event.content,
          context: currentState.context,
        );
        
        // 获取最新会话状态
        final latestMessages = List<ChatMessage>.from(updatedState.session.messages);
        // 更新AI回复消息
        final aiMessageIndex = latestMessages.length - 1;
        latestMessages[aiMessageIndex] = ChatMessage(
          id: placeholderMessage.id,
          role: MessageRole.assistant,
          content: response.content,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          actions: response.actions,
        );
        
        // 更新状态，完成消息生成
        emit(ChatSessionActive(
          session: updatedState.session.copyWith(
            messages: latestMessages,
            lastUpdatedAt: DateTime.now(),
          ),
          context: currentState.context,
          isGenerating: false,
        ));
        
        // 保存会话到存储
        await repository.saveChatSession(updatedState.session.id, latestMessages);
      } catch (e) {
        // 处理错误
        final latestState = state as ChatSessionActive;
        final latestMessages = List<ChatMessage>.from(latestState.session.messages);
        
        // 如果有占位符消息，将其标记为错误
        if (latestMessages.last.role == MessageRole.assistant && 
            latestMessages.last.status == MessageStatus.pending) {
          final errorIndex = latestMessages.length - 1;
          latestMessages[errorIndex] = latestMessages[errorIndex].copyWith(
            content: '生成回复时出错: ${e.toString()}',
            status: MessageStatus.error,
          );
        }
        
        emit(ChatSessionActive(
          session: latestState.session.copyWith(
            messages: latestMessages,
          ),
          context: latestState.context,
          isGenerating: false,
          error: e.toString(),
        ));
      }
    }
  }
  
  Future<void> _onLoadMoreMessages(LoadMoreMessages event, Emitter<ChatState> emit) async {
    // 这里实现加载更多历史消息的逻辑
    // 在第二周迭代中，我们可以先简单实现，后续再优化
  }
  
  Future<void> _onUpdateChatTitle(UpdateChatTitle event, Emitter<ChatState> emit) async {
    if (state is ChatSessionActive) {
      final currentState = state as ChatSessionActive;
      
      try {
        // 更新会话标题
        final updatedSession = currentState.session.copyWith(
          title: event.newTitle,
        );
        
        // 保存到存储
        await repository.updateChatSession(updatedSession);
        
        // 更新状态
        emit(currentState.copyWith(
          session: updatedSession,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          error: '更新标题失败: ${e.toString()}',
        ));
      }
    }
  }
  
  Future<void> _onExecuteAction(ExecuteAction event, Emitter<ChatState> emit) async {
    if (state is ChatSessionActive) {
      final currentState = state as ChatSessionActive;
      
      try {
        // 根据操作类型执行不同的动作
        switch (event.action.type) {
          case ActionType.applyToEditor:
            // 应用到编辑器的逻辑
            // 这部分需要与编辑器模块交互，在第二周迭代中可以先简单实现
            break;
          case ActionType.createCharacter:
            // 创建角色的逻辑
            break;
          case ActionType.createLocation:
            // 创建地点的逻辑
            break;
          case ActionType.generatePlot:
            // 生成情节的逻辑
            break;
          case ActionType.expandScene:
            // 扩展场景的逻辑
            break;
          case ActionType.createChapter:
            // 创建章节的逻辑
            break;
          case ActionType.analyzeSentiment:
            // 分析情感的逻辑
            break;
          case ActionType.fixGrammar:
            // 修复语法的逻辑
            break;
        }
      } catch (e) {
        emit(currentState.copyWith(
          error: '执行操作失败: ${e.toString()}',
        ));
      }
    }
  }
  
  Future<void> _onDeleteChatSession(DeleteChatSession event, Emitter<ChatState> emit) async {
    try {
      // 删除会话
      await repository.deleteChatSession(event.sessionId);
      
      // 如果当前状态是已加载会话列表，更新列表
      if (state is ChatSessionsLoaded) {
        final currentState = state as ChatSessionsLoaded;
        final updatedSessions = currentState.sessions
            .where((session) => session.id != event.sessionId)
            .toList();
        
        emit(ChatSessionsLoaded(sessions: updatedSessions));
      }
    } catch (e) {
      emit(ChatError(message: '删除会话失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onCancelRequest(CancelOngoingRequest event, Emitter<ChatState> emit) async {
    if (state is ChatSessionActive && (state as ChatSessionActive).isGenerating) {
      final currentState = state as ChatSessionActive;
      
      try {
        // 取消请求
        await repository.cancelRequest(currentState.session.id);
        
        // 更新状态
        final latestMessages = List<ChatMessage>.from(currentState.session.messages);
        
        // 如果最后一条消息是AI的占位符消息，将其标记为错误
        if (latestMessages.last.role == MessageRole.assistant && 
            latestMessages.last.status == MessageStatus.pending) {
          final errorIndex = latestMessages.length - 1;
          latestMessages[errorIndex] = latestMessages[errorIndex].copyWith(
            content: '已取消生成',
            status: MessageStatus.error,
          );
        }
        
        emit(currentState.copyWith(
          session: currentState.session.copyWith(
            messages: latestMessages,
          ),
          isGenerating: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          error: '取消请求失败: ${e.toString()}',
          isGenerating: false,
        ));
      }
    }
  }
  
  Future<void> _onUpdateChatContext(UpdateChatContext event, Emitter<ChatState> emit) async {
    if (state is ChatSessionActive) {
      final currentState = state as ChatSessionActive;
      
      emit(currentState.copyWith(
        context: event.context,
      ));
    }
  }
} 