<think>用户希望我继续提供剩余模块的详细设计文档。在之前的回复中，我已经提供了小说列表模块和编辑器模块的详细设计文档。根据前面的概要，下一批应该包括:

1. AI聊天模块详细设计
2. Codex知识库模块详细设计
3. 小说计划预览模块详细设计

我需要按照前面的格式和风格继续设计这些模块，保持代码格式和细节水平的一致性。内容应该包括:
- 模块概述
- 数据模型
- 状态管理
- UI组件结构
- 功能实现
- API交互
- 性能优化
- 可能的异常处理

我将使用中文编写这些详细设计文档。</think># 模块详细设计文档（第二批）

## AI聊天模块详细设计

### 1. 模块概述

AI聊天模块是系统的核心功能之一，提供与AI助手对话的能力，不仅用于解答问题，还可以分析小说内容、提供创作建议、角色设计等帮助。该模块的特点是具有上下文感知能力，能够根据用户当前编辑的小说内容提供相关的建议。

### 2. 数据模型

```dart
// 聊天会话模型
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final List<ChatMessage> messages;
  final String novelId;
  final String? chapterId;
  
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.messages,
    required this.novelId,
    this.chapterId,
  });
}

// 聊天消息模型
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final List<MessageAction>? actions;
  
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.actions,
  });
}

// 消息发送者角色
enum MessageRole {
  user,
  assistant,
  system,
}

// 消息状态
enum MessageStatus {
  sending,
  sent,
  error,
  pending,
}

// 消息关联操作
class MessageAction {
  final String id;
  final String label;
  final ActionType type;
  final Map<String, dynamic>? data;
  
  MessageAction({
    required this.id,
    required this.label,
    required this.type,
    this.data,
  });
}

// 操作类型
enum ActionType {
  applyToEditor,
  createCharacter,
  createLocation,
  generatePlot,
  expandScene,
  createChapter,
  analyzeSentiment,
  fixGrammar,
}

// 聊天上下文模型
class ChatContext {
  final String novelId;
  final String? chapterId;
  final String? selectedText;
  final List<ContextItem> relevantItems;
  
  ChatContext({
    required this.novelId,
    this.chapterId,
    this.selectedText,
    this.relevantItems = const [],
  });
}

// 上下文项目
class ContextItem {
  final String id;
  final ContextItemType type;
  final String title;
  final String content;
  final double relevanceScore;
  
  ContextItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.relevanceScore,
  });
}

// 上下文项目类型
enum ContextItemType {
  character,
  location,
  plot,
  chapter,
  scene,
  note,
  lore,
}
```

### 3. 状态管理

```dart
// AI聊天状态管理
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
        id: UUID.v4(),
        role: MessageRole.user,
        content: event.content,
        timestamp: DateTime.now(),
      );
      
      // 更新状态，添加用户消息并标记为生成中
      emit(ChatSessionActive(
        session: currentState.session.copyWith(
          messages: [...currentState.session.messages, userMessage],
          lastUpdatedAt: DateTime.now(),
        ),
        context: currentState.context,
        isGenerating: true,
      ));
      
      try {
        // 创建占位符AI消息
        final placeholderMessage = ChatMessage(
          id: UUID.v4(),
          role: MessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
        );
        
        // 更新状态，添加占位符消息
        ChatSessionActive updatedState;
        emit(updatedState = ChatSessionActive(
          session: currentState.session.copyWith(
            messages: [...currentState.session.messages, userMessage, placeholderMessage],
            lastUpdatedAt: DateTime.now(),
          ),
          context: currentState.context,
          isGenerating: true,
        ));
        
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
  
  // 其他事件处理方法...
}
```

### 4. UI组件结构

```
ChatScreen
├── ChatHeader
│   ├── BackButton
│   ├── SessionTitleText (editable)
│   ├── NewChatButton
│   ├── SessionsDropdown
│   └── SettingsButton
├── ChatContainer
│   ├── ChatMessagesList
│   │   ├── DateSeparator
│   │   ├── UserMessage
│   │   │   ├── UserAvatar
│   │   │   ├── MessageContent
│   │   │   └── MessageTimestamp
│   │   └── AIMessage
│   │       ├── AIAvatar
│   │       ├── MessageContent
│   │       ├── ActionButtons
│   │       └── MessageTimestamp
│   ├── TypingIndicator (when AI is generating)
│   └── ScrollToBottomButton
├── ContextPanel (collapsible)
│   ├── ContextHeader
│   ├── ContextItemsList
│   │   ├── CharacterContextItem
│   │   ├── PlotContextItem
│   │   ├── LocationContextItem
│   │   └── ChapterContextItem
│   └── ManageContextButton
└── MessageInputArea
    ├── TextInput
    ├── AttachContextToggle
    ├── AISuggestionChips
    └── SendButton
```

