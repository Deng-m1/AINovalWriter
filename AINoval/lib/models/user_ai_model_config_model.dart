import 'package:meta/meta.dart'; // For @immutable
import '../utils/date_time_parser.dart'; // Import the parser

/// 用户 AI 模型配置模型 (对应后端的 UserAIModelConfigResponse)
@immutable // Good practice for value objects
class UserAIModelConfigModel {
  const UserAIModelConfigModel({
    required this.id,
    required this.userId,
    required this.provider,
    required this.modelName,
    required this.alias,
    this.apiEndpoint,
    required this.isValidated,
    this.validationError,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

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
      apiEndpoint: json['apiEndpoint'] as String?, // Allow null
      isValidated: safeBool('isValidated'),
      validationError: json['validationError'] as String?, // Allow null
      isDefault: safeBool('isDefault'),
      createdAt: parseBackendDateTime(json['createdAt']), // Use the parser
      updatedAt: parseBackendDateTime(json['updatedAt']), // Use the parser
    );
  }
  final String id;
  final String userId;
  final String provider;
  final String modelName;
  final String alias;
  final String? apiEndpoint; // nullable
  final bool isValidated;
  final String? validationError; // nullable
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

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
      'validationError': validationError,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(), // Standard format for JSON
      'updatedAt': updatedAt.toIso8601String(), // Standard format for JSON
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
    String? validationError,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAIModelConfigModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      provider: provider ?? this.provider,
      modelName: modelName ?? this.modelName,
      alias: alias ?? this.alias,
      // For nullable fields, we need explicit handling if we want to allow setting them back to null
      // Option 1: Simple override (cannot set back to null via copyWith)
      // apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      // validationError: validationError ?? this.validationError,
      // Option 2: More explicit (allows setting back to null, but more verbose)
      // Requires careful thought on desired behavior. Let's stick to simple override for now.
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      isValidated: isValidated ?? this.isValidated,
      validationError: validationError ?? this.validationError,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
        other.validationError == validationError &&
        other.isDefault == isDefault &&
        other.createdAt == createdAt &&
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
        validationError.hashCode ^
        isDefault.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'UserAIModelConfigModel(id: $id, userId: $userId, provider: $provider, modelName: $modelName, alias: $alias, apiEndpoint: $apiEndpoint, isValidated: $isValidated, validationError: $validationError, isDefault: $isDefault, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
