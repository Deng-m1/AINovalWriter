import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:async';
import 'package:ainoval/services/api_service/base/sse_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:ainoval/config/app_config.dart';

/// 提示词仓库实现
class PromptRepositoryImpl implements PromptRepository {
  final ApiClient _apiClient;
  static const String _baseUrl = '/api/users/me/prompts';
  static const String _templateBaseUrl = '/api/users/me/prompt-templates';
  static const String _tag = 'PromptRepositoryImpl';

  /// 构造函数
  PromptRepositoryImpl(this._apiClient);

  @override
  Future<Map<AIFeatureType, PromptData>> getAllPrompts() async {
    try {
      final result = await _apiClient.get(_baseUrl);
      if (result is List) {
        final Map<AIFeatureType, PromptData> prompts = {};
        for (final item in result) {
          try {
            final dto = UserPromptTemplateDto.fromJson(item);
            // 获取默认提示词
            final defaultPrompt = await _getDefaultPrompt(dto.featureType);
            // 创建PromptData
            prompts[dto.featureType] = PromptData(
              userPrompt: dto.promptText,
              defaultPrompt: defaultPrompt,
              isCustomized: true,
            );
          } catch (e) {
            AppLogger.e(_tag, '解析提示词失败: $item', e);
          }
        }
        return prompts;
      } else {
        throw Exception('获取提示词列表失败: 响应格式错误');
      }
    } catch (e) {
      AppLogger.e(_tag, '获取所有提示词失败', e);
      // 如果API调用失败，返回默认提示词
      final Map<AIFeatureType, PromptData> defaultPrompts = {};
      try {
        // 为每种特性类型生成默认提示词
        for (final featureType in AIFeatureType.values) {
          final defaultPrompt = await _getDefaultPrompt(featureType);
          defaultPrompts[featureType] = PromptData(
            userPrompt: defaultPrompt,
            defaultPrompt: defaultPrompt,
            isCustomized: false,
          );
        }
        return defaultPrompts;
      } catch (e2) {
        // 如果连默认提示词也获取失败，则抛出原始异常
        throw Exception('获取提示词列表失败: ${e.toString()}');
      }
    }
  }

  @override
  Future<PromptData> getPrompt(AIFeatureType featureType) async {
    try {
      final url = '$_baseUrl/${_convertFeatureTypeToPath(featureType)}';
      final result = await _apiClient.get(url);
      final dto = UserPromptTemplateDto.fromJson(result);

      // 获取默认提示词
      final defaultPrompt = await _getDefaultPrompt(featureType);

      return PromptData(
        userPrompt: dto.promptText,
        defaultPrompt: defaultPrompt,
        isCustomized: true,
      );
    } catch (e) {
      // 如果获取失败，尝试获取默认提示词
      try {
        final defaultPrompt = await _getDefaultPrompt(featureType);
        return PromptData(
          userPrompt: defaultPrompt,
          defaultPrompt: defaultPrompt,
          isCustomized: false,
        );
      } catch (e2) {
        AppLogger.e(_tag, '获取提示词失败: $featureType', e2);
        throw Exception('获取提示词失败: ${e2.toString()}');
      }
    }
  }

  @override
  Future<PromptData> savePrompt(AIFeatureType featureType, String promptText) async {
    try {
      final url = '$_baseUrl/${_convertFeatureTypeToPath(featureType)}';
      final request = UpdatePromptRequest(promptText: promptText);
      final result = await _apiClient.put(url, data: request.toJson());
      final dto = UserPromptTemplateDto.fromJson(result);

      // 获取默认提示词
      final defaultPrompt = await _getDefaultPrompt(featureType);

      return PromptData(
        userPrompt: dto.promptText,
        defaultPrompt: defaultPrompt,
        isCustomized: true,
      );
    } catch (e) {
      AppLogger.e(_tag, '保存提示词失败: $featureType', e);
      throw Exception('保存提示词失败: ${e.toString()}');
    }
  }

