package com.ainovel.server.service.ai.capability;

import com.ainovel.server.domain.model.ModelInfo;
import com.ainovel.server.domain.model.ModelListingCapability;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 提供商能力检测接口
 * 策略模式：定义不同提供商的能力检测策略
 */
public interface ProviderCapabilityDetector {
    
    /**
     * 获取提供商名称
     * 
     * @return 提供商名称
     */
    String getProviderName();
    
    /**
     * 检测提供商的模型列表能力
     * 
     * @return 模型列表能力
     */
    default Mono<ModelListingCapability> detectModelListingCapability() {
        return Mono.just(ModelListingCapability.NO_LISTING);
    }
    
    /**
     * 获取默认模型列表
     * 
     * @return 默认模型列表
     */
    Flux<ModelInfo> getDefaultModels();
    
    /**
     * 测试API密钥是否有效
     * 
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @return 测试结果
     */
    Mono<Boolean> testApiKey(String apiKey, String apiEndpoint);
    
    /**
     * 获取默认的API端点
     * 
     * @return 默认API端点
     */
    String getDefaultApiEndpoint();
} 