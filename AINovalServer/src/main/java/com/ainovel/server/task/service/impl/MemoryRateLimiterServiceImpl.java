package com.ainovel.server.task.service.impl;

import com.ainovel.server.task.service.RateLimiterService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

/**
 * 基于内存的响应式限流服务实现
 */
@Slf4j
@Service("memoryRateLimiterService")
public class MemoryRateLimiterServiceImpl implements RateLimiterService {

    private final Map<String, Semaphore> resourceLimiters = new ConcurrentHashMap<>();
    private final Map<String, Double> configuredRates = new ConcurrentHashMap<>();
    
    @Value("${ainovel.rate-limiter.default-permits:10}")
    private int defaultPermits;
    
    @Value("${ainovel.rate-limiter.enabled:true}")
    private boolean enabled;
    
    @Override
    public Mono<Boolean> acquirePermit(String userId, String resource) {
        if (!enabled) {
            return Mono.just(true);
        }
        
        String key = getKey(userId, resource);
        return Mono.fromCallable(() -> {
            Semaphore semaphore = getSemaphore(key);
            return semaphore.tryAcquire();
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    @Override
    public Mono<Void> waitForPermit(String userId, String resource, Duration timeout) {
        if (!enabled) {
            return Mono.empty();
        }
        
        String key = getKey(userId, resource);
        return Mono.fromCallable(() -> {
            Semaphore semaphore = getSemaphore(key);
            try {
                boolean acquired = semaphore.tryAcquire(timeout.toMillis(), TimeUnit.MILLISECONDS);
                if (!acquired) {
                    throw new RuntimeException("获取许可超时: " + key);
                }
                return null;
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("等待许可被中断: " + key, e);
            }
        })
        .subscribeOn(Schedulers.boundedElastic())
        .then();
    }
    
    @Override
    public Mono<Void> releasePermit(String userId, String resource) {
        if (!enabled) {
            return Mono.empty();
        }
        
        String key = getKey(userId, resource);
        return Mono.fromRunnable(() -> {
            Semaphore semaphore = resourceLimiters.get(key);
            if (semaphore != null) {
                semaphore.release();
                log.debug("已释放许可: {}", key);
            }
        }).subscribeOn(Schedulers.boundedElastic())
        .then();
    }
    
    @Override
    public Mono<Integer> getAvailablePermits(String resource) {
        return Mono.fromCallable(() -> {
            int total = 0;
            for (Map.Entry<String, Semaphore> entry : resourceLimiters.entrySet()) {
                if (entry.getKey().endsWith(":" + resource)) {
                    total += entry.getValue().availablePermits();
                }
            }
            return total;
        }).subscribeOn(Schedulers.boundedElastic());
    }
    
    @Override
    public Mono<Void> resetLimiter(String resource) {
        return Mono.fromRunnable(() -> {
            for (String key : resourceLimiters.keySet()) {
                if (key.endsWith(":" + resource)) {
                    resourceLimiters.remove(key);
                    log.info("已重置限流器: {}", key);
                }
            }
        }).subscribeOn(Schedulers.boundedElastic())
        .then();
    }
    
    @Override
    public double getConfiguredRate(String providerOrModelKey) {
        return configuredRates.getOrDefault(providerOrModelKey, (double) defaultPermits);
    }
    
    /**
     * 配置指定资源的速率
     * 
     * @param resource 资源标识
     * @param rate 速率（每秒许可数）
     */
    public void configureRate(String resource, double rate) {
        configuredRates.put(resource, rate);
        log.info("已配置速率: {} -> {}/秒", resource, rate);
    }
    
    private String getKey(String userId, String resource) {
        return userId + ":" + resource;
    }
    
    private Semaphore getSemaphore(String key) {
        return resourceLimiters.computeIfAbsent(key, k -> {
            int permits = this.defaultPermits;
            String[] parts = k.split(":");
            if (parts.length > 1) {
                String resource = parts[1];
                Double rate = configuredRates.get(resource);
                if (rate != null) {
                    permits = (int) Math.ceil(rate);
                }
            }
            log.debug("创建限流器: {} 最大许可数: {}", k, permits);
            return new Semaphore(permits, true);
        });
    }
} 