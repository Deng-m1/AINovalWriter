import 'dart:async';

import 'package:ainoval/services/api_service/repositories/impl/chat_repository_impl.dart';
import 'package:ainoval/services/api_service/repositories/chat_repository.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_models.dart';

import '../../services/auth_service.dart';
import '../../services/context_provider.dart';
import '../../utils/logger.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import '../../config/app_config.dart';
import '../ai_config/ai_config_bloc.dart';
import '../../models/user_ai_model_config_model.dart';
import 'package:collection/collection.dart';



class ChatBloc extends Bloc<ChatEvent, ChatState> {
  
  ChatBloc({
    required this.repository, 
    required this.contextProvider,
    required this.authService,
    required AiConfigBloc aiConfigBloc,
  }) : _userId = AppConfig.userId ?? '',
       _aiConfigBloc = aiConfigBloc,
       super(ChatInitial()) {
    AppLogger.i('ChatBloc', 'Constructor called. Instance hash: ${identityHashCode(this)}');
    on<LoadChatSessions>(_onLoadChatSessions, transformer: restartable());
    on<CreateChatSession>(_onCreateChatSession);
    on<SelectChatSession>(_onSelectChatSession);
    on<SendMessage>(_onSendMessage, transformer: sequential());
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<UpdateChatTitle>(_onUpdateChatTitle);
    on<ExecuteAction>(_onExecuteAction);
    on<DeleteChatSession>(_onDeleteChatSession);
    on<CancelOngoingRequest>(_onCancelRequest);
    on<UpdateChatContext>(_onUpdateChatContext);
    on<UpdateChatModel>(_onUpdateChatModel);
  }
  final ChatRepository repository;
  final ContextProvider contextProvider;
  final AuthService authService;
  final String _userId;
  final AiConfigBloc _aiConfigBloc;
  
  // 用于跟踪活动的流订阅，以便可以取消它们
  // StreamSubscription? _sessionsSubscription;
  // StreamSubscription? _messagesSubscription;
  // 用于取消正在进行的消息生成请求
  StreamSubscription? _sendMessageSubscription;

