package com.ainovel.server.config;

import java.io.ByteArrayInputStream;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import com.ainovel.server.config.StorageConfig.StorageProperties;
import com.ainovel.server.service.provider.AliOSSStorageProvider;
import com.aliyun.oss.ClientBuilderConfiguration;
import com.aliyun.oss.OSS;
import com.aliyun.oss.OSSClientBuilder;
import com.aliyun.oss.common.auth.DefaultCredentialProvider;
import com.aliyun.oss.common.comm.SignVersion;

import lombok.extern.slf4j.Slf4j;

/**
 * 存储服务启动测试 在应用启动时进行OSS存储服务连接测试
 */
@Slf4j
@Component
public class StorageStartupTester implements ApplicationRunner {

    private final StorageProperties storageProperties;
    private final AliOSSStorageProvider ossStorageProvider;
    private final Environment environment;

    @Autowired
    public StorageStartupTester(StorageProperties storageProperties,
            AliOSSStorageProvider ossStorageProvider,
            Environment environment) {
        this.storageProperties = storageProperties;
        this.ossStorageProvider = ossStorageProvider;
        this.environment = environment;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        // 检查是否启用测试
        if (!storageProperties.isTestOnStartup()) {
            log.info("阿里云OSS连接测试已禁用，跳过测试");
            return;
        }

        log.info("开始测试阿里云OSS连接...");

        try {

            // 创建测试文件名
            String testFileName = "oss-test-" + UUID.randomUUID().toString() + ".txt";
            String testKey = String.format("%s/tests/%s", storageProperties.getCoversPath(), testFileName);
            String testContent = "这是一个测试文件，创建于 " + System.currentTimeMillis();

            // 获取OSS配置
            com.ainovel.server.config.StorageConfig.AliOssProperties ossProps = storageProperties.getAliyun();
            String endpoint = ossProps.getEndpoint();
            String accessKeyId = ossProps.getAccessKeyId();
            String accessKeySecret = ossProps.getAccessKeySecret();
            String bucketName = ossProps.getBucketName();
            String region = ossProps.getRegion();

            if (region == null || region.isEmpty()) {
                region = extractRegionFromEndpoint(endpoint);
                log.info("从endpoint提取region: {}", region);
            }

            log.info("测试OSS连接: endpoint={}, bucket={}, region={}, testKey={}",
                    endpoint, bucketName, region, testKey);

            // 测试上传
            OSS ossClient = null;
            try {
                // 创建客户端
                ClientBuilderConfiguration conf = new ClientBuilderConfiguration();
                conf.setSignatureVersion(SignVersion.V4);

                if (region != null && !region.isEmpty()) {
                    ossClient = OSSClientBuilder.create()
                            .endpoint(endpoint)
                            .credentialsProvider(new DefaultCredentialProvider(accessKeyId, accessKeySecret))
                            .clientConfiguration(conf)
                            .region(region)
                            .build();
                } else {
                    ossClient = new OSSClientBuilder().build(endpoint, accessKeyId, accessKeySecret, conf);
                }

                // 上传测试文件
                ossClient.putObject(bucketName, testKey,
                        new ByteArrayInputStream(testContent.getBytes()));
                log.info("测试文件上传成功: {}", testKey);

                // 检查文件是否存在
                boolean exists = ossClient.doesObjectExist(bucketName, testKey);
                log.info("测试文件存在检查: {}", exists ? "成功" : "失败");

                // 删除测试文件
                ossClient.deleteObject(bucketName, testKey);
                log.info("测试文件删除成功");

                log.info("阿里云OSS连接测试成功完成！存储服务配置正常。");
            } finally {
                if (ossClient != null) {
                    ossClient.shutdown();
                }
            }
        } catch (Exception e) {
            log.error("阿里云OSS连接测试失败", e);

            // 如果在生产环境中测试失败，可能需要发出警告
            if (isProductionEnvironment()) {
                log.error("警告：生产环境中OSS存储服务测试失败，这可能会影响应用程序的正常运行！");
            }
        }
    }

    /**
     * 从endpoint提取region信息
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

    /**
     * 检查是否是生产环境
     */
    private boolean isProductionEnvironment() {
        String[] activeProfiles = environment.getActiveProfiles();
        for (String profile : activeProfiles) {
            if (profile.equalsIgnoreCase("prod") || profile.equalsIgnoreCase("production")) {
                return true;
            }
        }
        return false;
    }
}