  @override
  Future<PromptData> deletePrompt(AIFeatureType featureType) async {
    try {
      final url = '$_baseUrl/${_convertFeatureTypeToPath(featureType)}';
      await _apiClient.delete(url);
      
      // 删除后获取默认提示词
      final defaultPrompt = await _getDefaultPrompt(featureType);
      return PromptData(
        userPrompt: defaultPrompt,
        defaultPrompt: defaultPrompt,
        isCustomized: false,
      );
    } catch (e) {
      AppLogger.e(_tag, '删除提示词失败: $featureType', e);
      throw Exception('删除提示词失败: ${e.toString()}');
    }
  }

  /// 将枚举类型转换为API路径
  String _convertFeatureTypeToPath(AIFeatureType featureType) {
    // 直接使用枚举的名称，不包含类名前缀
    return featureType.toString().split('.').last;
  }

  /// 将功能类型转换为字符串
  String _featureTypeToString(AIFeatureType featureType) {
    switch (featureType) {
      case AIFeatureType.sceneToSummary:
        return 'SCENE_TO_SUMMARY';
      case AIFeatureType.summaryToScene:
        return 'SUMMARY_TO_SCENE';
    }
  }

  /// 获取默认提示词
  Future<String> _getDefaultPrompt(AIFeatureType featureType) async {
    // 这里应该有一个用于获取默认提示词的接口
    // 但如果没有，我们可以使用一些默认值作为备用
    if (featureType == AIFeatureType.sceneToSummary) {
      return '请根据以下场景内容，生成一个简洁的摘要，用于帮助读者快速了解场景的核心内容。';
    } else if (featureType == AIFeatureType.summaryToScene) {
      return '请根据以下摘要，生成一个详细的场景描写，包括情节、对话和必要的环境描述。';
    } else {
      return '请生成内容';
    }
  }

  @override
  Stream<String> generateSceneSummaryStream(String novelId, String sceneId) {
    try {
      AppLogger.i(_tag, '开始流式生成场景摘要，场景ID: $sceneId');
      
      return SseClient().streamEvents<String>(
        path: '/scenes/$sceneId/summarize-stream',
        method: SSERequestType.POST,
        body: {}, // 空请求体
        parser: (json) {
          // 增强解析器的错误处理
          if (json.containsKey('error')) {
            AppLogger.e(_tag, '服务器返回错误: ${json['error']}');
            throw ApiException(-1, '服务器返回错误: ${json['error']}');
          }
          
          if (!json.containsKey('data')) {
            AppLogger.w(_tag, '服务器响应中缺少data字段: $json');
            return ''; // 返回空字符串而不是抛出异常
          }
          
          final data = json['data'];
          if (data == null) {
            AppLogger.w(_tag, '服务器响应中data字段为null');
            return '';
          }
          
          if (data is! String) {
            AppLogger.w(_tag, '服务器响应中data字段不是字符串类型: $data');
            return data.toString();
          }
          
          if (data == '[DONE]') {
            AppLogger.i(_tag, '收到流式生成完成标记: [DONE]');
            return '';
          }
          
          return data;
        },
        connectionId: 'summary_gen_${DateTime.now().millisecondsSinceEpoch}',
      ).where((chunk) => chunk.isNotEmpty); // 过滤掉空字符串
    } catch (e) {
      AppLogger.e(_tag, '流式生成场景摘要失败，场景ID: $sceneId', e);
      return Stream.error(Exception('流式生成场景摘要失败: ${e.toString()}'));
    }
  }
  
  @override
  Future<String> generateSceneSummary({
    required String novelId,
    required String sceneId,
  }) async {
    try {
      AppLogger.i(_tag, '开始收集流式生成的场景摘要，场景ID: $sceneId');
      
      // 使用StringBuffer收集流式结果
      final summary = StringBuffer();
      
      // 订阅流并等待所有块
      await for (final chunk in generateSceneSummaryStream(novelId, sceneId)) {
        summary.write(chunk);
      }
      
      AppLogger.i(_tag, '场景摘要生成完成，场景ID: $sceneId，摘要长度: ${summary.length}');
      return summary.toString();
    } catch (e) {
      AppLogger.e(_tag, '生成场景摘要失败，场景ID: $sceneId', e);
      throw Exception('生成摘要失败: ${e.toString()}');
    }
  }