### 5. 流式响应实现

```dart
// 流式响应处理类
class StreamingResponseHandler {
  final WebSocketChannel _channel;
  final String sessionId;
  final void Function(String) onChunk;
  final void Function(List<MessageAction>) onActionsReceived;
  final void Function(String) onError;
  final void Function() onComplete;
  
  StreamSubscription? _subscription;
  final StringBuffer _buffer = StringBuffer();
  
  StreamingResponseHandler({
    required WebSocketChannel channel,
    required this.sessionId,
    required this.onChunk,
    required this.onActionsReceived,
    required this.onError,
    required this.onComplete,
  }) : _channel = channel;
  
  // 开始监听流式响应
  void startListening() {
    _subscription = _channel.stream.listen(
      (dynamic data) {
        try {
          if (data is String) {
            final Map<String, dynamic> jsonData = jsonDecode(data);
            
            // 检查是否是结束标记
            if (jsonData.containsKey('done') && jsonData['done'] == true) {
              // 检查是否有推荐操作
              if (jsonData.containsKey('actions')) {
                final actionsList = (jsonData['actions'] as List)
                    .map((a) => MessageAction.fromJson(a))
                    .toList();
                onActionsReceived(actionsList);
              }
              
              onComplete();
              return;
            }
            
            // 处理文本块
            if (jsonData.containsKey('chunk')) {
              final chunk = jsonData['chunk'] as String;
              _buffer.write(chunk);
              onChunk(chunk);
            }
          }
        } catch (e) {
          onError('解析AI响应失败: $e');
        }
      },
      onError: (error) {
        onError('接收AI响应时出错: $error');
      },
      onDone: () {
        // 如果WebSocket关闭但没有收到完成信号
        if (_buffer.isNotEmpty) {
          onComplete();
        }
      },
    );
  }
  
  // 发送消息
  void sendMessage(String message, ChatContext context) {
    final request = jsonEncode({
      'sessionId': sessionId,
      'message': message,
      'context': context.toJson(),
    });
    
    _channel.sink.add(request);
  }
  
  // 取消请求
  void cancelRequest() {
    _channel.sink.add(jsonEncode({
      'sessionId': sessionId,
      'action': 'cancel',
    }));
  }
  
  // 清理资源
  void dispose() {
    _subscription?.cancel();
    _channel.sink.close();
  }
}
```

### 6. 聊天组件实现

```dart
class ChatMessagesList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final Function(MessageAction) onActionSelected;
  
  const ChatMessagesList({
    Key? key,
    required this.messages,
    this.isGenerating = false,
    required this.onActionSelected,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: messages.length + (isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        // 如果是最后一项且正在生成，显示打字指示器
        if (isGenerating && index == messages.length) {
          return TypingIndicator();
        }
        
        final message = messages[index];
        
        // 根据消息类型构建不同的气泡
        if (message.role == MessageRole.user) {
          return UserMessageBubble(message: message);
        } else if (message.role == MessageRole.assistant) {
          return AIMessageBubble(
            message: message,
            onActionSelected: onActionSelected,
          );
        } else {
          return SystemMessageBubble(message: message);
        }
      },
    );
  }
}

class AIMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(MessageAction) onActionSelected;
  
  const AIMessageBubble({
    Key? key,
    required this.message,
    required this.onActionSelected,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            child: Icon(Icons.smart_toy, color: Theme.of(context).colorScheme.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.status == MessageStatus.pending)
                        LoadingTextIndicator()
                      else if (message.status == MessageStatus.error)
                        ErrorMessageContent(message: message)
                      else
                        MarkdownBody(data: message.content),
                      
                      if (message.actions != null && message.actions!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: message.actions!.map((action) {
                              return ActionChip(
                                label: Text(action.label),
                                onPressed: () => onActionSelected(action),
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                  child: Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat();
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            child: Icon(Icons.smart_toy, color: Theme.of(context).colorScheme.primary),
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [0, 1, 2].map((i) {
                    final delay = i * 0.2;
                    final opacity = sin((_controller.value * 6.28) - delay) * 0.5 + 0.5;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(opacity),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 7. API交互

```dart
class ChatRepository {
  final ApiService apiService;
  final LocalStorageService localStorageService;
  final WebSocketService webSocketService;
  
