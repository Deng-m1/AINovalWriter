package com.ainovel.server.task.service.impl;

import com.ainovel.server.config.RateLimiterConfiguration;
import com.ainovel.server.task.service.RateLimiterService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
// import org.springframework.data.redis.core.ReactiveRedisTemplate;
// import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;

import jakarta.annotation.PostConstruct;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeoutException;

/**
 * 基于Redis的分布式限流服务实现
 * 
 * 此实现使用Redis实现分布式限流，适用于多实例部署，
 * 可以精确控制所有实例的总体调用速率。
 * 
 * 注意：当前实现被注释以解决编译问题，需先添加spring-boot-starter-data-redis依赖
 */
@Service
@ConditionalOnProperty(name = "task.ratelimiter.type", havingValue = "redis")
public class RedisRateLimiterServiceImpl implements RateLimiterService {

    private static final Logger logger = LoggerFactory.getLogger(RedisRateLimiterServiceImpl.class);
    
    @Autowired
    private RateLimiterConfiguration configuration;
    
    /* 
    @Autowired
    private ReactiveRedisTemplate<String, String> redisTemplate;
    
    private RedisScript<List<Long>> redisRateLimiterScript;
    */
    
    // Redis脚本，实现令牌桶算法
    private static final String RATE_LIMITER_SCRIPT = 
            "local tokens_key = KEYS[1]\n" +
            "local timestamp_key = KEYS[2]\n" +
            "local rate = tonumber(ARGV[1])\n" +
            "local capacity = tonumber(ARGV[2])\n" +
            "local now = tonumber(ARGV[3])\n" +
            "local requested = tonumber(ARGV[4])\n" +
            "-- 初始化令牌桶\n" +
            "local fill_time = capacity/rate\n" +
            "local last_tokens = tonumber(redis.call('get', tokens_key)) or capacity\n" +
            "local last_refreshed = tonumber(redis.call('get', timestamp_key)) or 0\n" +
            "local delta = math.max(0, now-last_refreshed)\n" +
            "local filled_tokens = math.min(capacity, last_tokens+(delta*rate))\n" +
            "local allowed = filled_tokens >= requested\n" +
            "local new_tokens = filled_tokens\n" +
            "if allowed then\n" +
            "  new_tokens = filled_tokens - requested\n" +
            "end\n" +
            "redis.call('set', tokens_key, new_tokens)\n" +
            "redis.call('set', timestamp_key, now)\n" +
            "-- 设置令牌桶和时间戳的过期时间，避免Redis内存泄漏\n" +
            "redis.call('expire', tokens_key, math.ceil(fill_time*2))\n" +
            "redis.call('expire', timestamp_key, math.ceil(fill_time*2))\n" +
            "return { new_tokens, allowed }";
            
    @PostConstruct
    public void init() {
        // 创建Redis脚本
        // redisRateLimiterScript = RedisScript.of(RATE_LIMITER_SCRIPT, List.class);
        
        logger.info("Redis分布式限流服务初始化完成，但功能被暂时禁用，默认限流：{}每秒", 
                configuration.getDefault_().getRate());
        
        logger.warn("Redis限流服务被禁用！请添加spring-boot-starter-data-redis依赖并解注释相关代码。");
    }
    
    @Override
    public Mono<Boolean> acquirePermit(String userId, String resource) {
        logger.warn("Redis限流服务被禁用，默认返回允许请求。请添加Redis相关依赖并解注释相关代码。");
        return Mono.just(true);
    }

    @Override
    public Mono<Void> waitForPermit(String userId, String resource, Duration timeout) {
        logger.warn("Redis限流服务被禁用，默认立即返回。请添加Redis相关依赖并解注释相关代码。");
        return Mono.empty();
    }

    @Override
    public Mono<Void> releasePermit(String userId, String resource) {
        logger.warn("Redis限流服务被禁用，无需释放。请添加Redis相关依赖并解注释相关代码。");
        return Mono.empty();
    }

    @Override
    public Mono<Integer> getAvailablePermits(String resource) {
        logger.warn("Redis限流服务被禁用，返回配置的突发容量作为估计值");
        return Mono.just(configuration.getConfigFor(resource).getBurstCapacity());
    }

    @Override
    public Mono<Void> resetLimiter(String resource) {
        logger.warn("Redis限流服务被禁用，无法重置限流器。请添加Redis相关依赖并解注释相关代码。");
        return Mono.empty();
    }

    // 以下是旧接口方法，保留以兼容现有代码
    // 这些方法在将来会被移除
    
    /**
     * @deprecated 使用 {@link #acquirePermit(String, String)} 替代
     */
    @Deprecated
    public boolean acquirePermit(String providerOrModelKey) {
        RateLimiterConfiguration.RateConfig config = configuration.getConfigFor(providerOrModelKey);
        return acquirePermit(providerOrModelKey, config.getDefaultTimeoutMillis());
    }

    /**
     * @deprecated 使用 {@link #acquirePermit(String, String)} 替代
     */
    @Deprecated
    public boolean acquirePermit(String providerOrModelKey, long timeoutMillis) {
        logger.warn("Redis限流服务被禁用，默认返回允许请求。请添加Redis相关依赖并解注释相关代码。");
        return true;
    }

    /**
     * @deprecated 使用 {@link #getAvailablePermits(String)} 替代 
     * 注意：该方法返回的是double类型，新方法返回Mono<Integer>
     */
    @Deprecated
    public double getAvailablePermitsDeprecated(String providerOrModelKey) {
        logger.warn("Redis限流服务被禁用，返回配置的突发容量作为估计值");
        return configuration.getConfigFor(providerOrModelKey).getBurstCapacity();
    }

    @Override
    public double getConfiguredRate(String providerOrModelKey) {
        return configuration.getConfigFor(providerOrModelKey).getRate();
    }
} 