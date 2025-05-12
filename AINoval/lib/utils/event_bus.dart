import 'dart:async';

// 事件基类
abstract class AppEvent {
  const AppEvent();
}

// 小说结构更新事件
class NovelStructureUpdatedEvent extends AppEvent {
  final String novelId;
  final String updateType; // 'outline_saved', 'chapter_added', 'scene_added', etc.
  final Map<String, dynamic> data;

  const NovelStructureUpdatedEvent({
    required this.novelId,
    required this.updateType,
    required this.data,
  });
}

// 事件总线单例
class EventBus {
  // 单例实例
  static final EventBus _instance = EventBus._internal();
  static EventBus get instance => _instance;

  // 事件流控制器
  final StreamController<AppEvent> _eventController = StreamController<AppEvent>.broadcast();

  // 获取事件流
  Stream<AppEvent> get eventStream => _eventController.stream;

  // 发送事件
  void fire(AppEvent event) {
    _eventController.add(event);
  }

  // 获取特定类型的事件流
  Stream<T> on<T extends AppEvent>() {
    return eventStream.where((event) => event is T).cast<T>();
  }

  // 私有构造函数，确保单例模式
  EventBus._internal();

  // 关闭事件总线
  void dispose() {
    _eventController.close();
  }
} 