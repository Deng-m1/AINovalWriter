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
// import reactor.core.publisher.Mono;

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
    public boolean acquirePermit(String providerOrModelKey) {
        RateLimiterConfiguration.RateConfig config = configuration.getConfigFor(providerOrModelKey);
        return acquirePermit(providerOrModelKey, config.getDefaultTimeoutMillis());
    }

    @Override
    public boolean acquirePermit(String providerOrModelKey, long timeoutMillis) {
        logger.warn("Redis限流服务被禁用，默认返回允许请求。请添加Redis相关依赖并解注释相关代码。");
        return true;
        
        /*
        RateLimiterConfiguration.RateConfig config = configuration.getConfigFor(providerOrModelKey);
        double rate = config.getRate();
        int capacity = config.getBurstCapacity();
        
        String tokenKey = "rate_limiter:" + providerOrModelKey + ":tokens";
        String timestampKey = "rate_limiter:" + providerOrModelKey + ":timestamp";
        
        List<String> keys = Arrays.asList(tokenKey, timestampKey);
        Instant now = Instant.now();
        List<String> args = Arrays.asList(
                Double.toString(rate),
                Integer.toString(capacity),
                Long.toString(now.getEpochSecond()),
                "1"); // 请求1个令牌
        
        try {
            List<Long> result = redisTemplate.execute(redisRateLimiterScript, keys, args)
                    .timeout(Duration.ofMillis(timeoutMillis))
                    .block();
            
            if (result == null || result.size() < 2) {
                logger.error("Redis限流器脚本执行返回异常结果: {}", result);
                return false;
            }
            
            Long newTokens = result.get(0);  // 剩余令牌数
            Long allowed = result.get(1);    // 0或1，表示是否允许
            
            boolean acquired = allowed == 1L;
            
            if (!acquired) {
                logger.warn("获取{}的限流许可失败，当前剩余令牌: {}", providerOrModelKey, newTokens);
            }
            
            return acquired;
        } catch (Exception e) {
            if (e instanceof TimeoutException) {
                logger.warn("Redis限流器执行超时: {}", e.getMessage());
            } else {
                logger.error("执行Redis限流器时发生异常", e);
            }
            return false;
        }
        */
    }

    @Override
    public double getAvailablePermits(String providerOrModelKey) {
        logger.warn("Redis限流服务被禁用，返回配置的突发容量作为估计值");
        return configuration.getConfigFor(providerOrModelKey).getBurstCapacity();
        
        /*
        String tokenKey = "rate_limiter:" + providerOrModelKey + ":tokens";
        
        try {
            String value = redisTemplate.opsForValue().get(tokenKey)
                    .timeout(Duration.ofMillis(500))
                    .block();
            
            if (value != null) {
                return Double.parseDouble(value);
            }
        } catch (Exception e) {
            logger.error("获取Redis中的可用许可数失败", e);
        }
        
        // 如果无法从Redis获取，则返回配置的突发容量作为估计值
        return configuration.getConfigFor(providerOrModelKey).getBurstCapacity();
        */
    }

    @Override
    public double getConfiguredRate(String providerOrModelKey) {
        return configuration.getConfigFor(providerOrModelKey).getRate();
    }
} 