  ChatRepository({
    required this.apiService,
    required this.localStorageService,
    required this.webSocketService,
  });
  
  // 获取聊天会话列表
  Future<List<ChatSession>> getChatSessions(String novelId) async {
    try {
      // 尝试从服务器获取
      final sessions = await apiService.fetchChatSessions(novelId);
      
      // 缓存到本地
      await localStorageService.saveChatSessions(novelId, sessions);
      
      return sessions;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localSessions = await localStorageService.getChatSessions(novelId);
      if (localSessions.isNotEmpty) {
        return localSessions;
      }
      throw Exception('无法加载聊天会话: $e');
    }
  }
  
  // 创建新会话
  Future<ChatSession> createChatSession({
    required String title,
    required String novelId,
    String? chapterId,
  }) async {
    try {
      // 创建会话
      final newSession = await apiService.createChatSession(
        title: title,
        novelId: novelId,
        chapterId: chapterId,
      );
      
      // 保存到本地
      await localStorageService.addChatSession(novelId, newSession);
      
      return newSession;
    } catch (e) {
      // 如果服务器请求失败，创建本地临时会话
      final tempSession = ChatSession(
        id: UUID.v4(),
        title: title,
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        messages: [],
        novelId: novelId,
        chapterId: chapterId,
      );
      
      // 标记为需要同步
      await localStorageService.addChatSession(novelId, tempSession, needsSync: true);
      
      return tempSession;
    }
  }
  
  // 获取特定会话
  Future<ChatSession> getChatSession(String sessionId) async {
    try {
      // 尝试从服务器获取
      final session = await apiService.fetchChatSession(sessionId);
      
      // 缓存到本地
      await localStorageService.updateChatSession(session);
      
      return session;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localSession = await localStorageService.getChatSession(sessionId);
      if (localSession != null) {
        return localSession;
      }
      throw Exception('无法加载聊天会话: $e');
    }
  }
  
