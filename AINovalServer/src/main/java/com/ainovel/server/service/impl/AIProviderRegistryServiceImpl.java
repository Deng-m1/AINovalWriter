package com.ainovel.server.service.impl; // Or your appropriate impl package

import com.ainovel.server.service.AIProviderRegistryService;
import com.ainovel.server.service.ai.ModelListingCapability;
import jakarta.annotation.PostConstruct; // Use jakarta if available, otherwise javax
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
public class AIProviderRegistryServiceImpl implements AIProviderRegistryService {

    // 使用 ConcurrentHashMap 保证线程安全，如果需要动态更新的话
    private final Map<String, ModelListingCapability> capabilityRegistry = new ConcurrentHashMap<>();

    @PostConstruct // 在 Bean 初始化后执行
    public void initializeRegistry() {
        // 硬编码已知提供商的能力
        // 使用小写键以保持一致性
        capabilityRegistry.put("openai", ModelListingCapability.LISTING_WITH_KEY);
        capabilityRegistry.put("anthropic", ModelListingCapability.LISTING_WITH_KEY);
        capabilityRegistry.put("gemini", ModelListingCapability.LISTING_WITH_KEY);
        capabilityRegistry.put("openrouter", ModelListingCapability.LISTING_WITHOUT_KEY);
        capabilityRegistry.put("siliconflow", ModelListingCapability.LISTING_WITH_KEY);
        capabilityRegistry.put("x-ai", ModelListingCapability.LISTING_WITHOUT_KEY);
        // 添加其他提供商...
        // capabilityRegistry.put("ollama", ModelListingCapability.NO_LISTING); // 示例：如果 Ollama 不支持API列表

        log.info("AI Provider Registry initialized with capabilities for: {}", capabilityRegistry.keySet());
    }

    @Override
    public Mono<ModelListingCapability> getProviderListingCapability(String providerName) {
        if (providerName == null || providerName.trim().isEmpty()) {
            return Mono.empty();
        }
        // 统一转换为小写进行查找
        ModelListingCapability capability = capabilityRegistry.get(providerName.toLowerCase());
        return Mono.justOrEmpty(capability);
    }

    // 可选：添加动态注册提供商的方法，如果需要的话
    // public void registerProviderCapability(String providerName, ModelListingCapability capability) {
    //     if (providerName != null && !providerName.trim().isEmpty() && capability != null) {
    //        capabilityRegistry.put(providerName.toLowerCase(), capability);
    //        log.info("Dynamically registered/updated capability for provider: {}", providerName.toLowerCase());
    //     }
    // }
} 