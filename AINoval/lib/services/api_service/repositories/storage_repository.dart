import 'dart:typed_data';

abstract class StorageRepository {
  /// 获取封面上传凭证
  Future<Map<String, dynamic>> getCoverUploadCredential({
    required String novelId,
    required String fileName,
    String? contentType,
  });

  /// 上传封面图片
  Future<String> uploadCoverImage({
    required String novelId,
    required Uint8List fileBytes,
    required String fileName,
    String? contentType,
  });

  /// 获取文件访问URL
  Future<String> getFileAccessUrl({
    required String fileKey,
    int? expirationSeconds,
  });

  /// 检查用户是否有有效的上传配置
  Future<bool> hasValidStorageConfig();
} 