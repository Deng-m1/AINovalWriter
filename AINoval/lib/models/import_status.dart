/// 小说导入状态模型
class ImportStatus {
  /// 从JSON创建实例
  factory ImportStatus.fromJson(Map<String, dynamic> json) {
    return ImportStatus(
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }

  /// 创建导入状态
  ImportStatus({
    required this.status,
    required this.message,
  });

  /// 导入状态 (PROCESSING, SAVING, INDEXING, COMPLETED, FAILED, ERROR)
  final String status;

  /// 状态消息
  final String message;

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
    };
  }

  @override
  String toString() => 'ImportStatus{status: $status, message: $message}';
}