  // 发送消息并获取响应
  Future<AIChatResponse> sendMessage({
    required String sessionId,
    required String message,
    required ChatContext context,
  }) async {
    // 创建WebSocket连接
    final channel = await webSocketService.createChatConnection(sessionId);
    
    // 创建处理流式响应的Completer
    final responseCompleter = Completer<AIChatResponse>();
    final responseBuffer = StringBuffer();
    List<MessageAction> actions = [];
    
    // 处理流式响应
    final handler = StreamingResponseHandler(
      channel: channel,
      sessionId: sessionId,
      onChunk: (chunk) {
        responseBuffer.write(chunk);
      },
      onActionsReceived: (receivedActions) {
        actions = receivedActions;
      },
      onError: (error) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(Exception(error));
        }
      },
      onComplete: () {
        if (!responseCompleter.isCompleted) {
          responseCompleter.complete(AIChatResponse(
            content: responseBuffer.toString(),
            actions: actions,
          ));
        }
      },
    );
    
    // 开始监听
    handler.startListening();
    
    // 发送消息
    handler.sendMessage(message, context);
    
    try {
      // 等待响应完成
      final response = await responseCompleter.future;
      
      // 清理资源
      handler.dispose();
      
      return response;
    } catch (e) {
      // 清理资源
      handler.dispose();
      rethrow;
    }
  }
  
  // 保存会话消息
  Future<void> saveChatSession(String sessionId, List<ChatMessage> messages) async {
    try {
      // 保存到服务器
      await apiService.updateChatSessionMessages(sessionId, messages);
      
      // 更新本地缓存
      final session = await localStorageService.getChatSession(sessionId);
      if (session != null) {
        await localStorageService.updateChatSession(
          session.copyWith(
            messages: messages,
            lastUpdatedAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // 如果服务器请求失败，仅保存到本地并标记为需要同步
      final session = await localStorageService.getChatSession(sessionId);
      if (session != null) {
        await localStorageService.updateChatSession(
          session.copyWith(
            messages: messages,
            lastUpdatedAt: DateTime.now(),
          ),
          needsSync: true,
        );
      }
    }
  }
  
  // 其他方法...
}

// AI回复模型
class AIChatResponse {
  final String content;
  final List<MessageAction> actions;
  
  AIChatResponse({
    required this.content,
    this.actions = const [],
  });
}
```

### 8. 上下文管理

```dart
class ContextProvider {
  final NovelRepository novelRepository;
  final CodexRepository codexRepository;
  
  ContextProvider({
    required this.novelRepository,
    required this.codexRepository,
  });
  
  // 获取会话的上下文
  Future<ChatContext> getContextForSession(ChatSession session) async {
    final novelId = session.novelId;
    final chapterId = session.chapterId;
    
    // 收集相关的上下文项目
    List<ContextItem> relevantItems = [];
    
    // 1. 添加小说的基本信息
    final novel = await novelRepository.getNovelById(novelId);
    relevantItems.add(ContextItem(
      id: novel.id,
      type: ContextItemType.note,
      title: novel.title,
      content: '这是一部名为"${novel.title}"的小说，总字数约${novel.wordCount}字。',
      relevanceScore: 1.0,
    ));
    
    // 2. 如果有指定章节，添加章节信息
    if (chapterId != null) {
      try {
        final chapter = await novelRepository.getChapterById(novelId, chapterId);
        relevantItems.add(ContextItem(
          id: chapter.id,
          type: ContextItemType.chapter,
          title: chapter.title,
          content: '当前正在编辑的章节是"${chapter.title}"，这是小说的第${chapter.order}章，字数约${chapter.wordCount}字。',
          relevanceScore: 1.0,
        ));
      } catch (e) {
        print('获取章节信息失败: $e');
      }
    }
    
    // 3. 添加主要角色
    try {
      final characters = await codexRepository.getCharacters(novelId, limit: 5);
      for (var character in characters) {
        relevantItems.add(ContextItem(
          id: character.id,
          type: ContextItemType.character,
          title: character.title,
          content: character.description,
          relevanceScore: 0.9,
        ));
      }
    } catch (e) {
      print('获取角色信息失败: $e');
    }
    
    // 4. 添加主要地点
    try {
      final locations = await codexRepository.getLocations(novelId, limit: 3);
      for (var location in locations) {
        relevantItems.add(ContextItem(
          id: location.id,
          type: ContextItemType.location,
          title: location.title,
          content: location.description,
          relevanceScore: 0.8,
        ));
      }
    } catch (e) {
      print('获取地点信息失败: $e');
    }
    
    // 5. 如果有当前章节，添加前一章节的摘要作为上下文
    if (chapterId != null) {
      try {
        final chapter = await novelRepository.getChapterById(novelId, chapterId);
        final prevChapter = await novelRepository.getPreviousChapter(novelId, chapter.order);
        if (prevChapter != null) {
          relevantItems.add(ContextItem(
            id: prevChapter.id,
            type: ContextItemType.chapter,
            title: '上一章: ${prevChapter.title}',
            content: prevChapter.summary ?? '前一章节没有摘要。',
            relevanceScore: 0.85,
          ));
        }
      } catch (e) {
        print('获取前一章节信息失败: $e');
      }
    }
    
    // 6. 添加主要情节线索
    try {
      final plots = await codexRepository.getPlots(novelId, limit: 2);
      for (var plot in plots) {
        relevantItems.add(ContextItem(
          id: plot.id,
          type: ContextItemType.plot,
          title: plot.title,
          content: plot.description,
          relevanceScore: 0.75,
        ));
      }
    } catch (e) {
      print('获取情节信息失败: $e');
    }
    
    return ChatContext(
      novelId: novelId,
      chapterId: chapterId,
      relevantItems: relevantItems,
    );
  }
  
  // 基于当前内容扩展上下文
  Future<ChatContext> expandContextWithCurrentContent(
    ChatContext baseContext,
    String currentContent,
  ) async {
    // 复制现有的上下文项
    final items = List<ContextItem>.from(baseContext.relevantItems);
    
    // 添加当前正在编辑的内容摘要
    items.add(ContextItem(
      id: 'current_content',
      type: ContextItemType.scene,
      title: '当前编辑的内容',
      content: currentContent.length > 1000 
          ? '${currentContent.substring(0, 997)}...' 
          : currentContent,
      relevanceScore: 1.0,
    ));
    
    return baseContext.copyWith(
      selectedText: currentContent,
      relevantItems: items,
    );
  }
  
  // 基于特定的检索词获取相关上下文
  Future<List<ContextItem>> searchRelevantContext(String novelId, String query) async {
    // 实现语义搜索，返回相关的知识库条目
    try {
      final searchResults = await codexRepository.semanticSearch(novelId, query);
      return searchResults.map((result) {
        return ContextItem(
          id: result.id,
          type: _mapEntryTypeToContextType(result.type),
          title: result.title,
          content: result.content,
          relevanceScore: result.score,
        );
      }).toList();
    } catch (e) {
      print('语义搜索失败: $e');
      return [];
    }
  }
  
  // 映射知识库条目类型到上下文类型
  ContextItemType _mapEntryTypeToContextType(String entryType) {
    switch (entryType) {
      case 'character':
        return ContextItemType.character;
      case 'location':
        return ContextItemType.location;
      case 'subplot':
        return ContextItemType.plot;
      case 'lore':
        return ContextItemType.lore;
      default:
        return ContextItemType.note;
    }
  }
}
```

### 9. 主要性能优化

- **消息分页加载**：聊天历史初始只加载最近的消息，滚动时加载更多
- **WebSocket连接池**：重用连接以减少建立连接的开销
- **上下文缓存**：缓存常用的上下文信息以减少频繁加载
- **本地存储聊天记录**：减少网络请求，提高加载速度
- **流式响应处理**：减少等待时间，提供更好的用户体验

```dart
// 分页加载聊天消息示例
class PaginatedChatBloc extends Bloc<PaginatedChatEvent, PaginatedChatState> {
  final ChatRepository repository;
  final int pageSize;
  
  PaginatedChatBloc({
    required this.repository,
    this.pageSize = 20,
  }) : super(ChatMessagesInitial()) {
    on<LoadInitialMessages>(_onLoadInitial);
    on<LoadMoreMessages>(_onLoadMore);
  }
  
  Future<void> _onLoadInitial(LoadInitialMessages event, Emitter<PaginatedChatState> emit) async {
    emit(ChatMessagesLoading());
    
    try {
      final session = await repository.getChatSession(event.sessionId);
      final totalMessages = session.messages.length;
      
      // 只加载最近的pageSize条消息
      final startIndex = totalMessages > pageSize ? totalMessages - pageSize : 0;
      final initialMessages = session.messages.sublist(startIndex);
      
      emit(ChatMessagesLoaded(
        sessionId: event.sessionId,
        messages: initialMessages,
        hasMore: startIndex > 0,
        totalCount: totalMessages,
        loadedCount: initialMessages.length,
      ));
    } catch (e) {
      emit(ChatMessagesError(message: e.toString()));
    }
  }
  
  Future<void> _onLoadMore(LoadMoreMessages event, Emitter<PaginatedChatState> emit) async {
    final currentState = state;
    if (currentState is ChatMessagesLoaded && currentState.hasMore) {
      try {
        final session = await repository.getChatSession(currentState.sessionId);
        final totalMessages = session.messages.length;
        final currentLoadedCount = currentState.loadedCount;
        
        // 计算新的起始索引
        final remainingCount = totalMessages - currentLoadedCount;
        final loadCount = remainingCount > pageSize ? pageSize : remainingCount;
        final startIndex = totalMessages - currentLoadedCount - loadCount;
        
        // 加载更多消息
        final moreMessages = session.messages.sublist(startIndex, totalMessages - currentLoadedCount);
        
        emit(ChatMessagesLoaded(
          sessionId: currentState.sessionId,
          messages: [...moreMessages, ...currentState.messages],
          hasMore: startIndex > 0,
          totalCount: totalMessages,
          loadedCount: currentLoadedCount + loadCount,
        ));
      } catch (e) {
        emit(ChatMessagesError(message: e.toString()));
      }
    }
  }
}
```

