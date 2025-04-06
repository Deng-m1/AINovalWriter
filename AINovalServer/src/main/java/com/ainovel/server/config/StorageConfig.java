package com.ainovel.server.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import lombok.Data;

/**
 * 存储相关配置
 */
@Configuration
public class StorageConfig {

    @Bean
    @ConfigurationProperties(prefix = "ainovel.storage")
    public StorageProperties storageProperties() {
        return new StorageProperties();
    }

    /**
     * 存储配置属性
     */
    @Data
    public static class StorageProperties {

        /**
         * 默认存储提供者
         */
        private String defaultProvider = "alioss";

        /**
         * 封面存储路径
         */
        private String coversPath = "covers";

        /**
         * 启动时是否测试存储连接
         */
        private boolean testOnStartup = false;

        /**
         * 阿里云OSS配置
         */
        private AliOssProperties aliyun = new AliOssProperties();

        /**
         * 其他存储提供者可以在这里添加
         */
    }

    /**
     * 阿里云OSS配置属性
     */
    @Data
    public static class AliOssProperties {

        /**
         * 终端节点
         */
        private String endpoint;

        /**
         * 访问密钥ID
         */
        private String accessKeyId;

        /**
         * 访问密钥密钥
         */
        private String accessKeySecret;

        /**
         * 存储桶名称
         */
        private String bucketName;

        /**
         * 自定义基础URL（可选）
         */
        private String baseUrl;

        /**
         * 地域信息，如cn-hangzhou（可选，如果不提供将从endpoint中提取）
         */
        private String region;
    }
}
