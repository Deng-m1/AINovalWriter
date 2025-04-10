import 'dart:typed_data';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter_oss_aliyun/flutter_oss_aliyun.dart';
import 'package:mime/mime.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

/// 阿里云OSS存储仓库实现，使用 POST Policy 上传
class AliyunOssStorageRepository implements StorageRepository {
  final ApiClient _apiClient;
  Client? _ossClient;
  final Dio _dio = Dio();
  Map<String, dynamic>? _lastCredential;

  AliyunOssStorageRepository(this._apiClient);

  @override
  Future<Map<String, dynamic>> getCoverUploadCredential({
    required String novelId,
    required String fileName,
    String? contentType,
  }) async {
    try {
      // 参数校验
      if (novelId.isEmpty) {
        throw ApiException(-1, '小说ID不能为空');
      }
      
      // 使用默认文件名
      final String safeFileName = fileName.isEmpty ? 'cover.jpg' : fileName;
      
      // 获取MIME类型（如果未提供）
      final String mimeType = contentType ?? _getMimeType(safeFileName);
      
      // 调用后端API获取 POST Policy 上传凭证
      final credential = await _apiClient.getCoverUploadCredential(novelId);

      // 校验返回的凭证是否包含 POST Policy 必要字段
      final requiredFields = ['accessKeyId', 'policy', 'signature', 'key', 'host'];
      final missingFields = requiredFields.where((field) =>
          !credential.containsKey(field) ||
          credential[field] == null ||
          credential[field].toString().isEmpty).toList();

      if (missingFields.isNotEmpty) {
        throw ApiException(
            -1, '获取上传凭证失败：缺少必要字段 ${missingFields.join(', ')}');
      }

      // 存储凭证，如果需要重新初始化客户端时使用
      _lastCredential = Map<String, dynamic>.from(credential);

      // 添加前端需要的额外信息
      credential['fileName'] = safeFileName;
      credential['contentType'] = mimeType;

      AppLogger.d(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '获取 POST Policy 上传凭证成功：${credential.keys.join(', ')}',
      );
      return credential;
    } catch (e) {
      AppLogger.e(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '获取上传凭证失败',
        e,
        (e is DioException) ? e.stackTrace : StackTrace.current,
      );
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(-1, '获取上传凭证失败: $e');
    }
  }

