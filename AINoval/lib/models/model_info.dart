import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Represents detailed information about an AI model provided by the backend.
@immutable
class ModelInfo extends Equatable {
  final String id; // Usually the unique model identifier (e.g., "gpt-4o")
  final String name; // User-friendly name (might be the same as id or different)
  final String provider;
  final String? description;
  final int? maxTokens;
  // Add other fields as needed based on backend response (e.g., pricing)
  // final double? unifiedPrice; 

  const ModelInfo({
    required this.id,
    required this.name,
    required this.provider,
    this.description,
    this.maxTokens,
    // this.unifiedPrice,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '', // Fallback name to id
      provider: json['provider'] as String? ?? '',
      description: json['description'] as String?,
      maxTokens: json['maxTokens'] as int?,
      // unifiedPrice: (json['unifiedPrice'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'description': description,
      'maxTokens': maxTokens,
      // 'unifiedPrice': unifiedPrice,
    };
  }

  @override
  List<Object?> get props => [id, name, provider, description, maxTokens /*, unifiedPrice*/];
} 