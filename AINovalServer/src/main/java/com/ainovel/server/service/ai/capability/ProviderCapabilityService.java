package com.ainovel.server.service.ai.capability;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.ModelInfo;
import com.ainovel.server.domain.model.ModelListingCapability;
import com.ainovel.server.service.AIProviderRegistryService;
import com.ainovel.server.service.ai.registry.AIProviderRegistry;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 提供商能力管理服务
 * 整合注册表和多个能力检测器
 * 使用门面模式(Facade Pattern)简化提供商能力相关的操作
 */
@Slf4j
@Service
public class ProviderCapabilityService implements AIProviderRegistryService {

    private final AIProviderRegistry registry;
    private final List<ProviderCapabilityDetector> detectors;
    private final Map<String, ProviderCapabilityDetector> detectorMap = new HashMap<>();

    @Autowired
    public ProviderCapabilityService(AIProviderRegistry registry, List<ProviderCapabilityDetector> detectors) {
        this.registry = registry;
        this.detectors = detectors;
    }

    @PostConstruct
    public void init() {
        // 初始化时，将所有检测器按提供商名称进行映射
        for (ProviderCapabilityDetector detector : detectors) {
            detectorMap.put(detector.getProviderName().toLowerCase(), detector);
            log.info("注册AI提供商能力检测器: {}", detector.getProviderName());
            
            // 预加载默认模型到注册表
            detector.getDefaultModels()
                .doOnNext(model -> registry.registerDefaultModel(
                    detector.getProviderName(), 
                    model.getId(), 
                    model
                ))
                .subscribe();
        }
    }

    /**
     * 获取提供商的能力检测器
     *
     * @param providerName 提供商名称
     * @return 能力检测器
     */
    public Optional<ProviderCapabilityDetector> getDetector(String providerName) {
        return Optional.ofNullable(detectorMap.get(providerName.toLowerCase()));
    }

    /**
     * 获取提供商的模型列表能力
     *
     * @param providerName 提供商名称
     * @return 模型列表能力
     */
    public Mono<ModelListingCapability> getProviderCapability(String providerName) {
        // 首先从注册表中获取
        ModelListingCapability capability = registry.getProviderCapability(providerName);
        if (capability != ModelListingCapability.NO_LISTING) {
            return Mono.just(capability);
        }
        
        // 如果注册表中没有，尝试通过检测器检测
        return getDetector(providerName)
            .map(detector -> detector.detectModelListingCapability())
            .orElse(Mono.just(ModelListingCapability.NO_LISTING));
    }

    /**
     * 获取提供商的默认API端点
     *
     * @param providerName 提供商名称
     * @return 默认API端点
     */
    public String getDefaultApiEndpoint(String providerName) {
        // 首先从注册表中获取
        String endpoint = registry.getDefaultApiEndpoint(providerName);
        if (endpoint != null) {
            return endpoint;
        }
        
        // 如果注册表中没有，尝试通过检测器获取
        return getDetector(providerName)
            .map(ProviderCapabilityDetector::getDefaultApiEndpoint)
            .orElse(null);
    }

    /**
     * 获取提供商的默认模型
     *
     * @param providerName 提供商名称
     * @return 默认模型列表
     */
    public Flux<ModelInfo> getDefaultModels(String providerName) {
        // 首先从注册表中获取
        Map<String, ModelInfo> models = registry.getDefaultModels(providerName);
        if (!models.isEmpty()) {
            return Flux.fromIterable(models.values());
        }
        
        // 如果注册表中没有，尝试通过检测器获取
        return getDetector(providerName)
            .map(ProviderCapabilityDetector::getDefaultModels)
            .orElse(Flux.empty());
    }

    /**
     * 测试提供商的API密钥
     *
     * @param providerName 提供商名称
     * @param apiKey API密钥
     * @param apiEndpoint API端点
     * @return 测试结果
     */
    public Mono<Boolean> testApiKey(String providerName, String apiKey, String apiEndpoint) {
        return getDetector(providerName)
            .map(detector -> detector.testApiKey(apiKey, apiEndpoint))
            .orElse(Mono.just(false));
    }
    
    /**
     * 实现AIProviderRegistryService接口方法
     * 获取提供商的模型列表能力
     *
     * @param providerName 提供商名称
     * @return 模型列表能力
     */
    @Override
    public Mono<ModelListingCapability> getProviderListingCapability(String providerName) {
        if (providerName == null || providerName.trim().isEmpty()) {
            return Mono.empty();
        }
        return getProviderCapability(providerName);
    }
} 