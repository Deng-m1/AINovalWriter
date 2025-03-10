import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_models.dart';

class WebSocketService {
  
  WebSocketService({
    this.baseUrl = 'ws://localhost:8080/chat',
  });
  final String baseUrl;
  final Map<String, WebSocketChannel> _connections = {};
  
  // 创建聊天连接
  Future<WebSocketChannel> createChatConnection(String sessionId) async {
    // 在第二周迭代中，我们不实际连接WebSocket，而是模拟
    // 返回一个模拟的WebSocketChannel
    final channel = MockWebSocketChannel(sessionId: sessionId);
    _connections[sessionId] = channel;
    return channel;
  }
  
  // 关闭连接
  void closeConnection(String sessionId) {
    if (_connections.containsKey(sessionId)) {
      _connections[sessionId]?.sink.close(status.goingAway);
      _connections.remove(sessionId);
    }
  }
  
  // 关闭所有连接
  void closeAllConnections() {
    for (final connection in _connections.values) {
      connection.sink.close(status.goingAway);
    }
    _connections.clear();
  }
}

// 简化的模拟WebSocketChannel实现
class MockWebSocketChannel extends StreamChannelMixin implements WebSocketChannel {
  
  MockWebSocketChannel({required this.sessionId}) {
    _sink = MockWebSocketSink(_sinkController);
    // 监听发送的消息，模拟响应
    _sinkController.stream.listen(_handleMessage);
  }
  final String sessionId;
  final StreamController<dynamic> _controller = StreamController<dynamic>();
  final StreamController<dynamic> _sinkController = StreamController<dynamic>();
  late final MockWebSocketSink _sink;
  
  @override
  Stream get stream => _controller.stream;
  
  @override
  WebSocketSink get sink => _sink;
  
  // 处理发送的消息，模拟响应
  void _handleMessage(dynamic message) {
    if (message is String) {
      try {
        final Map<String, dynamic> data = jsonDecode(message);
        
        if (data.containsKey('action') && data['action'] == 'cancel') {
          // 模拟取消请求
          _controller.add(jsonEncode({
            'done': true,
            'message': '请求已取消',
          }));
          return;
        }
        
        if (data.containsKey('message')) {
          // 模拟流式响应
          _simulateStreamingResponse(data['message'] as String);
        }
      } catch (e) {
        _controller.addError('解析消息失败: $e');
      }
    }
  }
  
  // 模拟流式响应
  void _simulateStreamingResponse(String message) async {
    // 根据消息内容生成不同的响应
    String response;
    List<MessageAction> actions = [];
    
    if (message.contains('角色')) {
      response = '角色设计是小说创作中的重要环节。好的角色应该有鲜明的性格特点、合理的动机和明确的目标。';
      actions.add(MessageAction(
        id: const Uuid().v4(),
        label: '创建角色',
        type: ActionType.createCharacter,
        data: {'suggestion': '根据对话创建新角色'},
      ));
    } else if (message.contains('情节')) {
      response = '情节发展需要有起承转合，保持读者的兴趣。一个好的情节应该包含引人入胜的开端、不断升级的冲突、出人意料的转折和合理的结局。';
      actions.add(MessageAction(
        id: const Uuid().v4(),
        label: '生成情节',
        type: ActionType.generatePlot,
        data: {'suggestion': '根据当前内容生成情节'},
      ));
    } else {
      response = '感谢您的提问。作为您的AI写作助手，我很乐意帮助您解决创作中遇到的问题。请告诉我您需要什么样的帮助？';
    }
    
    // 始终添加一个应用到编辑器的操作
    actions.add(MessageAction(
      id: const Uuid().v4(),
      label: '应用到编辑器',
      type: ActionType.applyToEditor,
      data: {'suggestion': '将AI回复应用到编辑器'},
    ));
    
    // 模拟流式响应，将响应分成多个块发送
    final chunks = _splitIntoChunks(response, 10);
    
    for (int i = 0; i < chunks.length; i++) {
      // 添加随机延迟，模拟网络延迟
      await Future.delayed(Duration(milliseconds: 100 + (50 * i)));
      
      // 发送块
      _controller.add(jsonEncode({
        'chunk': chunks[i],
      }));
    }
    
    // 发送完成信号和操作
    await Future.delayed(const Duration(milliseconds: 500));
    _controller.add(jsonEncode({
      'done': true,
      'actions': actions.map((a) => a.toJson()).toList(),
    }));
  }
  
  // 将文本分成多个块
  List<String> _splitIntoChunks(String text, int chunkSize) {
    final chunks = <String>[];
    for (int i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      chunks.add(text.substring(i, end));
    }
    return chunks;
  }
  
  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    _sinkController.close();
    return _controller.close();
  }
  
  // WebSocketChannel 接口所需的属性
  @override
  int? get closeCode => null;
  
  @override
  String? get closeReason => null;
  
  @override
  String? get protocol => null;
  
  @override
  Future<void> get ready => Future.value();
}

// 模拟的WebSocketSink
class MockWebSocketSink implements WebSocketSink {
  
  MockWebSocketSink(this._controller);
  final StreamController<dynamic> _controller;
  
  @override
  void add(dynamic data) {
    _controller.add(data);
  }
  
  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _controller.addError(error, stackTrace);
  }
  
  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }
  
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    // 不实际关闭，因为这是模拟的
    return Future.value();
  }
  
  @override
  Future<void> get done => Future.value();
} 