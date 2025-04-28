package com.ainovel.server.task.service;

import reactor.core.publisher.Mono;
import java.time.Duration;

/**
 * 响应式限流服务接口
 */
public interface RateLimiterService {
    
    /**
     * 尝试获取许可
     * @param userId 用户ID
     * @param resource 资源标识
     * @return 是否获取到许可的Mono
     */
    Mono<Boolean> acquirePermit(String userId, String resource);
    
    /**
     * 等待获取许可
     * @param userId 用户ID
     * @param resource 资源标识
     * @param timeout 超时时间
     * @return 完成信号
     */
    Mono<Void> waitForPermit(String userId, String resource, Duration timeout);
    
    /**
     * 释放许可
     * @param userId 用户ID
     * @param resource 资源标识
     * @return 完成信号
     */
    Mono<Void> releasePermit(String userId, String resource);
    
    /**
     * 获取可用许可数
     * @param resource 资源标识
     * @return 可用许可数的Mono
     */
    Mono<Integer> getAvailablePermits(String resource);
    
    /**
     * 重置指定资源的限流器
     * @param resource 资源标识
     * @return 完成信号
     */
    Mono<Void> resetLimiter(String resource);
    
    /**
     * 获取当前配置的速率
     * @param providerOrModelKey 提供者或模型键
     * @return 配置速率
     */
    double getConfiguredRate(String providerOrModelKey);
} 