  @override
  Future<String> uploadCoverImage({
    required String novelId,
    required Uint8List fileBytes,
    required String fileName,
    String? contentType,
  }) async {
    try {
      // 参数校验
      if (fileBytes.isEmpty) throw ApiException(-1, '上传内容为空');
      final safeFileName = fileName.isEmpty ? 'cover.jpg' : fileName;
      final mimeType = contentType ?? _getMimeType(safeFileName);

      // 获取 POST Policy 上传凭证
      final credential = await getCoverUploadCredential(
        novelId: novelId,
        fileName: safeFileName,
        contentType: mimeType,
      );

      AppLogger.d(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '准备使用 POST Policy 上传，凭证字段: ${credential.keys.join(', ')}',
      );

      // 从凭证中提取必要字段
      final String key = credential['key'].toString();
      final String policy = credential['policy'].toString();
      final String accessKeyId = credential['accessKeyId'].toString(); // Should be 'OSSAccessKeyId' in form
      final String signature = credential['signature'].toString();
      final String host = credential['host'].toString(); // Upload URL
      // final String? callback = credential['callback']?.toString(); // Optional callback

      // 准备 FormData
      final formData = FormData.fromMap({
        'key': key,
        'policy': policy,
        'OSSAccessKeyId': accessKeyId, // Field name expected by OSS
        'signature': signature,
        'success_action_status': '200', // Or '204' - request success status
        'Content-Type': mimeType, // Explicitly set Content-Type for the request part
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: safeFileName, // Use the safe file name
          contentType: MediaType.parse(mimeType), // Use MediaType for content type
        ),
        // if (callback != null) 'callback': callback, // Add callback if present
      });

      AppLogger.d(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '开始 POST Policy 上传文件: host=$host, key=$key, size=${fileBytes.length}, contentType=$mimeType',
      );

      try {
        // 使用 Dio 发送 POST 请求
        final response = await _dio.post(
          host,
          data: formData,
          onSendProgress: (count, total) {
            // Optional: Handle progress update
             AppLogger.d(
               'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
               '上传进度: $count/$total',
             );
          },
          options: Options(
            // OSS might return 200 or 204 on success depending on configuration
            // Dio considers only 2xx as success by default.
            // We check manually below.
            followRedirects: false,
            validateStatus: (status) {
              return status != null; // Accept any status code, validate below
            },
          ),
        );

        // 检查响应状态
        if (response.statusCode != 200 && response.statusCode != 204) {
           String errorBody = response.data?.toString() ?? 'No response body';
           // OSS often returns XML errors for POST uploads
           if (errorBody.contains('<Code>') && errorBody.contains('<Message>')) {
               // Try to extract OSS error details
               final codeMatch = RegExp(r'<Code>(.*?)<\/Code>').firstMatch(errorBody);
               final messageMatch = RegExp(r'<Message>(.*?)<\/Message>').firstMatch(errorBody);
               errorBody = 'OSS Error: Code=${codeMatch?.group(1) ?? 'Unknown'}, Message=${messageMatch?.group(1) ?? 'Unknown'}';
           }

           AppLogger.e(
            'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
            'OSS POST Policy 上传失败，状态码: ${response.statusCode}, 消息: ${response.statusMessage ?? errorBody}',
            Exception('OSS POST Policy Upload Failed'),
            StackTrace.current,
          );
          throw ApiException(response.statusCode ?? -1, '上传失败: ${response.statusMessage ?? errorBody}');
        }

        AppLogger.i(
          'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
          'POST Policy 上传成功',
        );

        // 构建文件URL (This might need adjustment depending on 'host' format)
        // If host is like 'https://bucket.endpoint', URL is host + / + key
        // If host is like 'https://endpoint' and bucket is separate, adjust accordingly.
        // Assuming host is the base URL for the object.
        final String fileUrl = '$host/$key'; // Simplistic assumption, adjust if needed

        AppLogger.i(
          'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
          '上传完成，文件URL: $fileUrl',
        );

        // 通知后端更新封面URL
        await _apiClient.updateNovelCover(novelId, fileUrl);

        return fileUrl;

      } on DioException catch (e) {
        String errorDetails = e.message ?? e.toString();
        if (e.response != null) {
          errorDetails += "\nResponse Status: ${e.response?.statusCode}";
          errorDetails += "\nResponse Data: ${e.response?.data}";
        }
         AppLogger.e(
          'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
          '上传过程中发生网络或服务器错误: $errorDetails', // FIX LINTER: Merge details into message
          e, // 记录原始异常
          e.stackTrace, // Pass the stack trace
        );
        throw ApiException(e.response?.statusCode ?? -1, '上传失败: $errorDetails');
      } catch (e, s) {
        // 处理其他类型的异常
        AppLogger.e(
          'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
          '上传过程中发生未知错误',
          e,
          s,
        );
        throw ApiException(-1, '上传失败: ${e.toString()}');
      }
    } catch (e, s) {
      AppLogger.e(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '上传封面图片失败 (外部捕获)',
        e,
        s,
      );
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(-1, '上传封面图片失败: $e');
    }
  }

  @override
  Future<String> getFileAccessUrl({
    required String fileKey,
    int? expirationSeconds,
  }) async {
    if (_ossClient == null && _lastCredential != null) {
       try {
          _initOssClient(_lastCredential!);
       } catch (e) {
          AppLogger.e(
            'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
            'Failed to re-initialize OSS client for getFileAccessUrl',
            e,
            StackTrace.current
          );
          // Fallback: Return non-signed URL if client init fails
          return _buildFileUrlFromKey(fileKey);
       }
    }

    if (_ossClient == null) {
      AppLogger.w(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        'OSS Client not initialized for getFileAccessUrl, returning non-signed URL.',
      );
      // Fallback: Return non-signed URL if client is not initialized
      return _buildFileUrlFromKey(fileKey);
    }

    try {
      // This assumes _ossClient was initialized correctly with STS creds
      final url = await _ossClient!.getSignedUrl(
          fileKey
      );
      return url;
    } catch (e, s) {
      AppLogger.e(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '获取文件访问URL失败 (getSignedUrl)',
        e,
        s,
      );
      // Fallback: Return non-signed URL on error
      return _buildFileUrlFromKey(fileKey);
    }
  }

  @override
  Future<bool> hasValidStorageConfig() async {
    try {
      // Test by attempting to get credentials for a dummy file
      await getCoverUploadCredential(
        novelId: 'test_config', // Use a distinct ID for testing
        fileName: 'test.jpg',
      );
      // We assume if credentials are fetched, the config is likely valid enough
      // A full test would involve a small test upload.
      return true;
    } catch (e) {
       AppLogger.w(
         'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
         'hasValidStorageConfig check failed',
         e
       );
      return false;
    }
  }
  
  /// 初始化或更新OSS客户端实例
  void _initOssClient(Map<String, dynamic> credential) {
    try {
      // 从凭证中提取 STS 或 AK/SK 信息
      final accessKeyId = credential['accessKeyId']?.toString();
      final accessKeySecret = credential['accessKeySecret']?.toString();
      final securityToken = credential['securityToken']?.toString(); // STS Token
      final endpoint = credential['endpoint']?.toString();
      final bucketName = credential['bucket']?.toString();
      final expiration = credential['expiration']?.toString(); // STS凭证过期时间 (ISO 8601)

      // 校验必要参数
      if (accessKeyId == null || accessKeyId.isEmpty ||
          accessKeySecret == null || accessKeySecret.isEmpty ||
          // securityToken 对于 STS 是必需的
          (securityToken == null || securityToken.isEmpty) ||
          endpoint == null || endpoint.isEmpty ||
          bucketName == null || bucketName.isEmpty) {
        throw ApiException(-1, 'OSS客户端初始化失败：凭证缺少必要参数 (Id, Secret, Token, Endpoint, Bucket)');
      }

      // 检查凭证是否已过期 (可选但推荐)
      DateTime? expireTime;
      if (expiration != null) {
          try {
             expireTime = DateTime.parse(expiration).toUtc();
             // 留一些缓冲时间，比如提前5分钟认为过期
             if (DateTime.now().toUtc().isAfter(expireTime.subtract(const Duration(minutes: 5)))) {
                AppLogger.w('Services/api_service/repositories/impl/aliyun_oss_storage_repository', 'STS凭证即将或已经过期，建议重新获取');
                // 这里可以决定是否强制重新获取凭证，或者让后续操作失败
             }
          } catch(e) {
             AppLogger.w('Services/api_service/repositories/impl/aliyun_oss_storage_repository', '解析凭证过期时间失败: $expiration', e);
          }
      }

      AppLogger.d(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '初始化OSS客户端: endpoint=$endpoint, bucket=$bucketName, 使用STS凭证',
      );

      // 使用 STS 凭证初始化 Client
      // 确保 flutter_oss_aliyun 支持直接传入 STS token
      _ossClient = Client.init(
        // region: credential['region']?.toString(), // 如果需要指定 region
        ossEndpoint: endpoint, // 使用后端提供的 endpoint
        bucketName: bucketName, // 使用后端提供的 bucket
        // signVersion: SignVersion.V4, // 显式指定V4 (如果SDK支持)
        authGetter: () => Auth(
          accessKey: accessKeyId,
          accessSecret: accessKeySecret,
          secureToken: securityToken, // 传递 STS Token
          expire: expiration ?? DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        ),
      );

      AppLogger.i(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        'OSS客户端初始化成功 (使用STS凭证)',
      );
    } catch (e) {
      AppLogger.e(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '初始化OSS客户端失败',
        e,
      );
       _ossClient = null; // 初始化失败，清空客户端
      if (e is ApiException) rethrow;
      throw ApiException(-1, '初始化OSS客户端失败: $e');
    }
  }
  
  /// 根据凭证构建文件URL
  String _buildFileUrl(Map<String, dynamic> credential) {
    // 优先使用后端可能直接提供的 fileUrl 字段 (如果后端逻辑包含)
    if (credential.containsKey('fileUrl') && credential['fileUrl'] != null && credential['fileUrl'].toString().isNotEmpty) {
       return credential['fileUrl'].toString();
    }

    // 从 endpoint, bucket, key 构建标准 OSS URL
    final endpoint = credential['endpoint']?.toString() ?? '';
    final bucket = credential['bucket']?.toString() ?? '';
    final key = credential['key']?.toString() ?? '';

    if (endpoint.isEmpty || bucket.isEmpty || key.isEmpty) {
       AppLogger.w('Services/api_service/repositories/impl/aliyun_oss_storage_repository', '无法构建文件URL，缺少 endpoint, bucket 或 key');
       return 'error_url_build_failed'; // 返回错误标识或抛出异常
    }

    // 确保 endpoint 不包含协议头，并移除末尾斜杠
    String cleanEndpoint = endpoint.replaceAll(RegExp(r'^https?://'), '');
    if (cleanEndpoint.endsWith('/')) {
      cleanEndpoint = cleanEndpoint.substring(0, cleanEndpoint.length - 1);
    }

    // 确保 key 不以斜杠开头
    String cleanKey = key;
    if (cleanKey.startsWith('/')) {
      cleanKey = cleanKey.substring(1);
    }

    // 构建 URL: https://bucket.endpoint/key
    return 'https://$bucket.$cleanEndpoint/$cleanKey';
  }
  
  /// Builds a potentially non-signed URL just from the key
  /// Requires _lastCredential to have endpoint/bucket info.
  String _buildFileUrlFromKey(String key) {
      final endpoint = _lastCredential?['endpoint']?.toString();
      final bucket = _lastCredential?['bucket']?.toString(); // Bucket might not be in POST creds

      if (endpoint == null || endpoint.isEmpty || bucket == null || bucket.isEmpty) {
         AppLogger.w('Services/api_service/repositories/impl/aliyun_oss_storage_repository',
            'Cannot build file URL from key, missing endpoint/bucket in last credential');
         return key; // Return key as fallback
      }

      String cleanEndpoint = endpoint.replaceAll(RegExp(r'^https?://'), '');
      if (cleanEndpoint.endsWith('/')) {
        cleanEndpoint = cleanEndpoint.substring(0, cleanEndpoint.length - 1);
      }
      String cleanKey = key;
      if (cleanKey.startsWith('/')) {
        cleanKey = cleanKey.substring(1);
      }
      return 'https://$bucket.$cleanEndpoint/$cleanKey';
  }
  
  /// 根据文件名获取MIME类型
  String _getMimeType(String fileName) {
    final mimeType = lookupMimeType(fileName);
    return mimeType ?? 'application/octet-stream';
  }
} 