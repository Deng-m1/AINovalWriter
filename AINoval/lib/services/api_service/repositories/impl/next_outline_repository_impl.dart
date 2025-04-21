import 'dart:convert';

import 'package:ainoval/models/next_outline/next_outline_dto.dart';
import 'package:ainoval/models/next_outline/outline_generation_chunk.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/base/sse_client.dart';
import 'package:ainoval/services/api_service/repositories/next_outline_repository.dart';
import 'package:ainoval/utils/app_logger.dart';

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
      path: '/novels/$novelId/ai/generate-next-outlines',
      method: SSERequestType.POST,
      body: request.toJson(),
      parser: (json) {
        // 增强解析器的错误处理
        if (json.containsKey('error')) {
          AppLogger.e(_tag, '服务器返回错误: ${json['error']}');
          throw ApiException(-1, '服务器返回错误: ${json['error']}');
        }
        
        try {
          return OutlineGenerationChunk.fromJson(json);
        } catch (e) {
          AppLogger.e(_tag, '解析OutlineGenerationChunk失败: $e, json: $json');
          throw ApiException(-1, '解析响应失败: $e');
        }
      },
    );
  }

  @override
  Stream<OutlineGenerationChunk> regenerateOutlineOption(
    String novelId, 
    RegenerateOptionRequest request
  ) {
    AppLogger.i(_tag, '重新生成单个剧情大纲选项: novelId=$novelId, optionId=${request.optionId}, configId=${request.selectedConfigId}');
    
    return SseClient().streamEvents<OutlineGenerationChunk>(
      path: '/novels/$novelId/ai/regenerate-outline-option',
      method: SSERequestType.POST,
      body: request.toJson(),
      parser: (json) {
        // 增强解析器的错误处理
        if (json.containsKey('error')) {
          AppLogger.e(_tag, '服务器返回错误: ${json['error']}');
          throw ApiException(-1, '服务器返回错误: ${json['error']}');
        }
        
        try {
          return OutlineGenerationChunk.fromJson(json);
        } catch (e) {
          AppLogger.e(_tag, '解析OutlineGenerationChunk失败: $e, json: $json');
          throw ApiException(-1, '解析响应失败: $e');
        }
      },
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
        '/novels/$novelId/ai/save-outline',
        body: request.toJson(),
      );
      
      return SaveNextOutlineResponse.fromJson(response);
    } catch (e) {
      AppLogger.e(_tag, '保存剧情大纲失败', e);
      rethrow;
    }
  }
}
