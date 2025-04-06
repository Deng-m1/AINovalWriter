package com.ainovel.server.service.provider;

import java.net.URL;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ainovel.server.config.StorageConfig.AliOssProperties;
import com.ainovel.server.config.StorageConfig.StorageProperties;
import com.aliyun.oss.ClientBuilderConfiguration;
import com.aliyun.oss.OSS;
import com.aliyun.oss.OSSClientBuilder;
import com.aliyun.oss.common.comm.SignVersion;
import com.aliyun.oss.common.utils.BinaryUtil;
import com.aliyun.oss.model.MatchMode;
import com.aliyun.oss.model.PolicyConditions;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * 阿里云OSS存储提供者实现
 */
@Slf4j
@Service("aliOSSStorageProvider")
public class AliOSSStorageProvider implements StorageProvider {

    private final String endpoint;
    private final String accessKeyId;
    private final String accessKeySecret;
    private final String bucketName;
    private final String baseUrl;
    private final String region;

    @Autowired
    public AliOSSStorageProvider(StorageProperties storageProperties) {
        AliOssProperties aliOssProps = storageProperties.getAliyun();
        this.endpoint = aliOssProps.getEndpoint();
        this.accessKeyId = aliOssProps.getAccessKeyId();
        this.accessKeySecret = aliOssProps.getAccessKeySecret();
        this.bucketName = aliOssProps.getBucketName();
        this.baseUrl = aliOssProps.getBaseUrl();
        this.region = aliOssProps.getRegion();

        log.info("初始化阿里云OSS存储提供者: endpoint={}, bucket={}, region={}, baseUrl={}",
                endpoint, bucketName, region, baseUrl != null ? baseUrl : "未配置");
    }

    /**
     * 获取OSS客户端实例
     */
    private OSS getOSSClient() {
        // 创建ClientBuilderConfiguration实例并配置签名版本
        ClientBuilderConfiguration conf = new ClientBuilderConfiguration();
        // 显式指定使用V4签名算法
        conf.setSignatureVersion(SignVersion.V4);

        // 优先使用配置中指定的region，如果未配置则尝试从endpoint提取
        String regionToUse = region;
        if (regionToUse == null || regionToUse.isEmpty()) {
            regionToUse = extractRegionFromEndpoint(endpoint);
            if (regionToUse != null) {
                log.info("从endpoint提取到region: {}", regionToUse);
            }
        }

        if (regionToUse != null && !regionToUse.isEmpty()) {
            // 使用V4签名需要指定region
            return OSSClientBuilder.create()
                    .endpoint(endpoint)
                    .credentialsProvider(new com.aliyun.oss.common.auth.DefaultCredentialProvider(accessKeyId, accessKeySecret))
                    .clientConfiguration(conf)
                    .region(regionToUse)
                    .build();
        } else {
            // 如果无法提取region，回退到旧方式构建
            log.warn("未配置region且无法从endpoint提取region信息，将使用不指定region的方式初始化OSS客户端");
            return new OSSClientBuilder().build(endpoint, accessKeyId, accessKeySecret, conf);
        }
    }

    /**
     * 从endpoint提取region信息 例如：从 https://oss-cn-hangzhou.aliyuncs.com 提取
     * cn-hangzhou
     */
    private String extractRegionFromEndpoint(String endpoint) {
        try {
            // 移除协议部分
            String noProtocol = endpoint.replaceAll("^https?://", "");
            // 查找第一个点的位置
            int dotIndex = noProtocol.indexOf('.');
            if (dotIndex <= 0) {
                return null;
            }

            // 提取 oss-cn-hangzhou 部分
            String prefix = noProtocol.substring(0, dotIndex);
            // 如果以 oss- 开头，去掉 oss- 前缀
            if (prefix.startsWith("oss-")) {
                return prefix.substring(4);
            } else {
                return null;
            }
        } catch (Exception e) {
            log.warn("从endpoint提取region时出错: {}", e.getMessage());
            return null;
        }
    }

