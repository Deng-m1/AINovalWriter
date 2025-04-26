package com.ainovel.server.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import lombok.Data;
import java.util.HashMap;
import java.util.Map;

/**
 * 限流器配置类，从application.yml文件读取配置信息
 */
@Configuration
@ConfigurationProperties(prefix = "task.ratelimiter")
@Data
public class RateLimiterConfiguration {
    
    /**
     * 限流器类型：memory (基于内存) 或 redis (分布式)
     */
    private String type = "memory";
    
    /**
     * 默认限流配置
     */
    private RateConfig default_ = new RateConfig();
    
    /**
     * 各AI提供商或模型的特定限流配置
     */
    private Map<String, RateConfig> providers = new HashMap<>();
    
    /**
     * 获取特定提供商或模型的限流配置，如果未配置则返回默认值
     * 
     * @param providerOrModelKey 提供商或模型的键
     * @return 限流配置
     */
    public RateConfig getConfigFor(String providerOrModelKey) {
        return providers.getOrDefault(providerOrModelKey, default_);
    }
    
    /**
     * 单个限流配置项的数据结构
     */
    @Data
    public static class RateConfig {
        /**
         * 每秒许可数量 (QPS)
         */
        private double rate = 10.0;
        
        /**
         * 突发容量 (令牌桶最大容量)
         */
        private int burstCapacity = 20;
        
        /**
         * 获取许可的默认超时时间(毫秒)
         */
        private long defaultTimeoutMillis = 5000;
    }
} 