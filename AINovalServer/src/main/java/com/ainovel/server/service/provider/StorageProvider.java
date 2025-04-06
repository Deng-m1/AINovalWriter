package com.ainovel.server.service.provider;

import java.util.Map;

import reactor.core.publisher.Mono;

/**
 * 存储提供者接口 定义了文件存储服务的通用操作，支持不同的存储实现（如阿里云OSS、AWS S3等）
 */
public interface StorageProvider {

    /**
     * 获取上传凭证
     *
     * @param key 文件存储的键（路径+文件名）
     * @param contentType 文件内容类型
     * @param expiration 过期时间（秒）
     * @return 包含上传所需参数的Map
     */
    Mono<Map<String, String>> generateUploadCredential(String key, String contentType, long expiration);

    /**
     * 获取文件访问URL
     *
     * @param key 文件存储的键（路径+文件名）
     * @param expiration 过期时间（秒），如果为0则返回永久URL
     * @return 文件访问URL
     */
    Mono<String> getFileUrl(String key, long expiration);

    /**
     * 删除文件
     *
     * @param key 文件存储的键（路径+文件名）
     * @return 操作结果
     */
    Mono<Boolean> deleteFile(String key);

    /**
     * 检查文件是否存在
     *
     * @param key 文件存储的键（路径+文件名）
     * @return 文件是否存在
     */
    Mono<Boolean> doesFileExist(String key);

    /**
     * 获取存储提供者名称
     *
     * @return 存储提供者名称
     */
    String getProviderName();
}
