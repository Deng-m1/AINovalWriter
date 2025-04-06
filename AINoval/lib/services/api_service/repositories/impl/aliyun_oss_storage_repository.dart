import 'dart:convert';
import 'dart:typed_data';


import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../../base/api_client.dart';
import '../../base/api_exception.dart';

/// 阿里云OSS存储仓库实现
class AliyunOssStorageRepository implements StorageRepository {
  final ApiClient _apiClient;

  AliyunOssStorageRepository(this._apiClient);

  @override
  Future<Map<String, dynamic>> getCoverUploadCredential({
    required String novelId,
    required String fileName,
    String? contentType,
  }) async {
    try {
      // 检测MIME类型（如果未提供）
      final String mimeType = contentType ?? _getMimeType(fileName);
      
      // 调用后端API获取上传凭证
      final response = await _apiClient.post(
        '/novels/$novelId/cover-upload-credential',
        data: {
          'fileName': fileName,
          'contentType': mimeType,
        },
      );
      
      if (response is! Map<String, dynamic>) {
        throw ApiException(-1, '获取上传凭证失败：返回类型错误');
      }
      
      return response;
    } catch (e) {
      AppLogger.e(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '获取上传凭证失败',
        e,
      );
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
      // 获取上传凭证
      final credential = await getCoverUploadCredential(
        novelId: novelId,
        fileName: fileName,
        contentType: contentType,
      );
      
      // 检查必要参数
      if (!credential.containsKey('host') || 
          !credential.containsKey('key') ||
          !credential.containsKey('policy') ||
          !credential.containsKey('signature') ||
          !credential.containsKey('accessKeyId')) {
        throw ApiException(-1, '上传凭证缺少必要参数');
      }
      
      // 准备表单数据
      final uri = Uri.parse(credential['host']);
      final request = http.MultipartRequest('POST', uri);
      
      // 添加OSS所需表单字段
      request.fields['key'] = credential['key'];
      request.fields['policy'] = credential['policy'];
      request.fields['signature'] = credential['signature'];
      request.fields['OSSAccessKeyId'] = credential['accessKeyId'];
      request.fields['success_action_status'] = '200';
      
      // 如果有内容类型，添加到表单中
      if (credential.containsKey('contentType')) {
        request.fields['Content-Type'] = credential['contentType'];
      }
      
      // 添加文件
      final mimeType = contentType ?? _getMimeType(fileName);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: mimeType.isNotEmpty ? null : null, // 仅在MIME类型有效时添加
      ));
      
      // 发送请求
      final response = await request.send();
      
      // 检查响应
      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        throw ApiException(response.statusCode, '上传失败: $responseBody');
      }
      
      // 构建文件URL并返回
      final fileUrl = '${credential['host']}/${credential['key']}';
      
      // 通知后端上传完成，更新小说封面URL
      await _apiClient.post(
        '/novels/$novelId/cover',
        data: {'coverUrl': fileUrl},
      );
      
      return fileUrl;
    } catch (e) {
      AppLogger.e(
        'Services/api_service/repositories/impl/aliyun_oss_storage_repository',
        '上传封面图片失败',
        e,
      );
      throw ApiException(-1, '上传封面图片失败: $e');
    }
  }

  @override
  Future<String> getFileAccessUrl({
    required String fileKey,
    int? expirationSeconds,
  }) async {
    // 对于公开读权限的文件，直接返回URL
    // 如果需要私有读权限，需要调用后端生成签名URL
    return fileKey;
  }

  @override
  Future<bool> hasValidStorageConfig() async {
    try {
      // 此方法可用于检查是否有有效的存储配置
      // 简单实现：尝试获取上传凭证，如果成功则认为配置有效
      await getCoverUploadCredential(
        novelId: 'test',
        fileName: 'test.jpg',
      );
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 根据文件名获取MIME类型
  String _getMimeType(String fileName) {
    final mimeType = lookupMimeType(fileName);
    return mimeType ?? 'application/octet-stream';
  }
} 