  @override
  Future<String> generateSceneFromSummary({
    required String novelId,
    required String summary,
  }) async {
    try {
      final url = '/api/novels/$novelId/scenes/generate';
      final request = {
        'summary': summary,
      };

      // 为AI生成请求设置更长的超时时间
      final result = await _apiClient.post(
        url, 
        data: request, 
        options: Options(
          receiveTimeout: const Duration(seconds: 180), // 场景生成可能需要更长时间
          sendTimeout: const Duration(seconds: 120),
        ),
      );

      if (result is Map && result.containsKey('content')) {
        return result['content'] as String;
      } else {
        throw Exception('生成场景失败: 响应格式错误');
      }
    } catch (e) {
      AppLogger.e(_tag, '生成场景内容失败', e);
      throw Exception('生成场景失败: ${e.toString()}');
    }
  }

  // 以下是新增的模板管理和优化相关方法的实现

  @override
  Future<List<PromptTemplate>> getPromptTemplates({
    String templateType = 'ALL',
  }) async {
    try {
      final url = '$_templateBaseUrl?type=$templateType';
      final result = await _apiClient.get(url);
      
      if (result is List) {
        final templates = <PromptTemplate>[];
        for (final item in result) {
          try {
            templates.add(PromptTemplate.fromJson(item));
          } catch (e) {
            AppLogger.e(_tag, '解析提示词模板失败: $item', e);
          }
        }
        return templates;
      } else {
        throw ApiException(-1, '获取提示词模板列表响应格式错误');
      }
    } catch (e) {
      AppLogger.e(_tag, '获取提示词模板列表失败，类型: $templateType', e);
      throw ApiException(-1, '获取提示词模板列表失败: ${e.toString()}');
    }
  }

  @override
  Future<PromptTemplate> getPromptTemplateById(String templateId) async {
    try {
      final url = '$_templateBaseUrl/$templateId';
      final result = await _apiClient.get(url);
      
      return PromptTemplate.fromJson(result);
    } catch (e) {
      AppLogger.e(_tag, '获取提示词模板详情失败，ID: $templateId', e);
      throw ApiException(-1, '获取提示词模板详情失败: ${e.toString()}');
    }
  }

  @override
  Future<PromptTemplate> createPromptTemplate({
    required String name,
    required String content,
    required AIFeatureType featureType,
    required String authorId,
  }) async {
    try {
      final url = _templateBaseUrl;
      final request = {
        'name': name,
        'content': content,
        'featureType': _featureTypeToString(featureType),
        'authorId': authorId,
      };
      
      final result = await _apiClient.post(url, data: request);
      return PromptTemplate.fromJson(result);
    } catch (e) {
      AppLogger.e(_tag, '创建提示词模板失败: $name', e);
      throw ApiException(-1, '创建提示词模板失败: ${e.toString()}');
    }
  }

