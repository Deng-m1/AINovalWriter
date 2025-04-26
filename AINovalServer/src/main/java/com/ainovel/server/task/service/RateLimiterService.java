package com.ainovel.server.task.service;

/**
 * 限流服务，用于控制对外部API（如AI服务）的调用速率。
 * 可以有内存或分布式实现。
 */
public interface RateLimiterService {
    
    /**
     * 尝试获取许可证，如果超过限制会阻塞指定的超时时间
     * 
     * @param providerOrModelKey 提供商或模型的键（如"openai", "anthropic", "gpt-4"等）
     * @return 是否成功获取许可
     */
    boolean acquirePermit(String providerOrModelKey);
    
    /**
     * 尝试获取许可证，如果超过限制会阻塞指定的超时时间
     * 
     * @param providerOrModelKey 提供商或模型的键（如"openai", "anthropic", "gpt-4"等）
     * @param timeoutMillis 最大等待时间（毫秒）
     * @return 是否成功获取许可
     */
    boolean acquirePermit(String providerOrModelKey, long timeoutMillis);
    
    /**
     * 获取指定提供商或模型的当前可用许可数量
     * 
     * @param providerOrModelKey 提供商或模型的键
     * @return 当前可用许可数量
     */
    double getAvailablePermits(String providerOrModelKey);
    
    /**
     * 获取指定提供商或模型的配置速率
     * 
     * @param providerOrModelKey 提供商或模型的键
     * @return 配置的每秒许可数
     */
    double getConfiguredRate(String providerOrModelKey);
} 