  @override
  Future<void> close() {
    AppLogger.w('ChatBloc', 'close() method called! Disposing ChatBloc and cancelling subscriptions. Instance hash: ${identityHashCode(this)}');
    // _sessionsSubscription?.cancel();
    // _messagesSubscription?.cancel();
    _sendMessageSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadChatSessions(LoadChatSessions event, Emitter<ChatState> emit) async {
    AppLogger.i('ChatBloc', '[Event Start] _onLoadChatSessions for novel ${event.novelId}');
    emit(ChatSessionsLoading());

    final List<ChatSession> sessions = []; // 不再需要局部变量
    try {
      // 假设 fetchUserSessions 返回 Stream<ChatSession>
      final stream = repository.fetchUserSessions(_userId);
      // 使用 await emit.forEach 处理流
      await emit.forEach<ChatSession>(
        stream,
        onData: (session) {
          sessions.add(session);
          // 返回当前状态，直到流结束
          emit(ChatSessionsLoading());
          return ChatSessionsLoaded(sessions: List.of(sessions));
          //return state; // 保持 Loading 状态直到完成
        },
        onError: (error, stackTrace) {
          AppLogger.e('ChatBloc', '_onLoadChatSessions stream error', error, stackTrace);
          // 在 onError 中直接返回错误状态
          final errorMessage = '加载会话列表失败: ${ApiExceptionHelper.fromException(error, "加载会话流出错").message}';
          return ChatSessionsLoaded(sessions: sessions, error: errorMessage);
        },
      );
      // // ---------- 修改开始 ----------
      // // 使用 toList() 收集流的所有结果，替代 emit.forEach
      // final List<ChatSession> sessions = await stream.toList(); // 等待流完成并将所有项收集到列表

      AppLogger.i('ChatBloc', '[Stream Complete] _onLoadChatSessions collected ${sessions.length} sessions.');

      // 检查 BLoC 是否关闭
      if (!isClosed && !emit.isDone) {
          emit(ChatSessionsLoaded(sessions: sessions));
      } else {
         AppLogger.w('ChatBloc', '[Emit Check] BLoC/Emitter closed before emitting final ChatSessionsLoaded.');
      }
      // ---------- 修改结束 ----------

    } catch (e, stackTrace) {
      AppLogger.e('ChatBloc', 'Failed to load chat sessions (stream error or other)', e, stackTrace);
       // 检查 BLoC 是否关闭
      if (!isClosed && !emit.isDone) {
          final errorMessage = '加载会话列表时发生错误: ${ApiExceptionHelper.fromException(e, "加载会话列表出错").message}';
          // 错误发生时，我们没有部分列表，所以 sessions 参数为空
          emit(ChatSessionsLoaded(sessions: const [], error: errorMessage)); // 返回空列表和错误
      }
    } finally {
      // 修改 finally 中的日志级别
      AppLogger.i('ChatBloc', '[Event End] _onLoadChatSessions complete.'); // 使用 INFO 级别
    }
  }
  
  Future<void> _onCreateChatSession(CreateChatSession event, Emitter<ChatState> emit) async {
    AppLogger.d('ChatBloc', '[Event Start] _onCreateChatSession');
    if (isClosed) { AppLogger.e('ChatBloc','Event started but BLoC closed.'); return; }
    try {
      final newSession = await repository.createSession(
        userId: _userId,
        novelId: event.novelId,
        metadata: {
          'title': event.title,
          if(event.chapterId != null) 'chapterId': event.chapterId
        },
      );

      // 优化：如果当前是列表状态，直接更新；否则重新加载
      if (state is ChatSessionsLoaded) {
         final currentState = state as ChatSessionsLoaded;
         final updatedSessions = List<ChatSession>.from(currentState.sessions)..add(newSession);
         // 更新列表，并清除可能存在的错误
         emit(currentState.copyWith(sessions: updatedSessions, clearError: true));
         AppLogger.d('ChatBloc', '_onCreateChatSession updated existing list.');
         // 创建后立即选中
         add(SelectChatSession(sessionId: newSession.id));
      } else {
        // 如果不是列表状态（例如初始状态、错误状态或活动会话状态），触发重新加载
        AppLogger.d('ChatBloc', '_onCreateChatSession triggering LoadChatSessions.');
        add(LoadChatSessions(novelId: event.novelId));
        // 在重新加载后，UI 将自然地显示新会话
        // 如果需要加载后自动选中，需要在 LoadChatSessions 成功后处理
      }

      AppLogger.d('ChatBloc', '[Event End] _onCreateChatSession successful.');

    } catch (e, stackTrace) {
       AppLogger.e('ChatBloc', '[Event Error] _onCreateChatSession failed.', e, stackTrace);
       if (!isClosed && !emit.isDone) {
           final errorMessage = '创建聊天会话失败: ${ApiExceptionHelper.fromException(e, "创建会话出错").message}';
            // 尝试在当前状态上显示错误
           if (state is ChatSessionsLoaded) {
             emit((state as ChatSessionsLoaded).copyWith(error: errorMessage, clearError: false));
           } else if (state is ChatSessionActive) {
             emit((state as ChatSessionActive).copyWith(error: errorMessage, clearError: false));
           } else {
             emit(ChatError(message: errorMessage));
           }
       }
    }
  }
  
  Future<void> _onSelectChatSession(SelectChatSession event, Emitter<ChatState> emit) async {
    AppLogger.d('ChatBloc', '[Event Start] _onSelectChatSession for session ${event.sessionId}');
    if (isClosed) { AppLogger.e('ChatBloc','Event started but BLoC closed.'); return; }

    // 取消之前的消息订阅和生成请求
    // await _messagesSubscription?.cancel(); // 由 emit.forEach 管理，无需手动取消
    await _sendMessageSubscription?.cancel();
    _sendMessageSubscription = null;

    emit(ChatSessionLoading());
    AppLogger.d('ChatBloc', '_onSelectChatSession emitted ChatSessionLoading');

    try {
      // 1. 获取会话详情
      final session = await repository.getSession(_userId, event.sessionId);
      // 2. 获取上下文
      final context = await contextProvider.getContextForSession(session);
      // 3. 解析选中的模型
      UserAIModelConfigModel? selectedModel;
      final aiState = _aiConfigBloc.state;
      
      if (aiState.configs.isNotEmpty) {
          if (session.selectedModelConfigId != null) {
              selectedModel = aiState.configs.firstWhereOrNull(
                 (config) => config.id == session.selectedModelConfigId,
              );
          }
          if (selectedModel == null) {
              selectedModel = aiState.defaultConfig;
          }
      } else {
         AppLogger.w('ChatBloc', '_onSelectChatSession: AiConfigBloc state does not have configs loaded.');
      }

      // 4. 发出初始 Activity 状态，标记正在加载历史
      emit(ChatSessionActive(
         session: session,
         context: context,
         selectedModel: selectedModel,
         messages: const [], // 初始空列表
         isGenerating: false,
         isLoadingHistory: true, // 标记正在加载历史
      ));
      AppLogger.d('ChatBloc', '_onSelectChatSession emitted initial ChatSessionActive (loading history)');

       // 5. 使用 await emit.forEach 加载消息历史
      final List<ChatMessage> messages = [];
      // 假设 getMessageHistory 返回 Stream<ChatMessage>
      final messageStream = repository.getMessageHistory(_userId, event.sessionId);

      AppLogger.d('ChatBloc', '_onSelectChatSession starting message history processing...');
      await emit.forEach<ChatMessage>(
        messageStream,
        onData: (message) {
           messages.add(message);
           // 返回当前状态，直到流结束
           // 如果希望流式更新消息，可以在这里 emit 更新后的 ChatSessionActive
          //  final currentState = state;
          //  if (currentState is ChatSessionActive && currentState.session.id == event.sessionId) {
          //      return currentState.copyWith(messages: List.of(messages));
          //  }
           return state; // 保持 Activity 状态
        },
        onError: (error, stackTrace) {
          AppLogger.e('ChatBloc', 'Error loading message history stream', error, stackTrace);
          // 在 onError 时，发出包含错误信息的状态，并停止加载历史
          final currentState = state;
          final errorMessage = '加载消息历史失败: ${_formatApiError(error, "加载历史出错")}';
          if (currentState is ChatSessionActive && currentState.session.id == event.sessionId) {
              if (!isClosed && !emit.isDone) {
                return currentState.copyWith(
                    isLoadingHistory: false,
                    error: errorMessage,
                    clearError: false,
                 );
              }
          }
          // Fallback error
          if (!isClosed && !emit.isDone) {
              return ChatError(message: errorMessage);
          }
           // 如果 emit 已关闭，无法发出状态，返回默认状态或 null (forEach 会处理)
          return state;
        },
      );

       // 当 forEach 成功完成 (流结束) 时，发出最终状态
       AppLogger.i('ChatBloc', '[Callback] _onSelectChatSession message history stream onDone. ${messages.length} messages.');
      // 再次检查 BLoC 和 emitter 状态，并确认当前会话仍然是目标会话
      final finalState = state;
      if (!isClosed && !emit.isDone && finalState is ChatSessionActive && finalState.session.id == event.sessionId) {
          emit(finalState.copyWith(
              messages: messages,
              isLoadingHistory: false, // 标记历史加载完成
              clearError: true, // 清除之前的错误（如果有）
          ));
          AppLogger.d('ChatBloc', '[History onDone Check] PASSED. Emitted final history.');
      } else {
          AppLogger.w('ChatBloc', '[History onDone Check] State changed, BLoC/Emitter closed, or state type mismatch. Ignoring emit.');
      }

    } catch (e, stackTrace) {
       AppLogger.e('ChatBloc', '[Event Error] _onSelectChatSession (initial get failed).', e, stackTrace);
       if (!isClosed && !emit.isDone) {
          final errorMessage = '加载会话失败: ${_formatApiError(e, "加载会话信息出错")}';
          emit(ChatError(message: errorMessage));
       }
    }
    AppLogger.d('ChatBloc', '[Event End Setup] _onSelectChatSession setup complete.');
  }
  
  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    if (state is ChatSessionActive) {
    final currentState = state as ChatSessionActive;

    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      sessionId: currentState.session.id,
      role: MessageRole.user,
      content: event.content,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    
      ChatMessage? placeholderMessage;

      try {
         placeholderMessage = ChatMessage(
            id: const Uuid().v4(),
         sessionId: currentState.session.id,
         role: MessageRole.assistant,
           content: '',
         timestamp: DateTime.now(),
           status: MessageStatus.pending,
       );

        // 在发起请求前，先更新UI，添加用户消息和占位符
       emit(currentState.copyWith(
          messages: [...currentState.messages, userMessage, placeholderMessage],
          isGenerating: true,
          error: null, // 清除之前的错误（如果有）
        ));

        // 现在发起流式请求
        await _handleStreamedResponse(emit, placeholderMessage.id, event.content);

      } catch (e, stackTrace) {
        AppLogger.e('ChatBloc', '发送消息失败 (在调用 _handleStreamedResponse 之前或期间出错)', e, stackTrace);
        // 确保在错误发生时也能更新状态
        if (state is ChatSessionActive) {
            final errorState = state as ChatSessionActive;
            final errorMessages = List<ChatMessage>.from(errorState.messages);

            // 如果 placeholder 存在于列表中，标记为错误
            if (placeholderMessage != null) {
                final errorIndex = errorMessages.indexWhere((msg) => msg.id == placeholderMessage!.id);
                if (errorIndex != -1) {
                    errorMessages[errorIndex] = errorMessages[errorIndex].copyWith(
                        content: '生成回复时出错: ${ApiExceptionHelper.fromException(e, "发送消息失败").message}', // 使用辅助方法
                        status: MessageStatus.error,
                    );
                    emit(errorState.copyWith(
                        messages: errorMessages,
                        isGenerating: false, // 即使出错也要停止生成状态
                        error: ApiExceptionHelper.fromException(e, "发送消息失败").message, // 使用辅助方法
                    ));
               } else {
                     // 如果 placeholder 不在列表里（理论上不应该发生，除非状态更新逻辑有问题）
                     AppLogger.w('ChatBloc', '未找到ID为 ${placeholderMessage.id} 的占位符消息标记错误');
                     emit(errorState.copyWith(
                        isGenerating: false,
                        error: ApiExceptionHelper.fromException(e, "发送消息失败").message, // 使用辅助方法
                    ));
                }
               } else {
                 // 如果 placeholder 尚未创建就出错
                 emit(errorState.copyWith(
                    isGenerating: false,
                    error: ApiExceptionHelper.fromException(e, "发送消息失败").message, // 使用辅助方法
                ));
            }
        }
      }
    }
  }
  
