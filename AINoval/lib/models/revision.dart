/// 修订历史模型
class Revision {
  
  /// 构造函数
  Revision({
    required this.id,
    required this.sceneId,
    required this.title,
    required this.timestamp,
    required this.content,
  });
  
  /// 从JSON创建Revision实例
  factory Revision.fromJson(Map<String, dynamic> json) {
    return Revision(
      id: json['id'] as String,
      sceneId: json['sceneId'] as String,
      title: json['title'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: json['content'] as String,
    );
  }
  /// 修订唯一标识符
  final String id;
  
  /// 关联的场景ID
  final String sceneId;
  
  /// 修订标题
  final String title;
  
  /// 修订时间
  final DateTime timestamp;
  
  /// 修订内容
  final String content;
  
  /// 将Revision实例转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sceneId': sceneId,
      'title': title,
      'timestamp': timestamp.toIso8601String(),
      'content': content,
    };
  }
} 