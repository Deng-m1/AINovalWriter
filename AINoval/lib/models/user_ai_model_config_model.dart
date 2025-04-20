import 'package:meta/meta.dart'; // For @immutable
import '../utils/date_time_parser.dart'; // Import the parser
import 'package:equatable/equatable.dart'; // Import Equatable for Equatable mixin

/// 用户 AI 模型配置模型 (对应后端的 UserAIModelConfigResponse)
@immutable // Good practice for value objects
class UserAIModelConfigModel extends Equatable {
  final String id;
  final String userId;
  final String provider;
  final String modelName;
  final String alias;
  final String apiEndpoint;
  final bool isValidated;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? apiKey; // 添加apiKey字段，存储解密后的API密钥

  const UserAIModelConfigModel({
    required this.id,
    required this.userId,
    required this.provider,
    required this.modelName,
    required this.alias,
    required this.apiEndpoint,
    required this.isValidated,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.apiKey, // 添加apiKey字段，可为空
  });

  // 空实例，用于默认值
  factory UserAIModelConfigModel.empty() {
    return UserAIModelConfigModel(
      id: '',
      userId: '',
      provider: '',
      modelName: '',
      alias: '',
      apiEndpoint: '',
      isValidated: false,
      isDefault: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      apiKey: null, // 默认为null
    );
  }

  // 从JSON转换方法
  factory UserAIModelConfigModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely get string, providing a default if null or wrong type
    String safeString(String key, [String defaultValue = '']) {
      return json[key] is String ? json[key] as String : defaultValue;
    }

    // Helper to safely get bool, providing a default if null or wrong type
    bool safeBool(String key, [bool defaultValue = false]) {
      return json[key] is bool ? json[key] as bool : defaultValue;
    }

    return UserAIModelConfigModel(
      id: safeString('id'), // Assuming 'id' is the key from backend
      userId: safeString('userId'),
      provider: safeString('provider'),
      modelName: safeString('modelName'),
      alias: safeString('alias'),
      apiEndpoint: json['apiEndpoint'] as String,
      isValidated: safeBool('isValidated'),
      isDefault: safeBool('isDefault'),
      createdAt: parseBackendDateTime(json['createdAt']), // Use the parser
      updatedAt: parseBackendDateTime(json['updatedAt']), // Use the parser
      apiKey: json['apiKey'] as String?, // 添加API密钥，可为空
    );
  }

  // 转换为JSON方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'provider': provider,
      'modelName': modelName,
      'alias': alias,
      'apiEndpoint': apiEndpoint,
      'isValidated': isValidated,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(), // Standard format for JSON
      'updatedAt': updatedAt.toIso8601String(), // Standard format for JSON
      'apiKey': apiKey, // 包含API密钥
    };
  }

  // 复制方法
  UserAIModelConfigModel copyWith({
    String? id,
    String? userId,
    String? provider,
    String? modelName,
    String? alias,
    String? apiEndpoint,
    bool? isValidated,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? apiKey, // 添加apiKey参数
  }) {
    return UserAIModelConfigModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      provider: provider ?? this.provider,
      modelName: modelName ?? this.modelName,
      alias: alias ?? this.alias,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      isValidated: isValidated ?? this.isValidated,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      apiKey: apiKey ?? this.apiKey, // 复制apiKey
    );
  }

  // --- Value Equality ---

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserAIModelConfigModel &&
        other.id == id &&
        other.userId == userId &&
        other.provider == provider &&
        other.modelName == modelName &&
        other.alias == alias &&
        other.apiEndpoint == apiEndpoint &&
        other.isValidated == isValidated &&
        other.isDefault == isDefault &&
        other.createdAt == createdAt &&
        other.apiKey == apiKey && // 比较apiKey
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        provider.hashCode ^
        modelName.hashCode ^
        alias.hashCode ^
        apiEndpoint.hashCode ^
        isValidated.hashCode ^
        isDefault.hashCode ^
        createdAt.hashCode ^
        apiKey.hashCode ^ // 计算apiKey的哈希值
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'UserAIModelConfigModel(id: $id, userId: $userId, provider: $provider, modelName: $modelName, alias: $alias, apiEndpoint: $apiEndpoint, isValidated: $isValidated, isDefault: $isDefault, createdAt: $createdAt, updatedAt: $updatedAt, apiKey: ${apiKey != null ? '******' : 'null'})'; // 不显示完整apiKey
  }

  @override
  List<Object?> get props => [id, userId, provider, modelName, alias, apiEndpoint, isValidated, isDefault, createdAt, updatedAt, apiKey]; // 添加apiKey到props
}
