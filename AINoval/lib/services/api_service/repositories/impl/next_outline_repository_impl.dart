import 'dart:convert';

import 'package:ainoval/models/next_outline/next_outline_dto.dart';
import 'package:ainoval/models/next_outline/outline_generation_chunk.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/base/sse_client.dart';
import 'package:ainoval/services/api_service/repositories/next_outline_repository.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';

import '../../../../utils/logger.dart';


/// 剧情推演仓库实现
class NextOutlineRepositoryImpl implements NextOutlineRepository {
  NextOutlineRepositoryImpl({
    required this.apiClient,
  });

  final ApiClient apiClient;
  final String _tag = 'NextOutlineRepositoryImpl';

  @override
  Stream<OutlineGenerationChunk> generateNextOutlinesStream(
    String novelId, 
    GenerateNextOutlinesRequest request
  ) {
    AppLogger.i(_tag, '流式生成剧情大纲: novelId=$novelId, startChapter=${request.startChapterId}, endChapter=${request.endChapterId}, numOptions=${request.numOptions}');
    
    return SseClient().streamEvents<OutlineGenerationChunk>(
      path: '/novels/$novelId/next-outlines/generate-stream',
      method: SSERequestType.POST,
      body: request.toJson(),
      parser: (json) {
        // 增强解析器的错误处理: 首先检查是否是已知的错误格式
        if (json is Map<String, dynamic> && json.containsKey('code') && json.containsKey('message')) {
          final errorMessage = json['message'] as String? ?? 'Unknown server error';
          final errorCodeString = json['code'] as String?;
          final errorCode = int.tryParse(errorCodeString ?? '') ?? -1; // 尝试解析为int，失败则为-1
          AppLogger.e(_tag, '服务器返回已知错误格式: code=${json['code']}, message=$errorMessage');
          throw ApiException(errorCode, errorMessage); // 使用int类型的errorCode
        }
        // 再检查是否包含 'error' 字段的值是否非空 (兼容旧的或不同的错误格式)
        else if (json is Map<String, dynamic> && json['error'] != null) {
           final errorMessage = json['error'] as String? ?? 'Unknown server error';
           AppLogger.e(_tag, '服务器返回错误字段: $errorMessage');
           throw ApiException(-1, errorMessage); // 默认错误码-1
         }
        
        // 如果不是错误格式，则尝试解析为正常数据块
        try {
          return OutlineGenerationChunk.fromJson(json);
        } catch (e, stackTrace) {
          AppLogger.e(_tag, '解析OutlineGenerationChunk失败: $e, json: $json'); // 移除 stackTrace
          // 抛出更具体的解析异常
          throw ApiException(-1, '解析响应失败: $e');
        }
      },
      eventName: 'outline-chunk',
    );
  }

  @override
  Stream<OutlineGenerationChunk> regenerateOutlineOption(
    String novelId, 
    RegenerateOptionRequest request
  ) {
    AppLogger.i(_tag, '重新生成单个剧情大纲选项: novelId=$novelId, optionId=${request.optionId}, configId=${request.selectedConfigId}');
    
    return SseClient().streamEvents<OutlineGenerationChunk>(
      path: '/novels/$novelId/next-outlines/regenerate-option',
      method: SSERequestType.POST,
      body: request.toJson(),
      parser: (json) {
         // 增强解析器的错误处理: 首先检查是否是已知的错误格式
        if (json is Map<String, dynamic> && json.containsKey('code') && json.containsKey('message')) {
          final errorMessage = json['message'] as String? ?? 'Unknown server error';
          final errorCodeString = json['code'] as String?;
          final errorCode = int.tryParse(errorCodeString ?? '') ?? -1; // 尝试解析为int，失败则为-1
          AppLogger.e(_tag, '服务器返回已知错误格式: code=${json['code']}, message=$errorMessage');
          throw ApiException(errorCode, errorMessage); // 使用int类型的errorCode
        }
        // 再检查是否包含 'error' 字段的值是否非空 (兼容旧的或不同的错误格式)
        else if (json is Map<String, dynamic> && json['error'] != null) {
           final errorMessage = json['error'] as String? ?? 'Unknown server error';
           AppLogger.e(_tag, '服务器返回错误字段: $errorMessage');
           throw ApiException(-1, errorMessage); // 默认错误码-1
         }
        
        // 如果不是错误格式，则尝试解析为正常数据块
        try {
          return OutlineGenerationChunk.fromJson(json);
        } catch (e, stackTrace) {
          AppLogger.e(_tag, '解析OutlineGenerationChunk失败: $e, json: $json'); // 移除 stackTrace
           // 抛出更具体的解析异常
          throw ApiException(-1, '解析响应失败: $e');
        }
      },
      eventName: 'outline-chunk',
    );
  }

  @override
  Future<SaveNextOutlineResponse> saveNextOutline(
    String novelId, 
    SaveNextOutlineRequest request
  ) async {
    AppLogger.i(_tag, '保存剧情大纲: novelId=$novelId, outlineId=${request.outlineId}, insertType=${request.insertType}');
    
    try {
      final response = await apiClient.post(
        '/novels/$novelId/next-outlines/save',
        data: request.toJson(),
      );
      
      return SaveNextOutlineResponse.fromJson(response);
    } catch (e) {
      AppLogger.e(_tag, '保存剧情大纲失败', e);
      rethrow;
    }
  }
}
