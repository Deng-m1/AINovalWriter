package com.ainovel.server.service;

import java.util.Map;

import reactor.core.publisher.Mono;

/**
 * 存储服务接口 提供文件存储相关的高级操作
 */
public interface StorageService {

    /**
     * 获取封面上传凭证
     *
     * @param novelId 小说ID
     * @param fileName 文件名
     * @param contentType 内容类型（可选）
     * @return 上传凭证
     */
    Mono<Map<String, String>> getCoverUploadCredential(String novelId, String fileName, String contentType);

    /**
     * 获取封面URL
     *
     * @param coverKey 封面文件的完整路径键
     * @param expiration 过期时间（秒）
     * @return 封面URL
     */
    Mono<String> getCoverUrl(String coverKey, long expiration);

    /**
     * 生成封面存储键
     *
     * @param novelId 小说ID
     * @param fileName 文件名
     * @return 存储键
     */
    String generateCoverKey(String novelId, String fileName);

    /**
     * 删除封面文件
     *
     * @param coverKey 封面文件的完整路径键
     * @return 操作结果
     */
    Mono<Boolean> deleteCover(String coverKey);

    /**
     * 检查封面是否存在
     *
     * @param coverKey 封面文件的完整路径键
     * @return 是否存在
     */
    Mono<Boolean> doesCoverExist(String coverKey);
}