  @override
  Future<PromptTemplate> updatePromptTemplate({
    required String templateId,
    String? name,
    String? content,
  }) async {
    try {
      // 首先检查权限
      final hasPermission = await hasEditPermission(templateId);
      if (!hasPermission) {
        throw ApiException(403, '无权编辑此模板');
      }
      
      final url = '$_templateBaseUrl/$templateId';
      final request = <String, dynamic>{};
      if (name != null) request['name'] = name;
      if (content != null) request['content'] = content;
      
      if (request.isEmpty) {
        return getPromptTemplateById(templateId); // 没有更新字段，直接返回当前模板
      }
      
      final result = await _apiClient.put(url, data: request);
      return PromptTemplate.fromJson(result);
    } catch (e) {
      AppLogger.e(_tag, '更新提示词模板失败，ID: $templateId', e);
      throw ApiException(-1, '更新提示词模板失败: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePromptTemplate(String templateId) async {
    try {
      // 首先检查权限
      final hasPermission = await hasEditPermission(templateId);
      if (!hasPermission) {
        throw ApiException(403, '无权删除此模板');
      }
      
      final url = '$_templateBaseUrl/$templateId';
      await _apiClient.delete(url);
    } catch (e) {
      AppLogger.e(_tag, '删除提示词模板失败，ID: $templateId', e);
      throw ApiException(-1, '删除提示词模板失败: ${e.toString()}');
    }
  }

  @override
  Future<PromptTemplate> copyPublicTemplate(PromptTemplate template) async {
    try {
      final url = '$_templateBaseUrl/copy/${template.id}';
      final result = await _apiClient.post(url);
      
      return PromptTemplate.fromJson(result);
    } catch (e) {
      AppLogger.e(_tag, '复制公共模板失败，ID: ${template.id}', e);
      throw ApiException(-1, '复制公共模板失败: ${e.toString()}');
    }
  }

  @override
  Future<bool> hasEditPermission(String templateId) async {
    try {
      // 获取模板详情
      final template = await getPromptTemplateById(templateId);
      
      // 只有私有模板且属于当前用户才有编辑权限
      return !template.isPublic && 
             template.authorId == AppConfig.userId;
    } catch (e) {
      AppLogger.e(_tag, '检查模板编辑权限失败，ID: $templateId', e);
      return false; // 出错时保守地返回无权限
    }
  }

  @override
  Future<PromptTemplate> toggleTemplateFavorite(PromptTemplate template) async {
    try {
      final url = '$_templateBaseUrl/${template.id}/favorite';
      final result = await _apiClient.post(url);
      
      return PromptTemplate.fromJson(result);
    } catch (e) {
      AppLogger.e(_tag, '切换模板收藏状态失败，ID: ${template.id}', e);
      throw ApiException(-1, '切换模板收藏状态失败: ${e.toString()}');
    }
  }

  @override
  Future<OptimizationResult> optimizePrompt({
    required String templateId,
    required OptimizePromptRequest request,
  }) async {
    try {
      // 如果有模板ID，先检查权限
      if (templateId.isNotEmpty) {
        final hasPermission = await hasEditPermission(templateId);
        if (!hasPermission) {
          throw ApiException(403, '无权编辑此模板');
        }
      }
      
      final url = '$_templateBaseUrl/${templateId.isEmpty ? "optimize" : "$templateId/optimize"}';
      
      // 为AI生成请求设置更长的超时时间
      final result = await _apiClient.post(
        url, 
        data: request.toJson(), 
        options: Options(
          receiveTimeout: const Duration(seconds: 180),
          sendTimeout: const Duration(seconds: 120),
        ),
      );
      
      return OptimizationResult.fromJson(result);
    } catch (e) {
      AppLogger.e(_tag, '优化提示词模板失败，ID: $templateId', e);
      throw ApiException(-1, '优化提示词模板失败: ${e.toString()}');
    }
  }

  @override
  Stream<OptimizationResult> optimizePromptTemplateStream({
    required String templateId,
    required OptimizePromptRequest request,
  }) async* {
    try {
      // 如果有模板ID，先检查权限
      if (templateId.isNotEmpty) {
        final hasPermission = await hasEditPermission(templateId);
        if (!hasPermission) {
          throw ApiException(403, '无权编辑此模板');
        }
      }
      
      final path = templateId.isEmpty 
          ? '$_templateBaseUrl/optimize-stream'
          : '$_templateBaseUrl/$templateId/optimize-stream';
      
      AppLogger.i(_tag, '开始流式优化提示词模板，ID: $templateId');
      
      final stream = SseClient().streamEvents<OptimizationResult>(
        path: path,
        method: SSERequestType.POST,
        body: request.toJson(),
        parser: (json) {
          // 处理错误
          if (json.containsKey('error')) {
            AppLogger.e(_tag, '服务器返回错误: ${json['error']}');
            throw ApiException(-1, '服务器返回错误: ${json['error']}');
          }
          
          return OptimizationResult.fromJson(json);
        },
        connectionId: 'template_optimize_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      yield* stream;
    } catch (e) {
      AppLogger.e(_tag, '流式优化提示词模板失败，ID: $templateId', e);
      throw ApiException(-1, '流式优化提示词模板失败: ${e.toString()}');
    }
  }

  @override
  Future<List<PromptTemplate>> getPromptTemplatesByFeatureType(AIFeatureType featureType) async {
    try {
      final url = '$_templateBaseUrl?featureType=${_featureTypeToString(featureType)}';
      final result = await _apiClient.get(url);
      
      if (result is List) {
        final templates = <PromptTemplate>[];
        for (final item in result) {
          try {
            templates.add(PromptTemplate.fromJson(item));
          } catch (e) {
            AppLogger.e(_tag, '解析提示词模板失败: $item', e);
          }
        }
        return templates;
      } else {
        throw ApiException(-1, '获取提示词模板列表响应格式错误');
      }
    } catch (e) {
      AppLogger.e(_tag, '获取指定功能类型的提示词模板列表失败，类型: $featureType', e);
      throw ApiException(-1, '获取提示词模板列表失败: ${e.toString()}');
    }
  }

  @override
  void cancelOptimization() {
    // 取消当前正在进行的优化操作
    try {
      AppLogger.i(_tag, '取消优化请求');
      // 使用SseClient的cancelConnection方法而不是disconnect方法
      SseClient().cancelConnection('template_optimize_${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      AppLogger.e(_tag, '取消优化请求失败', e);
    }
  }

  @override
  void optimizePromptStream(
    String templateId,
    OptimizePromptRequest request, {
    Function(double)? onProgress,
    Function(OptimizationResult)? onResult,
    Function(String)? onError,
  }) {
    try {
      // 如果有模板ID，先检查权限
      if (templateId.isNotEmpty) {
        hasEditPermission(templateId).then((hasPermission) {
          if (!hasPermission) {
            if (onError != null) {
              onError('无权编辑此模板');
            }
            return;
          }
          _startOptimizationStream(templateId, request, onProgress, onResult, onError);
        }).catchError((e) {
          if (onError != null) {
            onError('检查权限失败: ${e.toString()}');
          }
        });
      } else {
        _startOptimizationStream(templateId, request, onProgress, onResult, onError);
      }
    } catch (e) {
      AppLogger.e(_tag, '启动流式优化失败', e);
      if (onError != null) {
        onError('启动流式优化失败: ${e.toString()}');
      }
    }
  }
  
  /// 启动优化流处理
  void _startOptimizationStream(
    String templateId,
    OptimizePromptRequest request,
    Function(double)? onProgress,
    Function(OptimizationResult)? onResult,
    Function(String)? onError,
  ) {
    final path = templateId.isEmpty 
        ? '$_templateBaseUrl/optimize-stream'
        : '$_templateBaseUrl/$templateId/optimize-stream';
    
    AppLogger.i(_tag, '开始流式优化提示词，模板ID: $templateId');
    
    try {
      final stream = SseClient().streamEvents<Map<String, dynamic>>(
        path: path,
        method: SSERequestType.POST,
        body: request.toJson(),
        parser: (json) {
          // 处理错误
          if (json.containsKey('error')) {
            AppLogger.e(_tag, '服务器返回错误: ${json['error']}');
            throw ApiException(-1, '服务器返回错误: ${json['error']}');
          }
          
          // 处理进度
          if (json.containsKey('progress') && onProgress != null) {
            final double progress = (json['progress'] as num).toDouble();
            onProgress(progress);
          }
          
          return json;
        },
        connectionId: 'template_optimize_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      // 订阅流事件
      stream.listen(
        (json) {
          // 如果是结果数据，解析并调用回调
          if (json.containsKey('optimizedContent') && onResult != null) {
            try {
              final result = OptimizationResult.fromJson(json);
              onResult(result);
            } catch (e) {
              AppLogger.e(_tag, '解析优化结果失败', e);
              if (onError != null) {
                onError('解析优化结果失败: ${e.toString()}');
              }
            }
          }
        },
        onError: (e) {
          AppLogger.e(_tag, '流式优化错误', e);
          if (onError != null) {
            onError('流式优化错误: ${e.toString()}');
          }
        },
        onDone: () {
          AppLogger.i(_tag, '流式优化完成');
        },
      );
    } catch (e) {
      AppLogger.e(_tag, '创建流式优化失败', e);
      if (onError != null) {
        onError('创建流式优化失败: ${e.toString()}');
      }
    }
  }
}