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



class ChatBloc extends Bloc<ChatEvent, ChatState> {
  
  ChatBloc({
    required this.repository, 
    required this.contextProvider,
    required this.authService,
  }) : _userId = AppConfig.userId ?? '',
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
  }
  final ChatRepository repository;
  final ContextProvider contextProvider;
  final AuthService authService;
  final String _userId;
  
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
      // 3. 发出初始 Activity 状态，标记正在加载历史
      emit(ChatSessionActive(
         session: session,
         context: context,
         messages: const [], // 初始空列表
         isGenerating: false,
         isLoadingHistory: true, // 标记正在加载历史
      ));
      AppLogger.d('ChatBloc', '_onSelectChatSession emitted initial ChatSessionActive (loading history)');

       // 4. 使用 await emit.forEach 加载消息历史
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
          final errorMessage = '加载消息历史失败: ${ApiExceptionHelper.fromException(error, "加载历史出错").message}';
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
          final errorMessage = '加载会话失败: ${ApiExceptionHelper.fromException(e, "加载会话信息出错").message}';
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
  Future<void> _handleStreamedResponse(Emitter<ChatState> emit, String placeholderId, String userContent) async {
       StreamSubscription? responseSubscription;
       StringBuffer contentBuffer = StringBuffer();
       ChatMessage? finalMessageData;

       // 确保我们在 ChatSessionActive 状态下开始
       if (state is! ChatSessionActive) {
           AppLogger.e('ChatBloc', '_handleStreamedResponse called while not in ChatSessionActive state');
           throw Exception("Cannot handle stream response outside of active session.");
           // 或者可以直接 return 或发出错误状态
       }
       final currentSessionId = (state as ChatSessionActive).session.id;

       final stream = repository.streamMessage(
           userId: _userId,
           sessionId: currentSessionId,
           content: userContent,
       );

       responseSubscription = stream.listen(
         (chunk) {
            // 检查状态是否仍然是同一个活动会话
            if (state is! ChatSessionActive || (state as ChatSessionActive).session.id != currentSessionId || emit.isDone) {
                 AppLogger.w('ChatBloc', 'Stream chunk received, but state changed or BLoC closed. Cancelling.');
                 responseSubscription?.cancel();
                 return;
            }
            final latestState = state as ChatSessionActive; // 重新获取最新状态

             if (finalMessageData == null) {
                 finalMessageData = chunk;
             }
             contentBuffer.write(chunk.content);

             final latestMessages = List<ChatMessage>.from(latestState.messages);
             final aiMessageIndex = latestMessages.indexWhere((msg) => msg.id == placeholderId);

             if (aiMessageIndex != -1) {
                 latestMessages[aiMessageIndex] = latestMessages[aiMessageIndex].copyWith(
                     content: contentBuffer.toString(),
                     // **注意: MessageStatus.streaming 需要添加到你的枚举中**
                     status: MessageStatus.pending, // 使用 pending 直到完成，或者添加 streaming 状态
                     // 如果有 streaming 状态: status: MessageStatus.streaming,
                 );
                 emit(latestState.copyWith(
                     messages: latestMessages,
                     isGenerating: true, // 仍在生成中
                 ));
             } else {
                AppLogger.w('ChatBloc', '_handleStreamedResponse: 未找到ID为 $placeholderId 的占位符进行流式更新');
                responseSubscription?.cancel();
             }
         },
         onDone: () {
             AppLogger.i('ChatBloc', 'AI响应流完成');
             // 检查状态是否仍然是同一个活动会话
             if (state is! ChatSessionActive || (state as ChatSessionActive).session.id != currentSessionId || emit.isDone) {
                  AppLogger.w('ChatBloc', 'Stream done, but state changed or BLoC closed. Ignoring final update.');
                  return;
             }
             final latestState = state as ChatSessionActive; // 重新获取最新状态


             final latestMessages = List<ChatMessage>.from(latestState.messages);
             final aiMessageIndex = latestMessages.indexWhere((msg) => msg.id == placeholderId);

             if (aiMessageIndex != -1) {
                 latestMessages[aiMessageIndex] = (finalMessageData ?? latestMessages[aiMessageIndex]).copyWith(
                   id: finalMessageData?.id ?? placeholderId,
                   content: contentBuffer.toString(),
                   timestamp: DateTime.now(),
                   status: MessageStatus.sent,
                 );
                 emit(latestState.copyWith(
                     messages: latestMessages,
                     isGenerating: false, // 生成完成
                 ));
             } else {
                 AppLogger.w('ChatBloc', '_handleStreamedResponse (onDone): 未找到ID为 $placeholderId 的占位符进行最终更新');
                 // 即使找不到，也确保 isGenerating 设为 false
                  if (latestState.isGenerating) {
                     emit(latestState.copyWith(isGenerating: false));
                 }
             }
             // responseSubscription?.cancel(); // listen 会在 onDone 后自动取消
         },
         onError: (e, stackTrace) {
             AppLogger.e('ChatBloc', 'Handling onError - Instance hash: ${identityHashCode(this)}', e, stackTrace);
             final isEmitterDone = emit.isDone;
             AppLogger.d('ChatBloc', 'onError check: emit.isDone = $isEmitterDone - Instance hash: ${identityHashCode(this)}');

             // --- 修改开始: 简化错误处理和 emit 尝试 ---
             if (!isEmitterDone) {
                 try {
                     final currentState = state; // 获取当前状态
                     AppLogger.i('ChatBloc', 'onError: Emitter IS NOT done. Current state: ${currentState.runtimeType}. Attempting emit...');
                     final errorMessage = ApiExceptionHelper.fromException(e, "流处理失败").message;

                     if (currentState is ChatSessionActive) {
                         // 准备一个更新后的状态，确保 isGenerating 为 false
                         final errorState = currentState.copyWith(
                             isGenerating: false,
                             error: errorMessage,
                             // 尝试更新消息列表中的占位符为错误
                             messages: _markPlaceholderAsError(currentState.messages, placeholderId, contentBuffer.toString(), errorMessage),
                         );
                         emit(errorState);
                         AppLogger.i('ChatBloc', 'onError: Successfully emitted ChatSessionActive with isGenerating=false.');
                     } else {
                         // 如果当前不是活动会话，发出通用错误
                         emit(ChatError(message: errorMessage));
                         AppLogger.i('ChatBloc', 'onError: Successfully emitted ChatError.');
                     }
                 } catch (emitError, emitStackTrace) {
                     // 捕获 emit 调用本身可能抛出的异常
                     AppLogger.e('ChatBloc', 'onError: FAILED TO EMIT state even though emit.isDone was false initially!', emitError, emitStackTrace);
                 }
             } else {
                 AppLogger.w('ChatBloc', 'onError: Emitter IS done. Cannot emit state. Instance hash: ${identityHashCode(this)}');
             }
             // --- 修改结束 ---
         },
       );
     }

  // --- 添加辅助方法: 将占位符消息标记为错误 ---
  List<ChatMessage> _markPlaceholderAsError(List<ChatMessage> messages, String placeholderId, String bufferedContent, String errorMessage) {
      final listCopy = List<ChatMessage>.from(messages);
      final errorIndex = listCopy.indexWhere((msg) => msg.id == placeholderId);
      if (errorIndex != -1) {
          listCopy[errorIndex] = listCopy[errorIndex].copyWith(
              content: bufferedContent.isNotEmpty
                   ? '$bufferedContent\n\n[错误: $errorMessage]'
                   : '[错误: $errorMessage]',
              status: MessageStatus.error, // 确保你有 MessageStatus.error 枚举值
          );
      } else {
           AppLogger.w('ChatBloc', '_markPlaceholderAsError: 未找到ID为 $placeholderId 的占位符标记错误');
      }
      return listCopy;
  }
}