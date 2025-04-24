package com.ainovel.server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import com.ainovel.server.service.AIProviderRegistryService;
import com.ainovel.server.service.ai.capability.ProviderCapabilityService;

/**
 * AI服务配置类
 * 用于配置AI服务的Bean
 */
@Configuration
public class AIServiceConfig {
    
    /**
     * 将ProviderCapabilityService作为AIProviderRegistryService的实现
     * 使用@Primary确保在有多个实现时，优先使用此实现
     * 
     * @param providerCapabilityService 提供商能力服务
     * @return AIProviderRegistryService接口实现
     */
    @Bean
    @Primary
    public AIProviderRegistryService aiProviderRegistryService(ProviderCapabilityService providerCapabilityService) {
        return providerCapabilityService;
    }
} 