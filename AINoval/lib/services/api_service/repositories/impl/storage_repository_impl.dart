import 'dart:typed_data';

import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
import 'package:ainoval/services/api_service/repositories/impl/aliyun_oss_storage_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

/// 默认存储库实现
class StorageRepositoryImpl implements StorageRepository {
  final ApiClient _apiClient;

  StorageRepositoryImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> getCoverUploadCredential({
    required String novelId,
    required String fileName,
    String? contentType,
  }) async {
    try {
      // 获取MIME类型（如果未提供）
      final String mimeType = contentType ?? _getMimeType(fileName);
      
      // 调用后端API获取上传凭证
      // ApiClient现在已经在内部处理fileName和contentType参数
      final credential = await _apiClient.getCoverUploadCredential(novelId);
      
      if (credential is! Map<String, dynamic>) {
        throw ApiException(-1, '获取上传凭证失败：返回类型错误');
      }
      
      // 添加额外信息到凭证中（如果不存在）
      if (!credential.containsKey('contentType')) {
        credential['contentType'] = mimeType;
      }
      if (!credential.containsKey('fileName')) {
        credential['fileName'] = fileName;
      }
      
      // 记录结果，以便于调试
      AppLogger.d(
        'Services/api_service/repositories/impl/storage_repository_impl',
        '获取上传凭证成功：包含字段 ${credential.keys.join(', ')}',
      );
      
      return credential;
    } catch (e) {
      AppLogger.e(
        'Services/api_service/repositories/impl/storage_repository_impl',
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
      
      // 如果host是oss://开头，说明是阿里云OSS，需要特殊处理
      if (credential.containsKey('host') && credential['host'].toString().startsWith('oss://')) {
        // 使用AliyunOssStorageRepository处理
        AppLogger.d(
          'Services/api_service/repositories/impl/storage_repository_impl',
          '检测到阿里云OSS URL，切换到专用处理方式',
        );
        
        final ossSr = AliyunOssStorageRepository(_apiClient);
        return await ossSr.uploadCoverImage(
          novelId: novelId,
          fileBytes: fileBytes,
          fileName: fileName,
          contentType: contentType,
        );
      }
      
      // 检查必要参数 - 处理阿里云OSS凭证
      if (credential.containsKey('host') && 
          credential.containsKey('key') && 
          credential.containsKey('policy') && 
          credential.containsKey('signature') && 
          credential.containsKey('accessKeyId')) {
        // 阿里云OSS上传
        final uri = Uri.parse(credential['host']);
        final request = http.MultipartRequest('POST', uri);
        
        // 添加OSS表单字段
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
          contentType: mimeType.isNotEmpty ? null : null,
        ));
        
        // 发送请求
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        // 检查响应
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException(response.statusCode, '上传失败: ${response.body}');
        }
        
        // 构建文件URL并返回
        final fileUrl = '${credential['host']}/${credential['key']}';
        
        // 通知后端上传完成，更新小说封面URL
        await _apiClient.updateNovelCover(novelId, fileUrl);
        
        return fileUrl;
      }
      // 原来的通用上传实现
      else if (credential.containsKey('uploadUrl') && credential.containsKey('formFields')) {
        // 原有的通用上传逻辑
        final uri = Uri.parse(credential['uploadUrl']);
        final request = http.MultipartRequest('POST', uri);
        
        // 添加表单字段
        final formFields = credential['formFields'] as Map<String, dynamic>;
        formFields.forEach((key, value) {
          request.fields[key] = value.toString();
        });
        
        // 添加文件
        final mimeType = contentType ?? _getMimeType(fileName);
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: mimeType.isNotEmpty ? null : null,
        ));
        
        // 发送请求
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        // 检查响应
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException(response.statusCode, '上传失败: ${response.body}');
        }
        
        // 获取文件URL
        String fileUrl = '';
        if (credential.containsKey('fileUrl')) {
          fileUrl = credential['fileUrl'];
        } else {
          // 从响应中解析URL
          try {
            final responseData = Uri.parse(response.body);
            fileUrl = responseData.toString();
          } catch (e) {
            // 如果无法解析响应，使用预定的URL格式
            fileUrl = '${credential['baseUrl']}/${credential['key']}';
          }
        }
        
        // 通知后端上传完成，更新小说封面URL
        await _apiClient.updateNovelCover(novelId, fileUrl);
        
        return fileUrl;
      } else {
        throw ApiException(-1, '上传凭证格式不支持: ${credential.keys.join(', ')}');
      }
    } catch (e) {
      AppLogger.e(
        'Services/api_service/repositories/impl/storage_repository_impl',
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
    return fileKey;
  }

  @override
  Future<bool> hasValidStorageConfig() async {
    try {
      // 尝试获取测试小说的上传凭证，如果成功则认为配置有效
      await _apiClient.getCoverUploadCredential('test');
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