  Future<void> _onLoadMoreMessages(LoadMoreMessages event, Emitter<ChatState> emit) async {
    // TODO: 实现加载更多历史消息的逻辑
    // 需要修改 repository.getMessageHistory 以支持分页或 "before" 参数
    // 然后将获取到的旧消息插入到当前消息列表的前面
    AppLogger.w('ChatBloc', '_onLoadMoreMessages 尚未实现');
  }
  
  Future<void> _onUpdateChatTitle(UpdateChatTitle event, Emitter<ChatState> emit) async {
    if (state is ChatSessionActive) {
      final currentState = state as ChatSessionActive;
      
      try {
        final updatedSession = await repository.updateSession(
            userId: _userId,
            sessionId: currentState.session.id,
            updates: {'title': event.newTitle},
        );
        
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
    List<ChatSession>? previousSessions;
    if (state is ChatSessionsLoaded) {
        previousSessions = (state as ChatSessionsLoaded).sessions;
    } else if (state is ChatSessionActive) {
        // 如果从活动会话删除，我们可能没有完整的列表状态，但可以尝试保留
        // 这里简化处理，不保留列表
    }

    try {
      await repository.deleteSession(_userId, event.sessionId);

      // 从状态中移除会话
      if (previousSessions != null) {
        final updatedSessions = previousSessions
            .where((session) => session.id != event.sessionId)
            .toList();
        emit(ChatSessionsLoaded(sessions: updatedSessions));
      } else {
         // 如果之前不是列表状态，或当前活动会话被删除，回到初始状态
         // 让UI决定是否需要重新加载列表
         emit(ChatInitial());
      }
    } catch (e, stackTrace) { // 添加 stackTrace
       AppLogger.e('ChatBloc', '删除会话失败', e, stackTrace);
       // 无法在 ChatSessionsLoaded 添加错误，改为发出 ChatError
       // 保留之前的状态可能导致UI不一致
       final errorMessage = '删除会话失败: ${ApiExceptionHelper.fromException(e, "删除会话出错").message}';
       // 尝试在当前状态显示错误，如果不行就发 ChatError
       if (state is ChatSessionsLoaded) {
         // 现在可以使用 copyWith 来在 ChatSessionsLoaded 状态下显示错误
         final currentState = state as ChatSessionsLoaded;
          // 在保留现有列表的同时添加错误消息
          emit(currentState.copyWith(error: errorMessage));
       } else if (state is ChatSessionActive) {
            emit((state as ChatSessionActive).copyWith(error: errorMessage));
       } else {
         // 如果是其他状态，发出全局错误
         emit(ChatError(message: errorMessage));
       }
    }
  }
  
  Future<void> _onCancelRequest(CancelOngoingRequest event, Emitter<ChatState> emit) async {
    // await _sessionsSubscription?.cancel(); // 已移除
    // await _messagesSubscription?.cancel(); // 已移除
    await _sendMessageSubscription?.cancel();
    _sendMessageSubscription = null; // 清理引用

    if (state is ChatSessionActive && (state as ChatSessionActive).isGenerating) {
      final currentState = state as ChatSessionActive;
      AppLogger.w('ChatBloc', '取消请求 - 更新UI状态');

      final latestMessages = List<ChatMessage>.from(currentState.messages);
      final lastPendingIndex = latestMessages.lastIndexWhere((msg) =>
         msg.role == MessageRole.assistant &&
         (msg.status == MessageStatus.pending || msg.status == MessageStatus.streaming) // 包含 streaming 状态
      );

       if (lastPendingIndex != -1) {
          latestMessages[lastPendingIndex] = latestMessages[lastPendingIndex].copyWith(
             status: MessageStatus.error,
             content: latestMessages[lastPendingIndex].content.isEmpty
                  ? "[已取消]"
                  : "${latestMessages[lastPendingIndex].content}\n[已取消]",
          );
           emit(currentState.copyWith(
             messages: latestMessages,
             isGenerating: false,
           ));
       } else {
           emit(currentState.copyWith(isGenerating: false));
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

  // 修改：处理流式响应的辅助方法，接收 placeholderId
  // 使用 await emit.forEach 重构
  Future<void> _handleStreamedResponse(Emitter<ChatState> emit, String placeholderId, String userContent) async {
    // --- Initial state check ---
    if (state is! ChatSessionActive) {
      AppLogger.e('ChatBloc', '_handleStreamedResponse called while not in ChatSessionActive state');
      // Cannot proceed without active state, emit error if possible
      // Emitter might be closed here already if called incorrectly, so check
      if (!emit.isDone) {
        try {
          emit(ChatError(message: '内部错误: 无法在非活动会话中处理流'));
        } catch (e) { AppLogger.e('ChatBloc', 'Failed to emit error state', e); }
      }
      return;
    }
    // Capture initial state specifics
    final initialState = state as ChatSessionActive;
    final currentSessionId = initialState.session.id;
    final initialRole = MessageRole.assistant;

    StringBuffer contentBuffer = StringBuffer();

    try {
      final stream = repository.streamMessage(
        userId: _userId,
        sessionId: currentSessionId,
        content: userContent,
        // Pass configId if needed:
        // configId: initialState.selectedModel?.id,
      );

      // --- Use await emit.forEach ---
      await emit.forEach<ChatMessage>(
        stream,
        onData: (chunk) {
          // --- Per-chunk state validation ---
          // Get the absolute latest state *inside* onData
          final currentState = state;
          // Check if state is still valid *for this operation*
          if (currentState is! ChatSessionActive || currentState.session.id != currentSessionId) {
            AppLogger.w('ChatBloc', 'emit.forEach onData: State changed during stream processing. Stopping.');
            // Throwing an error here will exit emit.forEach and go to the outer catch block
            throw StateError('Chat session changed during streaming');
          }
          // --- State is valid, proceed ---

          contentBuffer.write(chunk.content);

          final latestMessages = List<ChatMessage>.from(currentState.messages);
          final aiMessageIndex = latestMessages.indexWhere((msg) => msg.id == placeholderId);

          if (aiMessageIndex != -1) {
            final updatedStreamingMessage = ChatMessage(
              id: placeholderId, // Keep placeholder ID
              role: initialRole,
              content: contentBuffer.toString(),
              timestamp: DateTime.now(),
              status: MessageStatus.streaming,
              sessionId: currentSessionId,
              userId: _userId,
              novelId: currentState.session.novelId,
              metadata: chunk.metadata ?? latestMessages[aiMessageIndex].metadata, // Merge metadata?
              actions: chunk.actions ?? latestMessages[aiMessageIndex].actions,     // Merge actions?
            );
            latestMessages[aiMessageIndex] = updatedStreamingMessage;

            // Return the *new state* to be emitted by forEach
            return currentState.copyWith(
              messages: latestMessages,
              isGenerating: true, // Still generating
            );
          } else {
            AppLogger.w('ChatBloc', '_handleStreamedResponse: 未找到ID为 $placeholderId 的占位符进行流式更新');
            // Cannot continue if placeholder lost, throw error to exit
            throw StateError('Placeholder message lost during streaming');
          }
        },
        onError: (error, stackTrace) {
          // This onError is for the *stream itself* having an error
          AppLogger.e('ChatBloc', 'Stream error in emit.forEach', error, stackTrace);
          final currentState = state; // Get state at the time of error
          final errorMessage = ApiExceptionHelper.fromException(error, "流处理失败").message;
          if (currentState is ChatSessionActive && currentState.session.id == currentSessionId) {
            // Return the error state to be emitted by forEach
            return currentState.copyWith(
              messages: _markPlaceholderAsError(currentState.messages, placeholderId, contentBuffer.toString(), errorMessage),
              isGenerating: false,
              error: errorMessage,
              clearError: false,
            );
          }
          // If state changed before stream error, return a generic error state
          return ChatError(message: errorMessage);
        },
      );

      // ---- Stream finished successfully (await emit.forEach completed without error) ----
      // Get final state AFTER the loop finishes
      final finalState = state;
      if (finalState is ChatSessionActive && finalState.session.id == currentSessionId) {
          final latestMessages = List<ChatMessage>.from(finalState.messages);
          final aiMessageIndex = latestMessages.indexWhere((msg) => msg.id == placeholderId);

          if (aiMessageIndex != -1) {
               final finalMessage = ChatMessage(
                   id: placeholderId, // Keep placeholder ID
                   role: initialRole,
                   content: contentBuffer.toString(), // Final content
                   timestamp: DateTime.now(), // Final timestamp
                   status: MessageStatus.sent, // Final status: sent
                   sessionId: currentSessionId,
                   userId: _userId,
                   novelId: finalState.session.novelId,
                   // Use latest known metadata/actions before finalizing
                   metadata: latestMessages[aiMessageIndex].metadata,
                   actions: latestMessages[aiMessageIndex].actions,
               );
               latestMessages[aiMessageIndex] = finalMessage;

               // Emit the final state explicitly after the loop
               emit(finalState.copyWith(
                   messages: latestMessages,
                   isGenerating: false, // Generation complete
                   clearError: true, // Clear any previous non-fatal errors shown during streaming
               ));
          } else {
               AppLogger.w('ChatBloc', '_handleStreamedResponse (onDone): 未找到ID为 $placeholderId 进行最终更新');
               if (finalState.isGenerating) {
                    emit(finalState.copyWith(isGenerating: false)); // Ensure generating stops
               }
          }
      } else {
           AppLogger.w('ChatBloc', 'Stream completed, but state changed or invalid. Final update skipped.');
              // If the state changed BUT we were generating, make sure to stop it
             if (state is ChatSessionActive && (state as ChatSessionActive).isGenerating) {
                emit((state as ChatSessionActive).copyWith(isGenerating: false));
             } else if (state is! ChatSessionActive) { 
                // This case is tricky, maybe emit ChatError or just log
                AppLogger.e('ChatBloc', 'Stream completed, state is not Active, but maybe was generating? State: ${state.runtimeType}');
             }
      }

    } catch (error, stackTrace) {
        // Catches errors from:
        // - Initial repository.streamMessage call
        // - Errors re-thrown from the stream's `onError` that emit.forEach catches
        // - The StateErrors thrown in `onData` if state changes or placeholder is lost
        AppLogger.e('ChatBloc', 'Error during _handleStreamedResponse processing loop', error, stackTrace);
        // Check emitter status *before* attempting to emit
        if (!emit.isDone) {
            final currentState = state; // Get state at the time of catch
            final errorMessage = (error is StateError)
                 ? "内部错误: ${error.message}" // Keep StateError messages distinct
                 : ApiExceptionHelper.fromException(error, "处理流响应失败").message;

            if (currentState is ChatSessionActive && currentState.session.id == currentSessionId) {
                 // Attempt to emit the error state for the correct session
                 emit(currentState.copyWith(
                     messages: _markPlaceholderAsError(currentState.messages, placeholderId, contentBuffer.toString(), errorMessage),
                     isGenerating: false, // Stop generation on error
                     error: errorMessage,
                     clearError: false,
                 ));
            } else {
                 // If state changed before catch, emit generic error
                  AppLogger.w('ChatBloc', 'Caught error, but state changed. Emitting generic ChatError.');
                 emit(ChatError(message: errorMessage));
            }
        } else {
            AppLogger.w('ChatBloc', 'Caught error, but emitter is done. Cannot emit error state.');
        }
    } finally {
       // No explicit subscription cleanup needed with emit.forEach
       AppLogger.d('ChatBloc', '_handleStreamedResponse finished processing for placeholder $placeholderId');
        // Ensure `isGenerating` is false if the process ends unexpectedly without explicit state update
        // This is a safety net.
        if (state is ChatSessionActive && (state as ChatSessionActive).isGenerating && (state as ChatSessionActive).session.id == currentSessionId) {
            AppLogger.w('ChatBloc', '_handleStreamedResponse finally: State still shows isGenerating. Forcing to false.');
            if (!emit.isDone) {
               emit((state as ChatSessionActive).copyWith(isGenerating: false));
            }
        }
    }
  }

  // 辅助方法: 将占位符消息标记为错误 (确保使用 MessageStatus.error)
  List<ChatMessage> _markPlaceholderAsError(List<ChatMessage> messages, String placeholderId, String bufferedContent, String errorMessage) {
      final listCopy = List<ChatMessage>.from(messages);
      final errorIndex = listCopy.indexWhere((msg) => msg.id == placeholderId);
      if (errorIndex != -1) {
          final existingMessage = listCopy[errorIndex];
          listCopy[errorIndex] = existingMessage.copyWith(
              content: bufferedContent.isNotEmpty
                   ? '$bufferedContent\n\n[错误: $errorMessage]'
                   : '[错误: $errorMessage]',
              status: MessageStatus.error, // Mark as error
              timestamp: DateTime.now(), // Update timestamp
          );
      } else {
           AppLogger.w('ChatBloc', '_markPlaceholderAsError: 未找到ID为 $placeholderId 的占位符标记错误');
      }
      return listCopy;
  }

  Future<void> _onUpdateChatModel(UpdateChatModel event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is ChatSessionActive && currentState.session.id == event.sessionId) {
      UserAIModelConfigModel? newSelectedModel;
      final aiState = _aiConfigBloc.state;

      // 1. Find the new model object from AiConfigBloc state
      if (aiState.configs.isNotEmpty) {
          newSelectedModel = aiState.configs.firstWhereOrNull(
              (config) => config.id == event.modelConfigId,
          );
      }

      if (newSelectedModel == null) {
          // 添加日志记录找不到模型的具体ID
          AppLogger.w('ChatBloc', '_onUpdateChatModel: Model config with ID ${event.modelConfigId} not found in AiConfigBloc state.');
          // --- 添加这行日志来查看 AiConfigBloc 的当前状态 ---
          AppLogger.d('ChatBloc', 'Current AiConfigState: Status=${aiState.status}, Config IDs=[${aiState.configs.map((c) => c.id).join(', ')}], DefaultConfig ID=${aiState.defaultConfig?.id}');
          // --------------------------------------------------
          emit(currentState.copyWith(error: '选择的模型配置未找到或未加载', clearError: false));
          return;
      }

      try {
          // 2. Update the backend session
          await repository.updateSession(
            userId: _userId,
            sessionId: event.sessionId,
            updates: {'selectedModelConfigId': event.modelConfigId}
          );

          // 3. Update the session object in the state
          final updatedSession = currentState.session.copyWith(
            selectedModelConfigId: event.modelConfigId,
            lastUpdatedAt: DateTime.now(),
          );

          // 4. Emit the new state with updated session and selectedModel
          emit(currentState.copyWith(
            session: updatedSession,
            selectedModel: newSelectedModel,
            clearError: true,
          ));
          AppLogger.i('ChatBloc','_onUpdateChatModel successful for session ${event.sessionId}, new model ${event.modelConfigId}');

      } catch (e, stackTrace) {
          AppLogger.e('ChatBloc','_onUpdateChatModel failed to update repository', e, stackTrace);
          emit(currentState.copyWith(
              error: '更新模型失败: ${_formatApiError(e, "更新模型失败")}',
              clearError: false,
          ));
      }
    } else {
         AppLogger.w('ChatBloc', '_onUpdateChatModel called with non-matching state or session ID.');
    }
  }

  // 添加一个辅助方法来格式化错误（如果 ApiExceptionHelper 不可用）
  String _formatApiError(Object error, [String defaultPrefix = '操作失败']) {
     return '$defaultPrefix: ${error.toString()}';
  }
}