    @Override
    public Mono<Map<String, String>> generateUploadCredential(String key, String contentType, long expiration) {
        return Mono.fromCallable(() -> {
            OSS ossClient = null;
            try {
                ossClient = getOSSClient();

                // 生成过期时间
                long expireTime = expiration > 0 ? expiration : 30 * 60; // 默认30分钟
                long expireEndTime = System.currentTimeMillis() + expireTime * 1000;
                Date expireDate = new Date(expireEndTime);

                // 设置上传策略
                PolicyConditions policyConditions = new PolicyConditions();
                policyConditions.addConditionItem(PolicyConditions.COND_CONTENT_LENGTH_RANGE, 0, 10 * 1024 * 1024); // 限制大小10MB
                policyConditions.addConditionItem(MatchMode.StartWith, PolicyConditions.COND_KEY, key);

                // 生成策略
                String postPolicy = ossClient.generatePostPolicy(expireDate, policyConditions);
                byte[] binaryData = postPolicy.getBytes("utf-8");
                String encodedPolicy = BinaryUtil.toBase64String(binaryData);
                String postSignature = ossClient.calculatePostSignature(postPolicy);

                // 构建返回结果
                Map<String, String> result = new HashMap<>();
                result.put("accessKeyId", accessKeyId);
                result.put("policy", encodedPolicy);
                result.put("signature", postSignature);
                result.put("key", key);
                result.put("expire", String.valueOf(expireEndTime / 1000));
                result.put("host", getUploadHost());

                if (contentType != null && !contentType.isEmpty()) {
                    result.put("contentType", contentType);
                }

                log.info("生成阿里云OSS上传凭证成功: key={}", key);
                return result;
            } catch (Exception e) {
                log.error("生成阿里云OSS上传凭证失败", e);
                throw e;
            } finally {
                if (ossClient != null) {
                    ossClient.shutdown();
                }
            }
        });
    }

    @Override
    public Mono<String> getFileUrl(String key, long expiration) {
        return Mono.fromCallable(() -> {
            OSS ossClient = null;
            try {
                // 检查是否有配置自定义域名
                if (baseUrl != null && !baseUrl.isEmpty()) {
                    return String.format("%s/%s", baseUrl.replaceAll("/$", ""), key);
                }

                ossClient = getOSSClient();

                // 如果有效期为0，返回标准URL（不带签名）
                if (expiration <= 0) {
                    return String.format("https://%s.%s/%s", bucketName, endpoint.replaceAll("^https?://", ""), key);
                }

                // 生成带签名的URL
                Date expirationDate = new Date(System.currentTimeMillis() + expiration * 1000);
                URL url = ossClient.generatePresignedUrl(bucketName, key, expirationDate);

                log.info("生成阿里云OSS文件访问URL成功: key={}", key);
                return url.toString();
            } catch (Exception e) {
                log.error("生成阿里云OSS文件访问URL失败", e);
                throw e;
            } finally {
                if (ossClient != null) {
                    ossClient.shutdown();
                }
            }
        });
    }

    @Override
    public Mono<Boolean> deleteFile(String key) {
        return Mono.fromCallable(() -> {
            OSS ossClient = null;
            try {
                ossClient = getOSSClient();
                ossClient.deleteObject(bucketName, key);

                log.info("删除阿里云OSS文件成功: key={}", key);
                return true;
            } catch (Exception e) {
                log.error("删除阿里云OSS文件失败: key={}", key, e);
                return false;
            } finally {
                if (ossClient != null) {
                    ossClient.shutdown();
                }
            }
        });
    }

    @Override
    public Mono<Boolean> doesFileExist(String key) {
        return Mono.fromCallable(() -> {
            OSS ossClient = null;
            try {
                ossClient = getOSSClient();
                boolean exists = ossClient.doesObjectExist(bucketName, key);

                log.info("检查阿里云OSS文件是否存在: key={}, exists={}", key, exists);
                return exists;
            } catch (Exception e) {
                log.error("检查阿里云OSS文件是否存在失败: key={}", key, e);
                return false;
            } finally {
                if (ossClient != null) {
                    ossClient.shutdown();
                }
            }
        });
    }

    @Override
    public String getProviderName() {
        return "AliOSS";
    }

    /**
     * 获取上传域名
     */
    private String getUploadHost() {
        /*         if (baseUrl != null && !baseUrl.isEmpty()) {
            return baseUrl;
        } */
        return String.format("https://%s.%s", bucketName, endpoint.replaceAll("^https?://", ""));
    }
}
