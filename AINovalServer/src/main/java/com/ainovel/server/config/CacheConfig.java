package com.ainovel.server.config;

import java.util.concurrent.TimeUnit;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import com.github.benmanes.caffeine.cache.Caffeine;

/**
 * 缓存配置类
 */
@Configuration
@EnableCaching
public class CacheConfig {

    /**
     * 配置默认的缓存管理器
     */
    @Bean
    @Primary
    public CacheManager cacheManager() {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager();
        cacheManager.setCaffeine(Caffeine.newBuilder()
                .expireAfterWrite(60, TimeUnit.MINUTES)
                .initialCapacity(100)
                .maximumSize(1000));
        // 启用异步缓存模式，支持响应式编程
        cacheManager.setAsyncCacheMode(true);
        return cacheManager;
    }

    /**
     * 配置短期缓存管理器，用于需要频繁刷新的数据
     */
    @Bean("shortTermCacheManager")
    public CacheManager shortTermCacheManager() {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager();
        cacheManager.setCaffeine(Caffeine.newBuilder()
                .expireAfterWrite(5, TimeUnit.MINUTES)
                .initialCapacity(50)
                .maximumSize(500));
        // 启用异步缓存模式，支持响应式编程
        cacheManager.setAsyncCacheMode(true);
        return cacheManager;
    }
}
