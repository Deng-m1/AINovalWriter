package com.ainovel.server.task.service.impl;

import com.ainovel.server.config.RateLimiterConfiguration;
import com.ainovel.server.task.service.RateLimiterService;
import io.github.resilience4j.ratelimiter.RateLimiter;
import io.github.resilience4j.ratelimiter.RateLimiterConfig;
import io.github.resilience4j.ratelimiter.RateLimiterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * 基于内存的限流服务实现，使用Resilience4j的RateLimiter
 * 
 * 警告：这种实现仅适用于单实例部署，多实例部署时每个实例会独立限流，
 * 可能导致总体调用率超过预期，建议生产环境使用分布式限流方案。
 */
@Service
@ConditionalOnProperty(name = "task.ratelimiter.type", havingValue = "memory", matchIfMissing = true)
public class MemoryRateLimiterServiceImpl implements RateLimiterService {

    private static final Logger logger = LoggerFactory.getLogger(MemoryRateLimiterServiceImpl.class);
    
    @Autowired
    private RateLimiterConfiguration configuration;
    
    private final Map<String, RateLimiter> rateLimiters = new ConcurrentHashMap<>();
    private RateLimiterRegistry rateLimiterRegistry;
    
    @PostConstruct
    public void init() {
        // 初始化默认限流器
        rateLimiterRegistry = RateLimiterRegistry.ofDefaults();
        
        // 获取默认限流器
        getRateLimiter("default");
        
        // 初始化配置中的各提供商限流器
        if (configuration.getProviders() != null) {
            configuration.getProviders().keySet().forEach(this::getRateLimiter);
        }
        
        logger.info("内存限流服务初始化完成，默认限流：{}每秒，配置的提供商：{}", 
                configuration.getDefault_().getRate(), 
                configuration.getProviders().keySet());
    }
    
    @Override
    public boolean acquirePermit(String providerOrModelKey) {
        RateLimiterConfiguration.RateConfig config = configuration.getConfigFor(providerOrModelKey);
        return acquirePermit(providerOrModelKey, config.getDefaultTimeoutMillis());
    }

    @Override
    public boolean acquirePermit(String providerOrModelKey, long timeoutMillis) {
        RateLimiter limiter = getRateLimiter(providerOrModelKey);
        
        try {
            // 尝试在指定的超时时间内获取许可
            boolean acquired = limiter.acquirePermission();
            
            if (!acquired) {
                logger.warn("获取{}的限流许可失败，超过{}ms超时", providerOrModelKey, timeoutMillis);
            }
            
            return acquired;
        } catch (Exception e) {
            logger.error("获取限流许可时发生异常", e);
            return false;
        }
    }

    @Override
    public double getAvailablePermits(String providerOrModelKey) {
        RateLimiter limiter = getRateLimiter(providerOrModelKey);
        return limiter.getMetrics().getAvailablePermissions();
    }

    @Override
    public double getConfiguredRate(String providerOrModelKey) {
        return configuration.getConfigFor(providerOrModelKey).getRate();
    }
    
    /**
     * 获取指定键的RateLimiter，如果不存在则创建
     */
    private RateLimiter getRateLimiter(String key) {
        return rateLimiters.computeIfAbsent(key, k -> {
            RateLimiterConfiguration.RateConfig config = configuration.getConfigFor(k);
            
            // 创建Resilience4j的RateLimiter配置
            RateLimiterConfig rateLimiterConfig = RateLimiterConfig.custom()
                    .limitRefreshPeriod(Duration.ofSeconds(1))  // 每秒刷新一次
                    .limitForPeriod((int)config.getRate())      // 每个周期的许可数
                    .timeoutDuration(Duration.ofMillis(config.getDefaultTimeoutMillis())) // 默认超时时间
                    .build();
            
            // 创建并注册限流器
            RateLimiter limiter = rateLimiterRegistry.rateLimiter(k, rateLimiterConfig);
            logger.debug("为{}创建限流器，速率：{}每秒", k, config.getRate());
            return limiter;
        });
    }
} 